#include <Rinternals.h>
#include <R_ext/Parse.h>
#include <Fileio.h>
#import <sys/fcntl.h>
#import <sys/select.h>
#import <sys/types.h>
#import <sys/time.h>
#import <signal.h>
#import <unistd.h>
#import "Rcallbacks.h"
#import "Rengine.h"

// size of the console output cache buffer
#define DEFAULT_WRITE_BUFFER_SIZE 32768
// high water-mark of the buffer - it's [length - x] where x is the smallest possible size to be flushed before a new string will be split.
#define writeBufferHighWaterMark  (DEFAULT_WRITE_BUFFER_SIZE-4096)
// low water-mark of the buffer - if less than the water mark is available then the buffer will be flushed
#define writeBufferLowWaterMark   2048

/*  RController.m: main GUI code originally based on Simon Urbanek's work of embedding R in Cocoa app (RGui?)
	The Code and File Completion is due to Simon U.
	History handler is due to Simon U.
*/

typedef struct {
  ParseStatus    status;
  int            prompt_type;
  int            browselevel;
  unsigned char  buf[1025];
  unsigned char *bufp;
} R_ReplState;

extern R_ReplState state;
extern BOOL WeHavePackages;
extern BOOL WeHaveDataSets;

void run_Rmainloop(void); // from Rinit.c
extern void RGUI_ReplConsole(SEXP rho, int savestack, int browselevel); // from Rinit.c
extern int RGUI_ReplIteration(SEXP rho, int savestack, int browselevel, R_ReplState *state);

#import "RController.h"
#import "CodeCompletion.h"
#import "FileCompletion.h"
#import "RDocument.h"
#import "PackageManager.h"
#import "DataManager.h"
#import "PackageInstaller.h"
#import "WSBrowser.h"
#import "HelpManager.h"
#import "RQuartz.h"

#import <unistd.h>
#import <sys/fcntl.h>

static RController* sharedRController;

@interface NSApplication (ScriptingSupport)
- (id)handleDCMDCommand:(NSScriptCommand*)command;
@end

@implementation NSApplication (ScriptingSupport)
- (id)handleDCMDCommand:(NSScriptCommand*)command
{
    NSDictionary *args = [command evaluatedArguments];
    NSString *cmd = [args objectForKey:@""];
    if (!cmd || [cmd isEqualToString:@""])
        return [NSNumber numberWithBool:NO];
	[[RController getRController] sendInput: cmd];
	return [NSNumber numberWithBool:YES];
}
@end

@implementation RController

- (id) init {
	self = [super init];
	
	runSystemAsRoot = NO;
	toolbar = nil;
	toolbarStopItem = nil;
	rootFD = -1;
	childPID = 0;
	RLtimer = nil;
	busyRFlag = YES;
	outputPosition = promptPosition = committedLength = 0;
	consoleInputQueue = [[NSMutableArray alloc] initWithCapacity:8];
	currentConsoleInput = nil;
	forceStdFlush = NO;
	writeBufferLen = DEFAULT_WRITE_BUFFER_SIZE;
	writeBufferPos = writeBuffer = (char*) malloc(writeBufferLen);
	
	return self;
}

- (void) setRootFlag: (BOOL) flag
{
	if (!flag) removeRootAuthorization();
	runSystemAsRoot=flag;
	
	{
		NSArray * ia = [toolbar items];
		int l = [ia count], i=0;
		while (i<l) {
			NSToolbarItem *ti = [ia objectAtIndex:i];
			if ([[ti itemIdentifier] isEqual:AuthenticationToolbarItemIdentifier]) {
				[ti setImage: [NSImage imageNamed: flag?@"lock-unlocked":@"lock-locked"]];
				break;
			}
			i++;
		}
	}
}

- (BOOL) getRootFlag { return runSystemAsRoot; }
- (void) setRootFD: (int) fd { rootFD=fd; }

- (NSFont*) currentFont
{
	return [RTextView font];
}

- (void) awakeFromNib {
	NSFont *theFont;
	char *args[4]={ "R", "--no-save", "--gui=cocoa", 0 };
	
	sharedRController = self;
	[[REngine alloc] initWithHandler:self arguments:args];
	
	[RConsoleWindow setOpaque:NO]; // Needed so we can see through it when we have clear stuff on top
	[RTextView setDrawsBackground:NO];
	[[RTextView enclosingScrollView] setDrawsBackground:NO];
	[self readDefaults];
	[RConsoleWindow setBackgroundColor:backgColor];
	[RConsoleWindow display];
	[RTextView setFont:[NSFont userFixedPitchFontOfSize:currentFontSize]];
	[fontSizeStepper setIntValue:currentFontSize];
    theFont=[RTextView font];
    theFont=[[NSFontManager sharedFontManager] convertFont:theFont toSize:[fontSizeStepper intValue]];
    [RTextView setFont:theFont];
	{
		NSMutableDictionary *md = [[RTextView typingAttributes] mutableCopy];
		[md setObject: inputColor forKey: @"NSColor"];
		[RTextView setTypingAttributes:[NSDictionary dictionaryWithDictionary:md]];
		[md release];
	}
 
//	[RTextView changeColor: inputColor];
	[RTextView display];
	[self setupToolbar];
	[self showWindow];
	[ RConsoleWindow setDocumentEdited:YES];
	
    //NSLog(@"RController: awake: done");
	
	WDirtimer = [NSTimer scheduledTimerWithTimeInterval:0.5
												 target:self
											   selector:@selector(showWorkingDir:)
											   userInfo:0
												repeats:YES];
	
	hist=[[History alloc] init];


    BOOL WantThread = YES;
	
    if(WantThread){ // re-route the stdout to our own file descriptor and use ConnectionCache on it
        int pfd[2];
        pipe(pfd);
        dup2(pfd[1], STDOUT_FILENO);
        close(pfd[1]);
        
        stdoutFD=pfd[0];

        pipe(pfd);
#ifndef PLAIN_STDERR
        dup2(pfd[1], STDERR_FILENO);
        close(pfd[1]);
#endif
        
        stderrFD=pfd[0];

		[self addConnectionLog];
    }

	[historyView setDoubleAction: @selector(historyDoubleClick:)];

	currentSize = [[RTextView textContainer] containerSize].width;
	//currentFontSize = [[RTextView font] pointSize];
	currentConsoleWidth = -1;
	chdir(R_ExpandFileName("~/"));
}

-(void) applicationDidFinishLaunching: (NSNotification *)aNotification
{
	if (![[REngine mainEngine] activate]) {
		NSRunAlertPanel(@"Cannot start R",[NSString stringWithFormat:@"Unable to start R: %@", [[REngine mainEngine] lastError]],@"OK",nil,nil);
		exit(-1);
	}
		
	[self setOptionWidth:YES];
	[RTextView setEditable:YES];
	[self flushROutput];
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		   selector:@selector(RConsoleDidResize:)
			   name:NSWindowDidResizeNotification
			 object: RConsoleWindow];
	
	timer = [NSTimer scheduledTimerWithTimeInterval:0.05
											 target:self
										   selector:@selector(otherEventLoops:)
										   userInfo:0
											repeats:YES];
	Flushtimer = [NSTimer scheduledTimerWithTimeInterval:0.5
												  target:self
												selector:@selector(flushTimerHook:)
												userInfo:0
												 repeats:YES];

	if (!RLtimer)
		RLtimer = [NSTimer scheduledTimerWithTimeInterval:0.001
												   target:self
												 selector:@selector(runRELP:)
												 userInfo:0
												  repeats:NO];

}

-(void) addConnectionLog
{
	NSPort *port1;
	NSPort *port2;
	NSArray *portArray;
	NSConnection *connectionToTransferServer;
				
	port1 = [NSPort port];
	port2 = [NSPort port];
	connectionToTransferServer = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[connectionToTransferServer setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	[NSThread detachNewThreadSelector:@selector(readThread:)
							 toTarget:self
						   withObject:portArray];
}

- (void) readThread: (NSArray *)portArray
{
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    NSConnection *connectionToController;
	RController *rc;
	unsigned int bufSize=2048;
    char *buf=(char*) malloc(bufSize);
    int n,pib=0, flushMark=bufSize-(bufSize>>2);
	int bufFD=0;
    fd_set readfds;
	struct timeval timv;

	timv.tv_sec=0; timv.tv_usec=300000; /* timeout */

	connectionToController = [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0]
															sendPort:[portArray objectAtIndex:1]];

	rc = ((RController *)[connectionToController rootProxy]);
	
    fcntl(stdoutFD, F_SETFL, O_NONBLOCK);
    fcntl(stderrFD, F_SETFL, O_NONBLOCK);
    while (1) {
		int selr=0, maxfd=stdoutFD;
        FD_ZERO(&readfds);
        FD_SET(stdoutFD,&readfds);
        FD_SET(stderrFD,&readfds); if(stderrFD>maxfd) maxfd=stderrFD;
		if (rootFD!=-1) { FD_SET(rootFD,&readfds); if(rootFD>maxfd) maxfd=rootFD; }
        selr=select(maxfd+1, &readfds, 0, 0, &timv);
        if (FD_ISSET(stdoutFD, &readfds)) {
			if (bufFD!=0 && pib>0) {
				[rc writeLogsWithBytes:buf length:pib type:bufFD];
				pib=0;
			}
			bufFD=0;
            while (pib<bufSize && (n=read(stdoutFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (pib>flushMark) { // if we reach the flush mark, dump it
				NS_DURING
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				NS_HANDLER
					;
				NS_ENDHANDLER
				pib=0;
            }
        } 
		if (FD_ISSET(stderrFD, &readfds)) {
			if (bufFD!=1 && pib>0) {
				[rc writeLogsWithBytes:buf length:pib type:bufFD];
				pib=0;
			}
			bufFD=1;
			while (pib<bufSize && (n=read(stderrFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (pib>flushMark) { // if we reach the flush mark, dump it
				NS_DURING
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				NS_HANDLER
					;
				NS_ENDHANDLER
				pib=0;
			}
		}
		if (rootFD!=-1 && FD_ISSET(rootFD, &readfds)) {
			if (bufFD!=2 && pib>0) {
				[rc writeLogsWithBytes:buf length:pib type:bufFD];
				pib=0;
			}
			bufFD=2;
			while (pib<bufSize && (n=read(rootFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (n==0 || pib>flushMark) { // if we reach the flush mark, dump it
				NS_DURING
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				NS_HANDLER
					;
				NS_ENDHANDLER
				pib=0;
			}
			if (n==0) rootFD=-1;
		}
		if ((forceStdFlush || selr==0) && pib>0) { // dump also if we got a timeout
			NS_DURING
				[rc writeLogsWithBytes:buf length:pib type:bufFD];
			NS_HANDLER
				;
			NS_ENDHANDLER
			pib=0;
		}
    }
    free(buf);
	
    [pool release];
}

- (void) flushStdConsole
{
	fflush(stderr);
	fflush(stdout);
	forceStdFlush=YES;
}

- (void) addChildProcess: (pid_t) pid
{
	childPID=pid;
	if (pid>0 && toolbarStopItem) [toolbarStopItem setEnabled:YES];
}

- (void) rmChildProcess: (pid_t) pid
{
	childPID=0;
	if (!busyRFlag && toolbarStopItem) [toolbarStopItem setEnabled:NO];
	[self flushStdConsole];
}

// When you have the toolbar in text-only mode, this action is called
// by the toolbar item's menu to make the font bigger.  We just change the stepper control and
// call our -changeFontSize: action.
-(IBAction) fontSizeBigger:(id)sender
{
	if ([RConsoleWindow isKeyWindow]) {
		[fontSizeStepper setIntValue:[fontSizeStepper intValue]+1];
		[self changeFontSize:NULL];
	} else
		[[NSFontManager sharedFontManager] modifyFont:sender];
}

// When you have the toolbar in text-only mode, this action is called
// by the toolbar item's menu to make the font smaller.  We just change the stepper control and
// call our -changeFontSize: action.
-(IBAction) fontSizeSmaller:(id)sender
{
	if ([RConsoleWindow isKeyWindow]) {
		[fontSizeStepper setIntValue:[fontSizeStepper intValue]-1];
		[self changeFontSize:NULL];
	} else
		[[NSFontManager sharedFontManager] modifyFont:sender];

}

// This action is called to change the font size.  It's called by the NSPopUpButton in the toolbar item's 
// custom view, and also by the above routines called from the toolbar item's menu (in text-only mode).
-(IBAction) changeFontSize:(id)sender
{
    NSFont *theFont;
    
    [fontSizeField takeIntValueFrom:fontSizeStepper];
    theFont=[RTextView font];
    theFont=[[NSFontManager sharedFontManager] convertFont:theFont toSize:[fontSizeStepper intValue]];
    [RTextView setFont:theFont];
	[self setOptionWidth:NO];
	[[NSUserDefaults standardUserDefaults] setFloat: [fontSizeStepper intValue] forKey:FontSizeKey];
}


extern BOOL isTimeToFinish;

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
	if (![self windowShouldClose:self])
		return NSTerminateCancel;
	
	if(timer){
		[timer invalidate];
		timer = nil;
	}

	if(RLtimer){
		[RLtimer invalidate];
		RLtimer = nil;
	}
		
	if(Flushtimer){
		[Flushtimer invalidate];
		Flushtimer = nil;
	}
	
	if(WDirtimer){
		[WDirtimer invalidate];
		WDirtimer = nil;
	}
		
	return NSTerminateNow;
}


- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [inputColor release];
    [outputColor release];
    [promptColor release];
    [backgColor release];
    [stderrColor release];
    [stdoutColor release];
	[super dealloc];
}

- (void)showWindow {
    [RConsoleWindow orderFront:nil];
}

- (void) flushTimerHook: (NSTimer*) source
{
	[self flushROutput];
}

- (void) flushROutput {
	if (writeBuffer!=writeBufferPos) {
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:outputColor];
		writeBufferPos=writeBuffer;
	}
}

- (void) handleFlushConsole {
	[self flushROutput];
	[self flushStdConsole];
}

/* this writes R output to the Console window, but indirectly by using a buffer */
- (void) handleWriteConsole: (NSString*) txt {
	const char *s = [txt UTF8String];
	int sl = strlen(s);
	int fits = writeBufferLen-(writeBufferPos-writeBuffer)-1;
	
	// let's flush the buffer if the new string is large and it would, but the buffer should be occupied
	if (fits<sl && fits>writeBufferHighWaterMark) {
		// for efficiency we're not using handleFlushConsole, because that would trigger stdxx flush, too
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:outputColor];
		writeBufferPos=writeBuffer;
		fits = writeBufferLen-1;
	}
	
	while (fits<sl) {	// ok, we're in a situation where we must split the string
		memcpy(writeBufferPos, s, fits);
		writeBufferPos[writeBufferLen-1]=0;
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:outputColor];
		sl-=fits; s+=fits;
		writeBufferPos=writeBuffer;
		fits=writeBufferLen-1;
	}

	strcpy(writeBufferPos, s);
	writeBufferPos+=sl;
	
	// flush the buffer if the low watermark is reached
	if (fits-sl<writeBufferLowWaterMark) {
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:outputColor];
		writeBufferPos=writeBuffer;
	}
}

/* this writes R output to the Console window directly, i.e. without using a buffer. Use handleWriteConsole: for the regular way. */
- (void) writeConsoleDirectly: (NSString*) txt withColor: (NSColor*) color{
	NSRange origSel = [RTextView selectedRange];
	NSRange insPt = NSMakeRange(outputPosition, 0);
	unsigned tl = [txt length];
	if (tl>0) {
		unsigned oldCL=committedLength;
		/* NSLog(@"original: %d:%d, insertion: %d, length: %d, prompt: %d, commit: %d", origSel.location,
			  origSel.length, outputPosition, tl, promptPosition, committedLength); */
		committedLength=0;
		[RTextView setSelectedRange:insPt];
		[RTextView insertText:txt];
		insPt.length=tl;
		[RTextView setTextColor:color range:insPt];
		if (outputPosition<=promptPosition) promptPosition+=tl;
		committedLength=oldCL;
		if (outputPosition<=committedLength) committedLength+=tl;
		if (outputPosition<=origSel.location) origSel.location+=tl;
		outputPosition+=tl;
		[RTextView setSelectedRange:origSel];
	}
}

/* Just writes the prompt in a different color */
- (void)handleWritePrompt: (NSString*) prompt {
    [self handleFlushConsole];
	unsigned textLength = [[RTextView textStorage] length];
    int promptLength=[prompt length];
	NSRange lr = [[[RTextView textStorage] string] lineRangeForRange:NSMakeRange(textLength,0)];
    promptPosition=textLength;
	if (lr.location!=textLength) { // the prompt must be on the beginning of the line
        [RTextView setSelectedRange:NSMakeRange(textLength, 0)];
		[RTextView insertText: @"\n"];
		textLength = [[RTextView textStorage] length];
		promptLength++;
	}
	
    if (promptLength>0) {
        [RTextView setSelectedRange:NSMakeRange(textLength, 0)];
        [RTextView insertText:prompt];
        [RTextView setTextColor:promptColor range:NSMakeRange(promptPosition, promptLength)];
		if (promptLength>1) // this is a trick to make sure that the insertion color doesn't change at the prompt
			[RTextView setTextColor:inputColor range:NSMakeRange(promptPosition+promptLength-1, 1)];
        committedLength=promptPosition+promptLength;
    }
	committedLength=promptPosition+promptLength;
}

- (void)  handleProcessingInput: (char*) cmd
{
	NSString *s = [NSString stringWithCString:cmd];
	unsigned textLength = [[RTextView textStorage] length];
	
	[RTextView setSelectedRange:NSMakeRange(committedLength, textLength-committedLength)];
	[RTextView insertText:s];
	textLength = [[RTextView textStorage] length];
	[RTextView setTextColor:inputColor range:NSMakeRange(committedLength, textLength-committedLength)];
	outputPosition=committedLength=textLength;
	
	if((*cmd == '?') || (!strncmp("help(",cmd,5))){ 
		[self openHelpFor: cmd];
		cmd[0] = '\n'; cmd[1] = 0;
	}
}

- (char*) handleReadConsole: (int) addtohist
{
	if (currentConsoleInput) {
		[currentConsoleInput release];
		currentConsoleInput=nil;
	}
	
	while ([consoleInputQueue count]==0)
		[self doProcessEvents: YES];
	
	currentConsoleInput = [consoleInputQueue objectAtIndex:0];
	[consoleInputQueue removeObjectAtIndex:0];

	if (addtohist) {
		// don't register training newline ... FIXME: we should acutally include it and fix history handling at other places ..
		if ([currentConsoleInput length]>0 && [currentConsoleInput characterAtIndex:[currentConsoleInput length]-1]=='\n')
			[hist commit:[currentConsoleInput substringToIndex:[currentConsoleInput length]-1]];			
		else
			[hist commit:currentConsoleInput];
		[historyView reloadData];
	}
	
	return [currentConsoleInput UTF8String];
}

- (BOOL)windowShouldClose:(id)sender
{
	
	NSBeginAlertSheet(@"Closing R session",@"Save",@"Don't Save",@"Cancel",[RTextView window],self,@selector(shouldCloseDidEnd:returnCode:contextInfo:),NULL,NULL,@"Save workspace image?");
    return NO;
}

/* this gets called by the "wanna save?" sheet on window close */
- (void) shouldCloseDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode==NSAlertDefaultReturn)
		[[REngine mainEngine] executeString:@"quit(\"yes\")"];
    if (returnCode==NSAlertAlternateReturn)
		[[REngine mainEngine] executeString:@"quit(\"no\")"];
}

/*  This is used to send commands through the GUI, i.e. from menus 
	The input replaces what the user is currently typing.
*/
- (void) sendInput: (NSString*) text {
	[self consoleInput:text interactive:YES];
	/*
	unsigned textLength = [[RTextView textStorage] length];
	[RTextView setSelectedRange:NSMakeRange(textLength, 0)];
	NSEvent* event = [NSEvent keyEventWithType:NSKeyDown
									  location:NSMakePoint(0,0)
								 modifierFlags:0
									 timestamp:0
								  windowNumber:[RConsoleWindow windowNumber]
									   context:nil
									characters:@"\n"
				   charactersIgnoringModifiers:nil
									 isARepeat:NO
									   keyCode:nil
		];
	[NSApp postEvent:event atStart:YES];
	 */
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return [[hist entries] count];
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
		row: (int)row
{
			return (NSString*) [[hist entries]  objectAtIndex: row];
}

/*  Clears the history  and updates the TableView */

- (IBAction)doClearHistory:(id)sender
{
	[hist resetAll];
	[historyView reloadData];
}

/*  Loads the content of the history of a file. The default extension .history
	This file is not compatible with unix history files as it could be multiline.
	This rountien cannot load standard unix history files.
	FIXME: We can probably import standard unix history files
*/

- (IBAction)doLoadHistory:(id)sender
{
	NSOpenPanel *op;
	int answer;
	
	op = [NSOpenPanel openPanel];
	[op setTitle:@"Choose history File"];
	
	answer = [op runModalForTypes: [NSArray arrayWithObject:@"history"]];
	
	if(answer == NSOKButton) {
		if([op filename] != nil){
			[hist resetAll];
			[hist setHist: [NSUnarchiver unarchiveObjectWithFile: [op filename]]];
			[historyView reloadData];
		}
	}
}

/*  Saves the content of the history of a file. The default extension .history
	This file is not compatible with unix history files as it could be multiline.
	FIXME: we can probably allow for exporting as single line
*/
	
- (IBAction)doSaveHistory:(id)sender
{
	int answer;
	NSSavePanel *sp;
	sp = [NSSavePanel savePanel];
	[sp setRequiredFileType:@"history"];
	[sp setTitle:@"Save history File"];
	answer = [sp runModal];
	if(answer == NSOKButton) {
		[NSArchiver archiveRootObject: [hist entries]
					toFile: [sp filename]];
	}
	
}

/*  On double-click on items of the History TableView, the item is pasted into the console
	at current cursor position
*/
- (IBAction)historyDoubleClick:(id)sender {
	NSString *cmd;
	int index = [sender selectedRow];
	if(index == -1) return;
	
	cmd = [[hist entries] objectAtIndex:index];
	[self consoleInput:cmd interactive:NO];
	[RConsoleWindow makeFirstResponder:RTextView];
}


/*  This routine is intended to "cat" some text to the R Console without
	issuing the newline.
- (void) consolePaste: (NSString*) text {
	unsigned textLength = [[RTextView textStorage] length];
	[RTextView setSelectedRange:NSMakeRange(textLength, 0)];
	[RTextView insertText:text];
}
*/
/* This function is used by two threads to write  stderr and/or stdout to the console
   outputType: 0 = stdout, 1 = stderr, 2 = stdout/err as root
*/
- (void) writeLogsWithBytes: (char*) buf length: (int) len type: (int) outputType
{
	NSColor *color=(outputType==0)?stdoutColor:((outputType==1)?stderrColor:[NSColor purpleColor]);
	
	[self flushROutput];
	[self writeConsoleDirectly:[NSString stringWithCString:buf length:len] withColor:color];
}    

+ (id) getRController{
	return sharedRController;
}

/* console input - the string passed here is handled as if it was typed on the console */
- (void) consoleInput: (NSString*) cmd interactive: (BOOL) inter
{
	if (!inter) {
		int textLength = [[RTextView textStorage] length];
		if (textLength>committedLength)
			[RTextView replaceCharactersInRange:NSMakeRange(committedLength,textLength-committedLength) withString:@""];
		[RTextView setSelectedRange:NSMakeRange(committedLength,0)];
		[RTextView insertText: cmd];
		textLength = [[RTextView textStorage] length];
		[RTextView setTextColor:inputColor range:NSMakeRange(committedLength,textLength-committedLength)];
	}

	if (inter) {
		if ([cmd characterAtIndex:[cmd length]-1]!='\n') cmd=[cmd stringByAppendingString: @"\n"];
		[consoleInputQueue addObject:[[NSString alloc] initWithString:cmd]];
	}
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    BOOL retval = NO;

	//NSLog(@"RTextView commandSelector: %@\n", NSStringFromSelector(commandSelector));
	
    if (@selector(insertNewline:) == commandSelector) {
        unsigned textLength = [[textView textStorage] length];
		[textView setSelectedRange:NSMakeRange(textLength,0)];
        if (textLength >= committedLength) {
			[textView insertText:@"\n"];
			textLength = [[textView textStorage] length];
			[self consoleInput: [[textView attributedSubstringFromRange:NSMakeRange(committedLength, textLength - committedLength)] string] interactive: YES];
			return(YES);
        }
        retval = YES;
    }
	
	// ---- history browsing ----
	if (@selector(moveUp:) == commandSelector) {
        unsigned textLength = [[textView textStorage] length];        
        NSRange sr=[textView selectedRange];
        if (sr.location==committedLength || sr.location==textLength) {
            NSRange rr=NSMakeRange(committedLength, textLength-committedLength);
            NSString *text = [[textView attributedSubstringFromRange:rr] string];
            if ([hist isDirty]) {
                [hist updateDirty: text];
            }
            NSString *news = [hist prev];
            if (news!=nil) {
                [news retain];
                sr.length=0; sr.location=committedLength;
                [textView setSelectedRange:sr];
                [textView replaceCharactersInRange:rr withString:news];
                [textView insertText:@""];
                [news release];
            }
            retval = YES;
        }
    }
    if (@selector(moveDown:) == commandSelector) {
        unsigned textLength = [[textView textStorage] length];        
        NSRange sr=[textView selectedRange];
        if ((sr.location==committedLength || sr.location==textLength) && ![hist isDirty]) {
            NSRange rr=NSMakeRange(committedLength, textLength-committedLength);
            NSString *news = [hist next];
            if (news==nil) news=@""; else [news retain];
            sr.length=0; sr.location=committedLength;
            [textView setSelectedRange:sr];
            [textView replaceCharactersInRange:rr withString:news];
            [textView insertText:@""];
            [news release];
            retval = YES;
        }
    }
    
	// ---- make sure the user won't accidentally get out of the input line ----
	
	if (@selector(moveToBeginningOfParagraph:) == commandSelector || @selector(moveToBeginningOfLine:) == commandSelector) {
        [textView setSelectedRange: NSMakeRange(committedLength,0)];
        retval = YES;
    }

	if (@selector(moveToBeginningOfParagraphAndModifySelection:) == commandSelector || @selector(moveToBeginningOfLineAndModifySelection:) == commandSelector) {
		// FIXME: this kills the selection - we should retain it ...
        [textView setSelectedRange: NSMakeRange(committedLength,0)];
        retval = YES;
    }
	
	if (@selector(moveWordLeft:) == commandSelector || @selector(moveLeft:) == commandSelector ||
		@selector(moveWordLeftAndModifySelection:) == commandSelector || @selector(moveLeftAndModifySelection:) == commandSelector) {
        NSRange sr=[textView selectedRange];
		if (sr.location==committedLength) return YES;
	}
	
	// ---- code/file completion ----
	
	if (@selector(insertTab:) == commandSelector) {
        NSRange sr=[textView selectedRange];
        int bow=sr.location;
        if (bow>committedLength) {
            while (bow>committedLength) bow--;
            {
                NSString *rep=nil;
                NSRange er = NSMakeRange(bow,sr.location-bow);
                NSString *text = [[textView attributedSubstringFromRange:er] string];
                
                // first we need to find out whether we're in a text part or code part
                unichar c;
                int tl = [text length], tp=0, quotes=0, dquotes=0, lastQuote=-1;
                while (tp<tl) {
                    c=[text characterAtIndex:tp];
                    if (c=='\\') tp++; // skip the next char after a backslash (we don't have to worry about \023 and friends)
                    else {
                        if (dquotes==0 && c=='\'') {
                            quotes^=1;
                            if (quotes) lastQuote=tp;
                        }
                        if (quotes==0 && c=='"') {
                            dquotes^=1;
                            if (dquotes) lastQuote=tp;
                        }
                    }
                    tp++;
                }
                
                if (quotes+dquotes>0) { // if we're inside any quotes, use file completion
                    rep=[FileCompletion complete:[text substringFromIndex:lastQuote+1]];
                    er.location+=lastQuote+1;
                    er.length-=lastQuote+1;
                } else { // otherwise use code completion
                    int s = [text length]-1;
                    c = [text characterAtIndex:s];
                    while (((c>='a')&&(c<='z'))||((c>='A')&&(c<='Z'))||((c>='0')&&(c<='9'))||c=='.') {
                        s--;
                        if (s==-1) break;
                        c = [text characterAtIndex:s];
                    }
                    s++;
                    er.location+=s; er.length-=s;
                    rep=[CodeCompletion complete:[text substringFromIndex:s]];
                }
                
                // ok, by now we should get "rep" if completion is possible and "er" modified to match the proper part
                if (rep!=nil) {
                    [textView replaceCharactersInRange:er withString:rep];
                }
            }
        }
        retval = YES; // tab is never passed further        
	}
	
	// ---- cancel ---
	
	if (@selector(cancel:) == commandSelector) {
		[self breakR:self];
		retval = YES;
	}
    
	return retval;
}
	
/* Allow changes only for uncommitted text */
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    return affectedCharRange.location >= committedLength;
}
	
- (void) handleBusy: (BOOL) isBusy {
    if (isBusy)
        [progressWheel startAnimation:self];
    else
        [progressWheel stopAnimation:self];

	busyRFlag = isBusy;
	if (toolbarStopItem) {
		if (isBusy || childPID>0)
			[toolbarStopItem setEnabled:YES];
		else
			[toolbarStopItem setEnabled:NO];
	}
}

- (void)  handleShowMessage: (char*) msg
{
	NSRunAlertPanel(@"R Message",[NSString stringWithCString:msg],@"OK",nil,nil);
}

/*  This is called from R with as callback to R_ProcessEvents during
	computation in "src/main/errors.c". The callback is defined at the
	moment inside "src/unix/aqua.c". In "errors.c" this is defined to
	allow for user interrupts but we also use it to make our GUI
	reponsive to user interaction.
*/	



/*  This called by a timer periodically to allow tcltk, x11 etc to process their events 
	like window resizing, locator, widgets interactions, etc.
*/

  
- (IBAction)runRELP:(id)sender {
	run_Rmainloop();
}

- (IBAction)flushconsole:(id)sender {
	[self handleFlushConsole];
}

- (IBAction)otherEventLoops:(id)sender {
	R_runHandlers(R_InputHandlers, R_checkActivity(0, 1));
}


- (IBAction)newQuartzDevice:(id)sender {
	[[REngine mainEngine] executeString:@"quartz()"];
}

- (IBAction)breakR:(id)sender{
	if (childPID)
		kill(childPID, SIGINT);
	else
		onintr();
}

- (IBAction)quitR:(id)sender{
	[self windowShouldClose:RConsoleWindow];
}

- (IBAction)makeConsoleKey:(id)sender
{
	[RConsoleWindow makeKeyAndOrderFront:sender];
}

- (IBAction)toggleHistory:(id)sender{
    NSDrawerState state = [HistoryDrawer state];
    if (NSDrawerOpeningState == state || NSDrawerOpenState == state) {
        [HistoryDrawer close];
    } else {
        [HistoryDrawer open];
    }
}

- (IBAction)toggleAuthentication:(id)sender{
	BOOL isOn = [self getRootFlag];
	
	if (isOn) {
		removeRootAuthorization();
		[self setRootFlag:NO];
	} else {
		if (requestRootAuthorization(1)) return;
		[self setRootFlag:YES];
	}
}


- (IBAction)newDocument:(id)sender{
	[[NSDocumentController sharedDocumentController] newDocument: sender];
}

- (IBAction)openDocument:(id)sender{
	[[NSDocumentController sharedDocumentController] openDocument: sender];
}

- (IBAction)saveDocumentAs:(id)sender{
	NSDocument *cd = [[NSDocumentController sharedDocumentController] currentDocument];
	
	if (cd)
		[cd saveDocumentAs:sender];
	else {
		int answer;
		NSSavePanel *sp;
		sp = [NSSavePanel savePanel];
		[sp setRequiredFileType:@"txt"];
		[sp setTitle:@"Save R Console To File"];
		answer = [sp runModalForDirectory:nil file:@"R Console.txt"];
		
		if(answer == NSOKButton) {
			[[RTextView string] writeToFile:[sp filename] atomically:YES];
		}
	}
}

- (IBAction)saveDocument:(id)sender{
	NSDocument *cd = [[NSDocumentController sharedDocumentController] currentDocument];
	
	if (cd)
		[cd saveDocument:sender];
	else // for the console this is the same as Save As ..
		[self saveDocumentAs:sender];
}

- (int) handleChooseFile:(char *)buf len:(int)len isNew:(int)isNew
{
	int answer;
	NSSavePanel *sp;
	NSOpenPanel *op;

	buf[0] = '\0';
	if(isNew==1){
		sp = [NSSavePanel savePanel];
		[sp setTitle:@"Choose New File Name"];
		answer = [sp runModalForDirectory:nil file:nil];
	
		if(answer == NSOKButton) {
			if([sp filename] != nil){
				CFStringGetCString((CFStringRef)[sp filename], buf, len-1,  kCFStringEncodingMacRoman); 
				buf[len] = '\0';
			}
		}
	} else {
		op = [NSOpenPanel openPanel];
		[op setTitle:@"Choose File"];
		answer = [op runModalForDirectory:nil file:nil];
	
		if(answer == NSOKButton) {
			if([op filename] != nil){
				CFStringGetCString((CFStringRef)[op filename], buf, len-1,  kCFStringEncodingMacRoman); 
				buf[len] = '\0';
			}
		}
	}	
	return strlen(buf);

}	

- (void) loadFile:(char *)fname
{
	int res = [[RController getRController] isImageData:fname];
	
	switch(res){
		case -1:
		NSLog(@"cannot open file");
		break;
		
		case 0:
			[self sendInput: [NSString stringWithFormat:@"load(\"%s\")",fname]];
		break;
		
		case 1:
			[self sendInput: [NSString stringWithFormat:@"source(\"%s\")",fname]];
		break;	
		default:
		break; 
	}
}

// FIXME: is this really sufficient? what about compressed files?
/*  isImageData:	returns -1 on error, 0 if the file is RDX2 or RDX1, 
					1 otherwise.
*/	
- (int)isImageData:(char *)fname
{
	FILE * fp;
	int flen;
	
	char buf[5];
	if( (fp = R_fopen(R_ExpandFileName(fname), "r")) ){
		fseek(fp, 0L, SEEK_END);
		flen = ftell(fp);
		rewind(fp);
		if(flen<4) 
			return(1);
		fread(buf, 1, 4, fp);
		buf[4] = '\0';
		if( (strcmp(buf,"RDX2")==0) || ((strcmp(buf,"RDX1")==0))) return(0);
		else return(1);
	} else
		return(-1);
}

- (void) doProcessEvents: (BOOL) blocking {
	NSEvent *event;

	if (blocking){
		event = [NSApp nextEventMatchingMask:NSAnyEventMask
								   untilDate:[NSDate distantFuture]
									  inMode:NSDefaultRunLoopMode
									 dequeue:YES];
		[NSApp sendEvent:event];	
	} else {
		while( (event = [NSApp nextEventMatchingMask:NSAnyEventMask
										   untilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]
											  inMode:NSDefaultRunLoopMode 
											 dequeue:YES]))
			[NSApp sendEvent:event];
	}
	return;
}

- (void) handleProcessEvents{
	[self doProcessEvents: NO];
}
	

/* 
This method calls the showHelpFor method of the Help Manager which opens
the internal html browser/help system of R.app
This method is called from ReadConsole.
 
The input C string 'topic' is parsed and the behaviour is the following:

topic = ?something  => showHelpFor:@"something"
topic = help(something) => showHelpFor:@"something"
topic = help(something); print(anotherthing);   =>  showHelpFor:@"something"

which means that all the rest of the input is discarded.
No error message or warning are raised.
*/

- (void) openHelpFor: (char *) topic 
{
	char tmp[300];
	int i;

	if(topic[0] == '?' && (strlen(topic)>1))
		[[HelpManager getHMController] showHelpFor: [NSString stringWithCString:topic+1]];
	if(strncmp("help(",topic,5)==0){
		for(i=5;i<strlen(topic); i++){
			if(topic[i]==')')
				break;
			tmp[i-5] = topic[i];
		}
		tmp[i-5] = '\0';
		[[HelpManager getHMController] showHelpFor: [NSString stringWithCString:tmp]];
	}
}

- (void) setupToolbar {

    // Create a new toolbar instance, and attach it to our document window 
   toolbar = [[[NSToolbar alloc] initWithIdentifier: RToolbarIdentifier] autorelease];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [RConsoleWindow setToolbar: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    
    if ([itemIdent isEqual: SaveDocToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: @"Save"];
		[toolbarItem setPaletteLabel: @"Save Console Window"];
		[toolbarItem setToolTip: @"Save R Console Window"];
		[toolbarItem setImage: [NSImage imageNamed: @"SaveDocumentItemImage"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(saveDocument:)];
    } else if ([itemIdent isEqual: NewEditWinToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: @"New Document"];
		[toolbarItem setPaletteLabel: @"New Document"];
		[toolbarItem setToolTip: @"Create a new, empty document in the editor"];
		[toolbarItem setImage: [NSImage imageNamed: @"emptyDoc"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newDocument:)];

    } else  if ([itemIdent isEqual: X11ToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Start X11"];
		[toolbarItem setPaletteLabel: @"Start X11 Server"];
		[toolbarItem setToolTip: @"Start The X11 Window Server To Allow R Using X11 device and Tcl/Tk"];
		[toolbarItem setImage: [NSImage imageNamed: @"X11"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(runX11:)];

    }  else  if ([itemIdent isEqual: SetColorsToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Set Colors"];
		[toolbarItem setPaletteLabel: @"Set R Colors"];
		[toolbarItem setToolTip: @"Set R Console Colors"];
		[toolbarItem setImage: [NSImage imageNamed: @"colors"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(openColors:)];

    } else  if ([itemIdent isEqual: LoadFileInEditorToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Open In Editor"];
		[toolbarItem setPaletteLabel: @"Open In Editor"];
		[toolbarItem setToolTip: @"Open In Editor"];
		[toolbarItem setImage: [NSImage imageNamed: @"RDoc"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(openDocument:)];

    } else  if ([itemIdent isEqual: SourceRCodeToolbarIdentifier]) {
		[toolbarItem setLabel: @"Source/Load"];
		[toolbarItem setPaletteLabel: @"Source Or Load In R"];
		[toolbarItem setToolTip: @"Source Script Or Load Data In R"];
		[toolbarItem setImage: [NSImage imageNamed: @"sourceR"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(sourceFile:)];

    } else if([itemIdent isEqual: NewQuartzToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Quartz"];
		[toolbarItem setPaletteLabel: @"Quartz"];
		[toolbarItem setToolTip: @"Open a new Quartz device window"];
		[toolbarItem setImage: [NSImage imageNamed: @"quartz"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newQuartzDevice:) ];

	} else if([itemIdent isEqual: InterruptToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Abort"];
		[toolbarItem setPaletteLabel: @"Abort"];
		toolbarStopItem = toolbarItem;
		[toolbarItem setToolTip: @"Interrupt current R computation"];
		[toolbarItem setImage: [NSImage imageNamed: @"stop"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(breakR:) ];

	}  else if([itemIdent isEqual: FontSizeToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Font Size"];
		[toolbarItem setPaletteLabel: @"Font Size"];
		[toolbarItem setToolTip: @"Grow or shrink the size of R Console font"];
		[toolbarItem setTarget: self];
		[toolbarItem performSelector:@selector(setView:) withObject:fontSizeView];
		[toolbarItem setAction:NULL];
		[toolbarItem setView:fontSizeView];
		if ([toolbarItem view]!=NULL)
		{
			[toolbarItem setMinSize:[[toolbarItem view] bounds].size];
			[toolbarItem setMaxSize:[[toolbarItem view] bounds].size];
		}

	}  else if([itemIdent isEqual: NewQuartzToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Quartz"];
		[toolbarItem setPaletteLabel: @"Quartz"];
		[toolbarItem setToolTip: @"Open a new Quartz device window"];
		[toolbarItem setImage: [NSImage imageNamed: @"quartz"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newQuartzDevice:) ];
	
	} else if([itemIdent isEqual: ShowHistoryToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"History"];
		[toolbarItem setPaletteLabel: @"History"];
		[toolbarItem setToolTip: @"Show/Hide R Command History"];
		[toolbarItem setImage: [NSImage imageNamed: @"history"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleHistory:) ];
	
	} else if([itemIdent isEqual: AuthenticationToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Authentication"];
		[toolbarItem setPaletteLabel: @"Authentication"];
		[toolbarItem setToolTip: @"Authorize R to run system commands as root"];
		[toolbarItem setImage: [NSImage imageNamed: @"lock-locked"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleAuthentication:) ];
	
	} else if([itemIdent isEqual: QuitRToolbarItemIdentifier]) {
		[toolbarItem setLabel: @"Quit"];
		[toolbarItem setPaletteLabel: @"Quit"];
		[toolbarItem setToolTip: @"Quit R"];
		[toolbarItem setImage: [NSImage imageNamed: @"quit"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(quitR:) ];
	
	} else {
	// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
	// Returning nil will inform the toolbar this kind of item is not supported 
	toolbarItem = nil;
    }
    return toolbarItem;
}


- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default    
    // If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
    // user chooses to revert to the default items this set will be used 
    return [NSArray arrayWithObjects:	InterruptToolbarItemIdentifier, SourceRCodeToolbarIdentifier,
		NewQuartzToolbarItemIdentifier, X11ToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		AuthenticationToolbarItemIdentifier, ShowHistoryToolbarItemIdentifier,
		SetColorsToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier, /* SaveDocToolbarItemIdentifier, */
		LoadFileInEditorToolbarItemIdentifier,
		NewEditWinToolbarItemIdentifier, NSToolbarPrintItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		QuitRToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
    // The set of allowed items is used to construct the customization palette 
    return [NSArray arrayWithObjects: 	QuitRToolbarItemIdentifier, AuthenticationToolbarItemIdentifier, ShowHistoryToolbarItemIdentifier, 
		InterruptToolbarItemIdentifier, NewQuartzToolbarItemIdentifier, /* SaveDocToolbarItemIdentifier, */
		NewEditWinToolbarItemIdentifier, LoadFileInEditorToolbarItemIdentifier,
		NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, X11ToolbarItemIdentifier,
		SetColorsToolbarItemIdentifier,
		FontSizeToolbarItemIdentifier, SourceRCodeToolbarIdentifier, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place 
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being 
    // added is found by referencing the @"item" key in the userInfo 
    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
    if ([[addedItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
		[addedItem setToolTip: @"Print Your Document"];
		[addedItem setTarget: self];
    }
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
    // the chance to tear down information related to the item that may have been cached.   The notification object
    // is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
    // key in the userInfo 
   // NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method:  This message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
    BOOL enable = NO;
    if ([[toolbarItem itemIdentifier] isEqual: SaveDocToolbarItemIdentifier]) {
		enable = [RConsoleWindow isDocumentEdited];
    } else if ([[toolbarItem itemIdentifier] isEqual: SourceRCodeToolbarIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: X11ToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: SetColorsToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: LoadFileInEditorToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: NewEditWinToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: NewQuartzToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: InterruptToolbarItemIdentifier]) {
		enable = (busyRFlag || (childPID>0));
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowHistoryToolbarItemIdentifier]) {
		enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: AuthenticationToolbarItemIdentifier]) {
		enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: QuitRToolbarItemIdentifier]) {
		enable = YES;
    }		
    return enable;
}


/* This is needed to force the NSDocument to know when edited windows are dirty */
- (void) RConsoleDidResize: (NSNotification *)notification{
	[self setOptionWidth:NO];
}

- (void) setOptionWidth:(BOOL)force;
{
	float newSize = [[RTextView textContainer] containerSize].width;
	float newFontSize = [[RTextView font] pointSize];
	if((newSize != currentSize) | (newFontSize != currentFontSize) | force){
		float newConsoleWidth = 1.5*newSize/newFontSize-1.0;
		if((int)newConsoleWidth != (int)currentConsoleWidth){
			R_SetOptionWidth(newConsoleWidth);
			currentSize = newSize;	
			currentFontSize = newFontSize;
			currentConsoleWidth = newConsoleWidth;
		}
	}
}


-(IBAction) checkForUpdates:(id)sender{
	[[REngine mainEngine] executeString: @"Rapp.updates()"];
}

-(IBAction) getWorkingDir:(id)sender
{
	[self sendInput:@"getwd()"];
//	[[REngine mainEngine] evaluateString: @"getwd()"];

}

-(IBAction) resetWorkingDir:(id)sender
{
	chdir(R_ExpandFileName("~/"));
}

-(IBAction) setWorkingDir:(id)sender
{
	NSOpenPanel *op;
	char	buf[301];
	getcwd(buf, 300);
	int answer;
	
	op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setTitle:@"Choose New Working Directory"];

	answer = [op runModalForDirectory:[NSString stringWithCString:buf] file:nil types:[NSArray arrayWithObject:@""]];
	[op setCanChooseDirectories:NO];
	[op setCanChooseFiles:YES];

	if(answer == NSOKButton) {
		if([op directory] != nil){
			CFStringGetCString((CFStringRef)[op directory], buf, 300,  kCFStringEncodingMacRoman); 
			chdir(buf);
			}
	}
	

}

- (IBAction) showWorkingDir:(id)sender
{
	char	buf[301];
    
	getcwd(buf, 300);

	[WDirView setEditable:YES];
	[WDirView setStringValue: [NSString stringWithCString:buf]];
	[WDirView setEditable:NO];
}



- (IBAction)installFromDir:(id)sender
{
	NSOpenPanel *op;
	int answer;
	
	op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setTitle:@"Select Package Directory"];
	
	answer = [op runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@""]];
	[op setCanChooseDirectories:NO];
	[op setCanChooseFiles:YES];		

	if(answer == NSOKButton) 
		if([op directory] != nil)
			[[REngine mainEngine] executeString: [NSString stringWithFormat:@"install.from.file(pkg=\"%@\")",[op directory]] ];
}

- (IBAction)installFromBinary:(id)sender
{
	[[REngine mainEngine] executeString: @"install.from.file(binary=TRUE)" ];
}

- (IBAction)installFromSource:(id)sender
{
	[[REngine mainEngine] executeString:@"install.from.file(binary=FALSE)" ];
}

- (IBAction)togglePackageInstaller:(id)sender
{
	[PackageInstaller togglePackageInstaller];
}

- (IBAction)toggleWSBrowser:(id)sender
{
	[WSBrowser toggleWorkspaceBrowser];
	[[REngine mainEngine] executeString:@"browseEnv(html=F)"];

}

- (IBAction)loadWorkSpace:(id)sender
{
	[self sendInput:@"load(\".RData\")"];
//	[[REngine mainEngine] evaluateString:@"load(\".RData\")" ];

}

- (IBAction)saveWorkSpace:(id)sender
{
	[self sendInput:@"save.image()"];
//	[[REngine mainEngine] evaluateString:@"save.image()"];
	
}

- (IBAction)loadWorkSpaceFile:(id)sender
{
	[[REngine mainEngine] executeString:@"load(file.choose())"];
}					

- (IBAction)saveWorkSpaceFile:(id)sender
{
	[[REngine mainEngine] executeString: @"save.image(file=file.choose())"];
}

- (IBAction)showWorkSpace:(id)sender{
	[self sendInput:@"ls()"];
}

- (IBAction)clearWorkSpace:(id)sender
{
	NSBeginAlertSheet(@"Clear Workspace",@"Yes",@"No !!!",nil,RConsoleWindow,self,@selector(shouldClearWS:returnCode:contextInfo:),NULL,NULL,
	@"All objects in the workspace will be removed. Are you sure you want to proceed?");    
}

/* this gets called by the "wanna save?" sheet on window close */
- (void) shouldClearWS:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode==NSAlertDefaultReturn)
		[[REngine mainEngine] executeString: @"rm(list=ls())"];
}

- (IBAction)togglePackageManager:(id)sender
{
	if(WeHavePackages==NO)
		[[REngine mainEngine] executeString:@"package.manager()"];
	[PackageManager togglePackageManager];
}

- (IBAction)toggleDataManager:(id)sender
{
	if(WeHaveDataSets==NO)
		[[REngine mainEngine] executeString: @"data.manager()"];

	[DataManager toggleDataManager];
}


-(IBAction) runX11:(id)sender{
	//[[REngine mainEngine] executeString: @"system(\"open -a X11.app\")"];
	system("open -a X11.app");
}
			
-(IBAction) openColors:(id)sender{
	[RColorPanel orderFront:self];
}



- (IBAction)performHelpSearch:(id)sender {
    if ([[sender stringValue] length]>0) {
//		[self sendInput:[NSString stringWithFormat:@"help.search(\"%@\")", [sender stringValue]]];
		[[REngine mainEngine] executeString: [NSString stringWithFormat:@"print(help.search(\"%@\"))", [sender stringValue]]];
        [helpSearch setStringValue:@""];
    }
}

- (IBAction)sourceFile:(id)sender
{
	int answer;
	NSOpenPanel *op;
	op = [NSOpenPanel openPanel];
	[op setTitle:@"R File to Source"];
	answer = [op runModalForTypes:nil];

	if (answer==NSOKButton)
		[self sendInput:[NSString stringWithFormat:@"source(\"%@\")",[op filename]]];
}

- (IBAction)printDocument:(id)sender
{
	NSPrintInfo *printInfo;
	NSPrintInfo *sharedInfo;
	NSPrintOperation *printOp;
	NSMutableDictionary *printInfoDict;
	NSMutableDictionary *sharedDict;
	
	sharedInfo = [NSPrintInfo sharedPrintInfo];
	sharedDict = [sharedInfo dictionary];
	printInfoDict = [NSMutableDictionary dictionaryWithDictionary:
		sharedDict];
	
	printInfo = [[NSPrintInfo alloc] initWithDictionary: printInfoDict];
	[printInfo setHorizontalPagination: NSAutoPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:RTextView 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
}

/* This method is called by a ColorWell and by the readDefaults.
In the latter case it could be that the newColor is "nil". In this
case the color is set to its default value.
*/
- (void)setInputColor:(NSColor *)newColor {
	if(inputColor)
		[inputColor release];
	
    if (newColor)
        inputColor = [newColor copyWithZone:[self zone]];
	else 
		inputColor = [[NSColor blueColor] copyWithZone:[self zone]];
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:inputColor] 
											  forKey:inputColorKey];
	[inputColorWell setColor: inputColor];
	[RTextView setInsertionPointColor: inputColor];
    [inputColorWell setNeedsDisplay:YES];
}

- (void)setOutputColor:(NSColor *)newColor {
	if(outputColor)
		[outputColor release];
	
    if (newColor)
        outputColor = [newColor copyWithZone:[self zone]];
	else 
		outputColor = [[NSColor blackColor] copyWithZone:[self zone]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:outputColor] 
											  forKey:outputColorKey];
	[outputColorWell setColor: outputColor];
    [outputColorWell setNeedsDisplay:YES];
}

- (void)setPromptColor:(NSColor *)newColor {
	if(promptColor)
		[promptColor release];
	
    if (newColor)
        promptColor = [newColor copyWithZone:[self zone]];
	else 
		promptColor = [[NSColor purpleColor] copyWithZone:[self zone]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:promptColor] 
											  forKey:promptColorKey];
	[promptColorWell setColor: promptColor];
    [promptColorWell setNeedsDisplay:YES];
	[RTextView setNeedsDisplay: YES];	
}

- (void)setStdoutColor:(NSColor *)newColor {
	if(stdoutColor)
		[stdoutColor release];
	
    if (newColor)
        stdoutColor = [newColor copyWithZone:[self zone]];
	else 
		stdoutColor = [[NSColor lightGrayColor] copyWithZone:[self zone]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:stdoutColor] 
											  forKey:stdoutColorKey];
	[stdoutColorWell setColor: stdoutColor];
    [stdoutColorWell setNeedsDisplay:YES];
}

- (void)setStderrColor:(NSColor *)newColor {
	if(stderrColor)
		[stderrColor release];
	
    if (newColor)
        stderrColor = [newColor copyWithZone:[self zone]];
	else 
		stderrColor = [[NSColor redColor] copyWithZone:[self zone]];

	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:stderrColor] 
											  forKey:stderrColorKey];
	[stderrColorWell setColor: stderrColor];
    [stderrColorWell setNeedsDisplay:YES];
}

- (void)setBackGColor:(NSColor *)newColor {
	if(backgColor)
		[backgColor release];
	
    if (newColor)
		backgColor = [ [NSColor colorWithCalibratedRed:[newColor redComponent] 
												 green:[newColor greenComponent]
												  blue:[newColor blueComponent]
												 alpha:alphaValue] copyWithZone:[self zone]];
	else 
		backgColor = [ [NSColor colorWithCalibratedRed:1.0 
												 green:1.0
												  blue:1.0
												 alpha:alphaValue] copyWithZone:[self zone]];

	[RConsoleWindow setBackgroundColor:backgColor];
	[RConsoleWindow display];
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:backgColor] 
											  forKey:backgColorKey];
	[backgColorWell setColor: backgColor];
    [backgColorWell setNeedsDisplay:YES];
}


- (void)changeInputColor:(id)sender {
    [self setInputColor:[sender color]];
}

- (void)changeOutputColor:(id)sender {
    [self setOutputColor:[sender color]];
}

- (void)changePromptColor:(id)sender {
    [self setPromptColor:[sender color]];
}

- (void)changeStdoutColor:(id)sender {
    [self setStdoutColor:[sender color]];
}

- (void)changeStderrColor:(id)sender {
    [self setStderrColor:[sender color]];
}

- (void)changeBackGColor:(id)sender {
	[self setBackGColor:[sender color]];
	[RTextView setBackgroundColor:[sender color]];
}

- (IBAction) changeAlphaColor:(id)sender {
	[self setAlphaValue:[sender floatValue]];
	[self setBackGColor: [backgColorWell color]];
	[RTextView setNeedsDisplay: YES];
}

- (void)setAlphaValue:(float)f {
    alphaValue = f;

	if(backgColor)
		[self setBackGColor:backgColor];
	
	[[NSUserDefaults standardUserDefaults] setFloat:alphaValue 
											  forKey:alphaValueKey];
	[alphaStepper setFloatValue:alphaValue];

}

- (IBAction) setDefaultColors:(id)sender {
	[self setAlphaValue: 1.0];
	[self setBackGColor: nil];
	[self setInputColor: nil];
	[self setOutputColor: nil];
	[self setPromptColor: nil];
	[self setStderrColor: nil];
	[self setStdoutColor: nil];
	
}


- (void) readDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	
	if( [defaults stringForKey:FontSizeKey] == nil )
			currentFontSize = 11.0;
	else
		currentFontSize =  [defaults floatForKey:FontSizeKey];
	
	if( [defaults stringForKey:alphaValueKey] == nil )
		[self setAlphaValue: 1.0];
	else
		[self setAlphaValue: [defaults floatForKey:alphaValueKey]];

	NSData *theData=[defaults dataForKey:backgColorKey];
	if(theData != nil)		
		[self setBackGColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData]];
	else
		[self setBackGColor: nil];
	
	theData=[defaults dataForKey:inputColorKey];
	if(theData != nil)		
		[self setInputColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData]];
	else
		[self setInputColor: nil];


	theData=[defaults dataForKey:outputColorKey];
	if(theData != nil)		
		[self setOutputColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData]];
	else
		[self setOutputColor: nil];

	theData=[defaults dataForKey:promptColorKey];
	if(theData != nil)		
		[self setPromptColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData]];
	else
		[self setPromptColor: nil];
	

	
	theData = [defaults dataForKey:stderrColorKey];
	if(theData != nil)		
		[self setStderrColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData]];
	else
		[self setStderrColor: nil];

	
	theData=[defaults dataForKey:stdoutColorKey];
	if(theData != nil)		
		[self setStdoutColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData]];
	else
		[self setStdoutColor: nil];
	
		
}

@end


