/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *
 *                  
 *  R Copyright notes:
 *                     Copyright (C) 1995-1996   Robert Gentleman and Ross Ihaka
 *                     Copyright (C) 1998-2001   The R Development Core Team
 *                     Copyright (C) 2002-2004   The R Foundation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  A copy of the GNU General Public License is available via WWW at
 *  http://www.gnu.org/copyleft/gpl.html.  You can also obtain it by
 *  writing to the Free Software Foundation, Inc., 59 Temple Place,
 *  Suite 330, Boston, MA  02111-1307  USA.
 */

#import "RGUI.h"
#include <R.h>
#include <Rversion.h>
#include <Rinternals.h>
#include <R_ext/Parse.h>
#include <Fileio.h>
#if (R_VERSION >= R_Version(2,1,0))
// Rinterface is public, but present only in 2.1+
#include <Rinterface.h>
#else
// if there is no Rinterface, we need private Defn.h
#include <Defn.h>
#endif
#import <sys/fcntl.h>
#import <sys/select.h>
#import <sys/types.h>
#import <sys/time.h>
#import <sys/wait.h>
#import <signal.h>
#import <unistd.h>
#import "RController.h"
#import "REngine/Rcallbacks.h"
#import "REngine/Rengine.h"
#import "RConsoleTextStorage.h"

#import "Tools/Authorization.h"
#import "Preferences.h"
#import "SearchTable.h"

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

void run_Rmainloop(void); // from Rinit.c
extern void RGUI_ReplConsole(SEXP rho, int savestack, int browselevel); // from Rinit.c
extern int RGUI_ReplIteration(SEXP rho, int savestack, int browselevel, R_ReplState *state);

// from Defn.h

int R_SetOptionWidth(int);

#import "RController.h"
#import "Tools/CodeCompletion.h"
#import "Tools/FileCompletion.h"
#import "RDocument.h"
#import "PackageManager.h"
#import "DataManager.h"
#import "PackageInstaller.h"
#import "WSBrowser.h"
#import "HelpManager.h"
#import "Quartz/RQuartz.h"
#import "RDocumentController.h"

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
	readConsTransBufferSize = 1024; // initial size - will grow as needed
	readConsTransBuffer = (char*) malloc(readConsTransBufferSize);
	textViewSync = [[NSString alloc] initWithString:@"consoleTextViewSemahphore"];
	
	consoleColorsKeys = [[NSArray alloc] initWithObjects:
		backgColorKey, inputColorKey, outputColorKey, promptColorKey,
		stderrColorKey, stdoutColorKey, rootColorKey];
	defaultConsoleColors = [[NSArray alloc] initWithObjects: // default colors
		[NSColor whiteColor], [NSColor blueColor], [NSColor blackColor], [NSColor purpleColor],
		[NSColor redColor], [NSColor grayColor], [NSColor purpleColor]];
	consoleColors = [defaultConsoleColors mutableCopy];
	
	textFont = [[NSFont userFixedPitchFontOfSize:currentFontSize] retain];
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
	return textFont;
}

- (void) awakeFromNib {
	char *args[4]={ "R", "--no-save", "--gui=cocoa", 0 };
	
#ifdef DEBUG_RGUI
	[[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
#endif
	
	sharedRController = self;
	
	NSLayoutManager *lm = [[RTextView layoutManager] retain];
	NSTextStorage *origTS = [[RTextView textStorage] retain];
	RConsoleTextStorage * textStorage = [[RConsoleTextStorage alloc] init];
	[origTS removeLayoutManager:lm];
	[textStorage addLayoutManager:lm];
	[lm release];
	[origTS release];
	
	[RConsoleWindow setBackgroundColor:[defaultConsoleColors objectAtIndex:iBackgroundColor]]; // we need this, because "update" doesn't touch the color if it's equal - and by default the window has *no* background - not even the default one, so we bring it in sync
	
	[[Preferences sharedPreferences] addDependent: self];
	[self updatePreferences];
	
	{ // first initialize R_LIBS if necessary
		NSString *prefStr = [Preferences stringForKey:miscRAquaLibPathKey withDefault:nil];
		BOOL flag = !isAdmin(); // the default is YES for users and NO for admins
		if (prefStr)
			flag=[prefStr isEqualToString: @"YES"];
		if (flag) {
			char *cRLIBS = getenv("R_LIBS");
			NSString *addPath = [@"~/Library/R/library" stringByExpandingTildeInPath];
			if (cRLIBS && *cRLIBS)
				addPath = [NSString stringWithFormat: @"%s:%@", cRLIBS, addPath];
			setenv("R_LIBS", [addPath UTF8String], 1);
		}
	}
	setenv("R_GUI_APP_VERSION", R_GUI_VERSION_STR, 1);
	
#if (R_VERSION >= R_Version(2,1,0))
	// we enforce UTF-8 locale for R 2.1.0 and higher if LANG is not UTF-8 already
	{
		char *cloc = getenv("LANG");
		if (!cloc || strlen(cloc)<7 || strcasecmp(cloc+strlen(cloc)-5,"UTF-8")) {
			/* if not set, try to figure out the locale from 'preferredLocalizations' */
			char lbuf[64];
			NSArray *pl = [[NSBundle mainBundle] preferredLocalizations];
			strcpy(lbuf, "en_US.UTF-8");
			if (pl && [pl count]>0) {
				NSString *ls = (NSString*) [pl objectAtIndex:0];
				if (ls && [ls length]>0 && ![ls isEqualToString:@"English"]) {
					strncpy(lbuf, [ls UTF8String],48);
					lbuf[48]=0;
					/* FIXME: for some reason R doesn't like en.UTF-8 - as we have no region info (only 10.4+ has that) R needs en_.UTF-8
						secondly, we need to fall-back to en_US.UTF-8 in case R doesn't know the locale, otherwise we'll get no UTF-8
					    all this needs some more testing as R-devel stabilizes */
					strcat(lbuf,"_.UTF-8:en_US.UTF-8");
				}
			}
			setenv("LANG", lbuf, 1);
		}
		NSLog(@"Using locale \"%s\"", getenv("LANG"));
	}
#endif
	
	[[[REngine alloc] initWithHandler:self arguments:args] setCocoaHandler:self];
	
	[RConsoleWindow setOpaque:NO]; // Needed so we can see through it when we have clear stuff on top
	[RTextView setDrawsBackground:NO];
	[[RTextView enclosingScrollView] setDrawsBackground:NO];
	
	/*
	[RTextView setFont:[NSFont userFixedPitchFontOfSize:currentFontSize]];
	[fontSizeStepper setIntValue:currentFontSize];
    theFont=[RTextView font];
    theFont=[[NSFontManager sharedFontManager] convertFont:theFont toSize:[fontSizeStepper intValue]];
    [RTextView setFont:theFont];
	 */
	[RTextView setFont: textFont];
	{
		NSMutableDictionary *md = [[RTextView typingAttributes] mutableCopy];
		[md setObject: [consoleColors objectAtIndex:iInputColor] forKey: @"NSColor"];
		[RTextView setTypingAttributes:[NSDictionary dictionaryWithDictionary:md]];
		[md release];
	}
	[RTextView setContinuousSpellCheckingEnabled:NO]; // force 'no spell checker'
		
	//	[RTextView changeColor: inputColor];
	[RTextView display];
	[self setupToolbar];

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
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: [[Preferences stringForKey:@"initialWorkingDirectoryKey" withDefault:@"~"] stringByExpandingTildeInPath]];
}

-(void) applicationDidFinishLaunching: (NSNotification *)aNotification
{
	if (![[REngine mainEngine] activate]) {
		NSRunAlertPanel(NLS(@"Cannot start R"),[NSString stringWithFormat:NLS(@"Unable to start R: %@"), [[REngine mainEngine] lastError]],NLS(@"OK"),nil,nil);
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
	
	// once we're ready with the doc transition, the following will actually fire up the cconsole window
	//[[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"Rcommand" display:YES];

	[RConsoleWindow makeKeyAndOrderFront:self];
	//[[REngine mainEngine] runDelayedREPL]; // start delayed REPL
	//CGPostKeyboardEvent(27, 53, 1); // post <ESC> to cause SIGINT and thus the actual start of REPL
	
	if (!RLtimer)
		RLtimer = [NSTimer scheduledTimerWithTimeInterval:0.001
												   target:self
												 selector:@selector(kickstart:)
												 userInfo:0
												  repeats:NO];	
}

- (void) kickstart:(id) sender {
	//kill(getpid(),SIGINT);
	[[REngine mainEngine] runREPL];
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
    char *buf=(char*) malloc(bufSize+16);
    int n=0, pib=0, flushMark=bufSize-(bufSize>>2);
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
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}
				pib=0;
			}
			bufFD=0;
            while (pib<bufSize && (n=read(stdoutFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (pib>flushMark) { // if we reach the flush mark, dump it
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}
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
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}
				pib=0;
			}
		}
		if (rootFD!=-1 && FD_ISSET(rootFD, &readfds)) {
			if (bufFD!=2 && pib>0) {
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}
				pib=0;
			}
			bufFD=2;
			while (pib<bufSize && (n=read(rootFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (n==0 || pib>flushMark) { // if we reach the flush mark, dump it
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}
				pib=0;
			}
			if (n==0) rootFD=-1;
		}
		if ((forceStdFlush || selr==0) && pib>0) { // dump also if we got a timeout
			@try{
				[rc writeLogsWithBytes:buf length:pib type:bufFD];
			} @catch(NSException *ex) {
			}
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
	[[Preferences sharedPreferences] removeDependent:self];
	[defaultConsoleColors release];
	[consoleColors release];
	[consoleColorsKeys release];
#ifdef DEBUG_RGUI
	[[NSExceptionHandler defaultExceptionHandler] setDelegate:nil];
#endif
	[super dealloc];
}

- (void) flushTimerHook: (NSTimer*) source
{
	[self flushROutput];
}

- (void) flushROutput {
	if (writeBuffer!=writeBufferPos) {
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:[consoleColors objectAtIndex:iOutputColor]];
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
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:[consoleColors objectAtIndex:iOutputColor]];
		writeBufferPos=writeBuffer;
		fits = writeBufferLen-1;
	}
	
	while (fits<sl) {	// ok, we're in a situation where we must split the string
		memcpy(writeBufferPos, s, fits);
		writeBufferPos[writeBufferLen-1]=0;
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:[consoleColors objectAtIndex:iOutputColor]];
		sl-=fits; s+=fits;
		writeBufferPos=writeBuffer;
		fits=writeBufferLen-1;
	}
	
	strcpy(writeBufferPos, s);
	writeBufferPos+=sl;
	
	// flush the buffer if the low watermark is reached
	if (fits-sl<writeBufferLowWaterMark) {
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:[consoleColors objectAtIndex:iOutputColor]];
		writeBufferPos=writeBuffer;
	}
}

/* this writes R output to the Console window directly, i.e. without using a buffer. Use handleWriteConsole: for the regular way. */
- (void) writeConsoleDirectly: (NSString*) txt withColor: (NSColor*) color{
	@synchronized(textViewSync) {
		RConsoleTextStorage *textStorage = (RConsoleTextStorage*) [RTextView textStorage];
		NSRange origSel = [RTextView selectedRange];
		unsigned tl = [txt length];
		if (tl>0) {
			unsigned oldCL=committedLength;
			/* NSLog(@"original: %d:%d, insertion: %d, length: %d, prompt: %d, commit: %d", origSel.location,
			origSel.length, outputPosition, tl, promptPosition, committedLength); */
			[textStorage beginEditing];
			committedLength=0;
			[textStorage insertText:txt atIndex:outputPosition withColor:color];
			if (outputPosition<=promptPosition) promptPosition+=tl;
			committedLength=oldCL;
			if (outputPosition<=committedLength) committedLength+=tl;
			if (outputPosition<=origSel.location) origSel.location+=tl;
			outputPosition+=tl;
			[textStorage endEditing];
			[RTextView setSelectedRange:origSel];
			[RTextView scrollRangeToVisible:origSel];
		}
	}
}

/* Just writes the prompt in a different color */
- (void)handleWritePrompt: (NSString*) prompt {
    [self handleFlushConsole];
	@synchronized(textViewSync) {
		RConsoleTextStorage *textStorage = (RConsoleTextStorage*) [RTextView textStorage];
		unsigned textLength = [textStorage length];
		int promptLength=[prompt length];
		NSRange lr = [[textStorage string] lineRangeForRange:NSMakeRange(textLength,0)];
		[textStorage beginEditing];
		promptPosition=textLength;
		if (lr.location!=textLength) { // the prompt must be on the beginning of the line
			[textStorage insertText: @"\n" atIndex: textLength withColor:[consoleColors objectAtIndex:iPromptColor]];
			textLength = [textStorage length];
			promptLength++;
		}
		
		if (promptLength>0) {
			[textStorage insertText:prompt atIndex: textLength withColor:[consoleColors objectAtIndex:iPromptColor]];
			if (promptLength>1) // this is a trick to make sure that the insertion color doesn't change at the prompt
				[textStorage addAttribute:@"NSColor" value:[consoleColors objectAtIndex:iInputColor] range:NSMakeRange(promptPosition+promptLength-1, 1)];
			committedLength=promptPosition+promptLength;
		}
		committedLength=promptPosition+promptLength;
		[textStorage endEditing];
		{
			NSRange targetRange = NSMakeRange(committedLength,0);
			[RTextView setSelectedRange:targetRange];
			[RTextView scrollRangeToVisible:targetRange];
		}
	}
}

- (void)  handleProcessingInput: (char*) cmd
{
	NSString *s = [[NSString alloc] initWithUTF8String:cmd];
	
	@synchronized(textViewSync) {
		unsigned textLength = [[RTextView textStorage] length];
		
		[RTextView setSelectedRange:NSMakeRange(committedLength, textLength-committedLength)];
		[RTextView insertText:s];
		textLength = [[RTextView textStorage] length];
		[RTextView setTextColor:[consoleColors objectAtIndex:iInputColor] range:NSMakeRange(committedLength, textLength-committedLength)];
		outputPosition=committedLength=textLength;
		
		// remove undo actions to prevent undo across prompts
		[[RTextView undoManager] removeAllActions];
	}
	
	[s release];
	
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
	
	{
		const char *c = [currentConsoleInput UTF8String];
		if (!c) return 0;
		if (strlen(c)>readConsTransBufferSize-1) { // grow as necessary
			free(readConsTransBuffer);
			readConsTransBufferSize = (strlen(c)+2048)&0xfffffc00;
			readConsTransBuffer = (char*) malloc(readConsTransBufferSize);
		} // we don't shrink the buffer if gets too large - we may want to think about that ...
		
		strcpy(readConsTransBuffer, c);
	}
	return readConsTransBuffer;
}

- (int) handleEdit: (char*) file
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *fn = [[NSString stringWithUTF8String:file] stringByExpandingTildeInPath];
	if (![[NSFileManager defaultManager] isReadableFileAtPath:fn]) {
		[pool release];
		return 0;
	}
	
	RDocument *document = [[RDocumentController sharedDocumentController] openRDocumentWithContentsOfFile: fn display:YES];
	[document setREditFlag: YES];
	
	NSEnumerator *e = [[document windowControllers] objectEnumerator];
	NSWindowController *wc = nil;
	while (wc = [e nextObject]) {
		NSWindow *window = [wc window];
		NSModalSession session = [NSApp beginModalSessionForWindow:window];
		while([document hasREditFlag])
			[NSApp runModalSession:session];
		
		[NSApp endModalSession:session];
	}
	
	[pool release];
	return(0);
}

/* FIXME: the filename is not set for newvly created files */
- (int) handleEditFiles: (int) nfile withNames: (char**) file titles: (char**) wtitle pager: (char*) pager
{
	int    	i;
    
    if (nfile <=0) return 1;
	
    for (i = 0; i < nfile; i++) {
		NSString *fn = [[NSString stringWithUTF8String:file[i]] stringByExpandingTildeInPath];
		if([[NSFileManager defaultManager] fileExistsAtPath:fn])
			[[RDocumentController sharedDocumentController] openRDocumentWithContentsOfFile:fn display:true];
		else
			[[NSDocumentController sharedDocumentController] newDocument: [RController getRController]];
		
		NSDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
		if(wtitle[i]!=nil)
			[RDocument changeDocumentTitle: document Title: [NSString stringWithUTF8String:wtitle[i]]];
    }
	return 1;
}

- (int) handleShowFiles: (int) nfile withNames: (char**) file headers: (char**) headers windowTitle: (char*) wtitle pager: (char*) pages andDelete: (BOOL) del
{
	int    	i;
    
    if (nfile <=0) return 1;
	
    for (i = 0; i < nfile; i++){
		NSString *fn = [[NSString stringWithUTF8String:file[i]] stringByExpandingTildeInPath];
		RDocument *document = [[RDocumentController sharedDocumentController] openRDocumentWithContentsOfFile:fn display:true];
		if(wtitle[i]!=nil)
			[RDocument changeDocumentTitle: document Title: [NSString stringWithUTF8String:wtitle]];
		[document setEditable: NO];
    }
	return 1;
}

//======== Cocoa Handler ======

- (int) handlePackages: (int) count withNames: (char**) name descriptions: (char**) desc URLs: (char**) url status: (BOOL*) stat
{
	[[PackageManager sharedController] updatePackages:count withNames:name descriptions:desc URLs:url status:stat];
	return 0;
}

- (int) handleHelpSearch: (int) count withTopics: (char**) topics packages: (char**) pkgs descriptions: (char**) descs urls: (char**) urls title: (char*) title
{
	[[SearchTable sharedController] updateHelpSearch:count withTopics:topics packages:pkgs descriptions:descs urls:urls title:title];
	return 0;
}

- (BOOL*) handleDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url
{
	[[DataManager sharedController] updateDatasets:count withNames:name descriptions:desc packages:pkg URLs:url];
	return 0; // we don't load the DS this way, we use REngine instead
}

- (int) handleInstalledPackages: (int) count withNames: (char**) name installedVersions: (char**) iver repositoryVersions: (char**) rver update: (BOOL*) stat label: (char*) label
{
	[[PackageInstaller sharedController] updateInstalledPackages:count withNames:name installedVersions:iver repositoryVersions:rver update:stat label:label];
	return 0;
}

- (int) handleSystemCommand: (char*) cmd
{	
	int cstat=-1;
	pid_t pid;
	
	if ([self getRootFlag]) {
		FILE *f;
		char *argv[3] = { "-c", cmd, 0 };
		int fd;
 		NSBundle *b = [NSBundle mainBundle];
		char *sushPath=0;
		if (b) {
			NSString *sush=[[b resourcePath] stringByAppendingString:@"/sush"];
			sushPath = (char*) malloc([sush cStringLength]+1);
			[sush getCString:sushPath maxLength:[sush cStringLength]];
		}
		
		fd = runRootScript(sushPath?sushPath:"/bin/sh",argv,&f,1);
		if (!fd && f)
			[self setRootFD:fileno(f)];
		if (sushPath) free(sushPath);
		return fd;
	}
	
	pid=fork();
	if (pid==0) {
		// int sr;
		// reset signal handlers
		signal(SIGINT, SIG_DFL);
		signal(SIGTERM, SIG_DFL);
		signal(SIGQUIT, SIG_DFL);
		signal(SIGALRM, SIG_DFL);
		signal(SIGCHLD, SIG_DFL);
		execl("/bin/sh","/bin/sh","-c",cmd,0);
		exit(-1);
		//sr=system(cmd);
		//exit(WEXITSTATUS(sr));
	}
	if (pid==-1) return -1;
	
	[[RController getRController] addChildProcess: pid];
	
	while (1) {
		pid_t w = waitpid(pid, &cstat, WNOHANG);
		if (w!=0) break;
		Re_ProcessEvents();
	}
	[[RController getRController] rmChildProcess: pid];
	return cstat;
}	

//==========

- (BOOL)windowShouldClose:(id)sender
{
	[[RDocumentController sharedDocumentController] closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(didCloseAll:) contextInfo:nil];	
	return NO;
}	
	
- (void)didCloseAll:(id)sender {
	NSBeginAlertSheet(NLS(@"Closing R session"),NLS(@"Save"),NLS(@"Don't Save"),NLS(@"Cancel"),[RTextView window],self,@selector(shouldCloseDidEnd:returnCode:contextInfo:),NULL,NULL,NLS(@"Save workspace image?"));
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
	[op setTitle:NLS(@"Choose history File")];
	
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
	[sp setTitle:NLS(@"Save history File")];
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
	NSColor *color=(outputType==0)?[consoleColors objectAtIndex:iStdoutColor]:((outputType==1)?[consoleColors objectAtIndex:iStderrColor]:[consoleColors objectAtIndex:iRootColor]);
	buf[len]=0; /* this MAY be dangerous ... */
	NSString *s = [[NSString alloc] initWithUTF8String:buf];
	[self flushROutput];
	[self writeConsoleDirectly:s withColor:color];
	[s release];
}

+ (RController*) getRController{
	return sharedRController;
}

/* console input - the string passed here is handled as if it was typed on the console */
- (void) consoleInput: (NSString*) cmd interactive: (BOOL) inter
{
	@synchronized(textViewSync) {
		if (!inter) {
			int textLength = [[RTextView textStorage] length];
			if (textLength>committedLength)
				[RTextView replaceCharactersInRange:NSMakeRange(committedLength,textLength-committedLength) withString:@""];
			[RTextView setSelectedRange:NSMakeRange(committedLength,0)];
			[RTextView insertText: cmd];
			textLength = [[RTextView textStorage] length];
			[RTextView setTextColor:[consoleColors objectAtIndex:iInputColor] range:NSMakeRange(committedLength,textLength-committedLength)];
		}
		
		if (inter) {
			if ([cmd characterAtIndex:[cmd length]-1]!='\n') cmd=[cmd stringByAppendingString: @"\n"];
			[consoleInputQueue addObject:[[NSString alloc] initWithString:cmd]];
		}
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
		[textView complete:self];
		retval = YES;
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
	if (affectedCharRange.location < committedLength) { /* if the insertion is outside editable scope, append at the end */
		[textView setSelectedRange:NSMakeRange([[textView textStorage] length],0)];
		[textView insertText:replacementString];
		return NO;
	}
	return YES;
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index 
{
	NSRange sr=[textView selectedRange];
	//NSLog(@"completion attempt; cursor at %d, complRange: %d-%d, commit: %d", sr.location, charRange.location, charRange.location+charRange.length, committedLength);
	//sr=charRange;
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
				//rep=[FileCompletion complete:[text substringFromIndex:lastQuote+1]];
				er.location+=lastQuote+1;
				er.length-=lastQuote+1;
				return [FileCompletion completeAll:[text substringFromIndex:lastQuote+1] cutPrefix:0];
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
				//rep=[CodeCompletion complete:[text substringFromIndex:s]];
				*index=0;
				return [CodeCompletion completeAll:[text substringFromIndex:s] cutPrefix:charRange.location-er.location];
			}
			
			// ok, by now we should get "rep" if completion is possible and "er" modified to match the proper part
			if (rep!=nil) {
				*index=0;
				return [NSArray arrayWithObjects: rep, @"dummy", nil];
				//[textView replaceCharactersInRange:er withString:rep];
			}
		}
	}
	return nil;
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
	NSRunAlertPanel(NLS(@"R Message"),[NSString stringWithCString:msg],NLS(@"OK"),nil,nil);
}

- (IBAction)flushconsole:(id)sender {
	[self handleFlushConsole];
}

- (IBAction)otherEventLoops:(id)sender {
	R_runHandlers(R_InputHandlers, R_checkActivity(0, 1));
}


- (IBAction)newQuartzDevice:(id)sender {
	NSString *width = [Preferences stringForKey:quartzPrefPaneWidthKey withDefault: @"4.5"];
	NSString *height = [Preferences stringForKey:quartzPrefPaneHeightKey withDefault: @"4.5"];
	NSString *cmd = [[[[@"quartz(display=\"\",width=" stringByAppendingString:width]
		stringByAppendingString:@",height="] stringByAppendingString:height] stringByAppendingString:@")"];
	[[REngine mainEngine] executeString:cmd];
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

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
	[[RDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename display:YES];
	return YES;
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
		[sp setTitle:NLS(@"Save R Console To File")];
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
		[sp setTitle:NLS(@"Choose New File Name")];
		answer = [sp runModalForDirectory:nil file:nil];
		
		if(answer == NSOKButton) {
			if([sp filename] != nil){
				CFStringGetCString((CFStringRef)[sp filename], buf, len-1,  kCFStringEncodingMacRoman); 
				buf[len] = '\0';
			}
		}
	} else {
		op = [NSOpenPanel openPanel];
		[op setTitle:NLS(@"Choose File")];
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

- (void) loadFile:(NSString *)fname
{
	int res = [[RController getRController] isImageData:fname];
	
	switch(res){
		case -1:
			NSLog(@"cannot open file");
			break;
			
		case 0:
			[self sendInput: [NSString stringWithFormat:@"load(\"%@\")",fname]];
			break;
			
		case 1:
			[self sendInput: [NSString stringWithFormat:@"source(\"%@\")",fname]];
			break;	
		default:
			break; 
	}
}

// FIXME: is this really sufficient? what about compressed files?
/*  isImageData:	returns -1 on error, 0 if the file is RDX2 or RDX1, 
1 otherwise.
*/	
- (int)isImageData:(NSString *)fname
{
	NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:fname];
	NSData *header;
	char buf[5];

	if (!fh)
		return -1;

	header = [fh readDataOfLength:4];
	[fh closeFile];
	
	if (!header || [header length]<4)
		return -1;

	memcpy(buf, [header bytes], 4);
	
	buf[4]=0;
	if( (strcmp(buf,"RDX2")==0) || ((strcmp(buf,"RDX1")==0)))
		return(0);
	return(1);
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
		[[HelpManager sharedController] showHelpFor: [NSString stringWithCString:topic+1]];
	if(strncmp("help(",topic,5)==0){
		for(i=5;i<strlen(topic); i++){
			if(topic[i]==')')
				break;
			tmp[i-5] = topic[i];
		}
		tmp[i-5] = '\0';
		[[HelpManager sharedController] showHelpFor: [NSString stringWithCString:tmp]];
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
		[toolbarItem setLabel: NLS(@"Save")];
		[toolbarItem setPaletteLabel: NLS(@"Save Console Window")];
		[toolbarItem setToolTip: NLS(@"Save R console window")];
		[toolbarItem setImage: [NSImage imageNamed: @"SaveDocumentItemImage"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(saveDocument:)];
    } else if ([itemIdent isEqual: NewEditWinToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"New Document")];
		[toolbarItem setPaletteLabel: NLS(@"New Document")];
		[toolbarItem setToolTip: NLS(@"Create a new, empty document in the editor")];
		[toolbarItem setImage: [NSImage imageNamed: @"emptyDoc"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newDocument:)];
		
    } else  if ([itemIdent isEqual: X11ToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Start X11")];
		[toolbarItem setPaletteLabel: NLS(@"Start X11 Server")];
		[toolbarItem setToolTip: NLS(@"Start the X11 window server to allow R using X11 device and Tcl/Tk")];
		[toolbarItem setImage: [NSImage imageNamed: @"X11"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(runX11:)];
		
    }  else  if ([itemIdent isEqual: SetColorsToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Set Colors")];
		[toolbarItem setPaletteLabel: NLS(@"Set R Colors")];
		[toolbarItem setToolTip: NLS(@"Set R console colors")];
		[toolbarItem setImage: [NSImage imageNamed: @"colors"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(openColors:)];
		
    } else  if ([itemIdent isEqual: LoadFileInEditorToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Open In Editor")];
		[toolbarItem setPaletteLabel: NLS(@"Open In Editor")];
		[toolbarItem setToolTip: NLS(@"Open document in editor")];
		[toolbarItem setImage: [NSImage imageNamed: @"RDoc"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(openDocument:)];
		
    } else  if ([itemIdent isEqual: SourceRCodeToolbarIdentifier]) {
		[toolbarItem setLabel: NLS(@"Source/Load")];
		[toolbarItem setPaletteLabel: NLS(@"Source or Load in R")];
		[toolbarItem setToolTip: NLS(@"Source script or load data in R")];
		[toolbarItem setImage: [NSImage imageNamed: @"sourceR"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(sourceOrLoadFile:)];
		
    } else if([itemIdent isEqual: NewQuartzToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Quartz")];
		[toolbarItem setPaletteLabel: NLS(@"Quartz")];
		[toolbarItem setToolTip: NLS(@"Open a new Quartz device window")];
		[toolbarItem setImage: [NSImage imageNamed: @"quartz"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newQuartzDevice:) ];
		
	} else if([itemIdent isEqual: InterruptToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Stop")];
		[toolbarItem setPaletteLabel: NLS(@"Stop")];
		toolbarStopItem = toolbarItem;
		[toolbarItem setToolTip: NLS(@"Interrupt current R computation")];
		[toolbarItem setImage: [NSImage imageNamed: @"stop"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(breakR:) ];
		
	}  else if([itemIdent isEqual: FontSizeToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Font Size")];
		[toolbarItem setPaletteLabel: NLS(@"Font Size")];
		[toolbarItem setToolTip: NLS(@"Change the size of R console font")];
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
		[toolbarItem setLabel: NLS(@"Quartz")];
		[toolbarItem setPaletteLabel: NLS(@"Quartz")];
		[toolbarItem setToolTip: NLS(@"Open a new Quartz device window")];
		[toolbarItem setImage: [NSImage imageNamed: @"quartz"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newQuartzDevice:) ];
		
	} else if([itemIdent isEqual: ShowHistoryToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"History")];
		[toolbarItem setPaletteLabel: NLS(@"History")];
		[toolbarItem setToolTip: NLS(@"Show/Hide R command history")];
		[toolbarItem setImage: [NSImage imageNamed: @"history"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleHistory:) ];
		
	} else if([itemIdent isEqual: AuthenticationToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Authentication")];
		[toolbarItem setPaletteLabel: NLS(@"Authentication")];
		[toolbarItem setToolTip: NLS(@"Authorize R to run system commands as root")];
		[toolbarItem setImage: [NSImage imageNamed: @"lock-locked"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleAuthentication:) ];
		
	} else if([itemIdent isEqual: QuitRToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Quit")];
		[toolbarItem setPaletteLabel: NLS(@"Quit")];
		[toolbarItem setToolTip: NLS(@"Quit R")];
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
		[addedItem setToolTip: NLS(@"Print this document")];
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
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: [[Preferences stringForKey:@"initialWorkingDirectoryKey" withDefault:@"~"] stringByExpandingTildeInPath]];
	[self showWorkingDir:sender];
}

-(IBAction) setWorkingDir:(id)sender
{
	NSOpenPanel *op;
	int answer;

	op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setTitle:NLS(@"Choose New Working Directory")];
	
	answer = [op runModalForDirectory:[[NSFileManager defaultManager] currentDirectoryPath] file:nil types:[NSArray arrayWithObject:@""]];
	
	if(answer == NSOKButton && [op directory] != nil)
		[[NSFileManager defaultManager] changeCurrentDirectoryPath:[[op directory] stringByExpandingTildeInPath]];
	[self showWorkingDir:sender];
}

- (IBAction) showWorkingDir:(id)sender
{
	[WDirView setEditable:YES];
	[WDirView setStringValue: [[[NSFileManager defaultManager] currentDirectoryPath] stringByAbbreviatingWithTildeInPath]];
	[WDirView setEditable:NO];
}



- (IBAction)installFromDir:(id)sender
{
	NSOpenPanel *op;
	int answer;
	
	op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setTitle:NLS(@"Select Package Directory")];
	
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
	[[PackageInstaller sharedController] show];
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
	[[REngine mainEngine] executeString: @"save.image(file=file.choose(TRUE))"];
}

- (IBAction)showWorkSpace:(id)sender{
	[self sendInput:@"ls()"];
}

- (IBAction)clearWorkSpace:(id)sender
{
	NSBeginAlertSheet(NLS(@"Clear Workspace"), NLS(@"Yes"), NLS(@"No") , nil, RConsoleWindow, self, @selector(shouldClearWS:returnCode:contextInfo:), NULL, NULL,
					  NLS(@"All objects in the workspace will be removed. Are you sure you want to proceed?"));
}

/* this gets called by the "wanna save?" sheet on window close */
- (void) shouldClearWS:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode==NSAlertDefaultReturn)
		[[REngine mainEngine] executeString: @"rm(list=ls())"];
}

- (IBAction)togglePackageManager:(id)sender
{
	if ([[PackageManager sharedController] count]==0)
		[[REngine mainEngine] executeString:@"package.manager()"];
	else
		[[PackageManager sharedController] show];
}

- (IBAction)toggleDataManager:(id)sender
{
	if ([[DataManager sharedController] count]==0) {
		[[DataManager sharedController] show];
		[[REngine mainEngine] executeString: @"data.manager()"];
	} else
		[[DataManager sharedController] show];
}


-(IBAction) runX11:(id)sender{
	system("open -a X11.app");
}

-(IBAction) openColors:(id)sender{
	[prefsCtrl selectPaneWithIdentifier:@"Colors"];
	[prefsCtrl showWindow:self];
	[[prefsCtrl window] makeKeyAndOrderFront:self];
}

- (IBAction)performHelpSearch:(id)sender {
    if ([[sender stringValue] length]>0) {
		//		[self sendInput:[NSString stringWithFormat:@"help.search(\"%@\")", [sender stringValue]]];
		[[REngine mainEngine] executeString: [NSString stringWithFormat:@"print(help.search(\"%@\"))", [sender stringValue]]];
        [helpSearch setStringValue:@""];
    }
}

- (IBAction)sourceOrLoadFile:(id)sender
{
	int answer;
	NSOpenPanel *op;
	op = [NSOpenPanel openPanel];
	[op setTitle:NLS(@"R File to Source/Load")];
	answer = [op runModalForTypes:nil];
	
	if (answer==NSOKButton)
		[self loadFile:[op filename]];
}

- (IBAction)sourceFile:(id)sender
{
	int answer;
	NSOpenPanel *op;
	op = [NSOpenPanel openPanel];
	[op setTitle:NLS(@"R File to Source")];
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

- (IBAction) setDefaultColors:(id)sender {
	int i = 0, ccs = [consoleColorsKeys count];
	[[Preferences sharedPreferences] beginBatch];
	while (i<ccs) {
		[Preferences setKey:[consoleColorsKeys objectAtIndex:i] withArchivedObject:[defaultConsoleColors objectAtIndex: i]];
		i++;
	}
	[[Preferences sharedPreferences] endBatch];
}

- (void) updatePreferences {
	currentFontSize = [Preferences floatForKey: FontSizeKey withDefault: 11.0];
	NSFont *newFont = [NSFont userFixedPitchFontOfSize:currentFontSize];
	if (newFont!=textFont) {
		[textFont release];
		textFont = [newFont retain];
	}
	
	{
		int i = 0, ccs = [consoleColorsKeys count];
		while (i<ccs) {
			NSColor *c = [Preferences unarchivedObjectForKey: [consoleColorsKeys objectAtIndex:i] withDefault: [consoleColors objectAtIndex:i]];
			if (c != [consoleColors objectAtIndex:i]) {
				[consoleColors replaceObjectAtIndex:i withObject:c];
				if (i == iBackgroundColor) {
					[RConsoleWindow setBackgroundColor:c];
					[RConsoleWindow display];
				}
			}
			i++;
		}
	}
	[RTextView setNeedsDisplay:YES];
}

- (NSTextView *)getRTextView{
	return RTextView;
}

- (NSWindow *)getRConsoleWindow{
	return RConsoleWindow;
}

#ifdef DEBUG_RGUI
- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask	// mask is NSLog<exception type>Mask, exception's userInfo has stack trace for key NSStackTraceKey
{
	NSString *stack = [[exception userInfo] objectForKey:NSStackTraceKey];
	NSTask *ls=[[NSTask alloc] init];
	NSString *pid = [[NSNumber numberWithInt:getpid()] stringValue];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
	
	NSLog(@"Logged exception %@ with trace %@", exception, stack);
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/atos"]) {
		NSPipe *sop = [[NSPipe alloc] init];
		NSFileHandle *soh = [sop fileHandleForReading];
		NSLog(@"Calling atos to retrieve symbols, please wait!");
		[args addObject:@"-p"];
		[args addObject:pid];
		[args addObjectsFromArray:[stack componentsSeparatedByString:@" "]];
	
		[ls setLaunchPath:@"/usr/bin/atos"];
		[ls setArguments:args];
		[ls setStandardOutput:sop];
		[ls launch];
		while ([ls isRunning]) {
			NSData *data = [soh availableData];
			if (data && [data length]>0) { /* remove empty lines in the trace */
				const char *c = [data bytes], *d=c;
				while (*d) {
					if (*d=='\n' && d[1]=='\n') {
						int l=d-c;
						while (*d=='\n') d++;
						fwrite(c, 1, l+1, stderr);
						c=d;
					} else d++;
				}
				if (*c && d-c)
					fwrite(c, 1, d-c, stderr);
			}
		}
		[ls release];
		[sop release];
	} else
		NSLog(@"Unable to find atos - symbols can't be dumped!");
	return NO;
}

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(unsigned int)aMask	// mask is NSHandle<exception type>Mask, exception's userInfo has stack trace for key
{
	return NO;
}

#endif

@end


