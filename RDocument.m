//
//  RDocument.m
//  aa
//
//  Created by stefano iacus on Sat Aug 14 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "RDocument.h"
#import "RController.h"

BOOL defaultsInitialized = NO;

NSColor *shColorNormal;
NSColor *shColorString;
NSColor *shColorNumber;
NSColor *shColorKeyword;
NSColor *shColorComment;
NSColor *shColorIdentifier;

NSArray *keywordList;

@implementation RDocument

+ (void) setDefaultSyntaxHighlightingColors
{
	shColorNormal=[NSColor blackColor];
	shColorString=[NSColor blueColor];
	shColorNumber=[NSColor blueColor];
	shColorKeyword=[NSColor colorWithDeviceRed:0.7 green:0.6 blue:0.0 alpha:1.0];
	shColorComment=[NSColor colorWithDeviceRed:0.6 green:0.4 blue:0.4 alpha:1.0];
	shColorIdentifier=[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.4 alpha:1.0];
	
	keywordList = [NSArray arrayWithObjects: @"for", @"if", @"else", @"TRUE", @"FALSE", @"while",
		@"do", @"NULL", @"Inf", @"NA", @"NaN", @"in", nil];
}

/*  Here we only break the modal loop for the R_Edit call. Wether a window
	is to be saved on exit or no, is up to Cocoa
*/ 
- (BOOL)windowShouldClose:(id)sender{
	
	if(isREdit){
		[NSApp stopModal];
		isREdit = NO;
	}
	return YES;
}

- (id)init
{
    self = [super init];
    if (self) {
		updating=NO;
		execNewlineFlag=NO;
		if (!defaultsInitialized) {
			[RDocument setDefaultSyntaxHighlightingColors];
			defaultsInitialized=YES;
		}
		initialContents=nil;
		initialContentsType=nil;
		useHighlighting=YES;
		isEditable=YES;
		isREdit=NO;
    }
	
    return self;
}

- (void)dealloc {
	if (initialContents) [initialContents release];
	if (initialContentsType) [initialContentsType release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"RDocument";
}

- (void) loadInitialContents
{
	if (!initialContents || !textView) return;
	if ([initialContentsType isEqual:@"rtf"])
		[textView replaceCharactersInRange:
			NSMakeRange(0, [[textView textStorage] length])
								   withRTF:initialContents];
	else
		[textView replaceCharactersInRange:
			NSMakeRange(0, [[textView textStorage] length])
								   withString:[NSString stringWithCString:[initialContents bytes] length:[initialContents length]]];
	[self updateSyntaxHighlightingForRange:NSMakeRange(0,[[textView textStorage] length])];
	[initialContents release];
	initialContents=nil;
}


- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
		
	[textView setFont:[[RController getRController] currentFont]];
	[textView setContinuousSpellCheckingEnabled:NO]; // by default no continuous spell checking
	[textView setAllowsUndo: YES];
	[self loadInitialContents];
	[textView setEditable: isEditable];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		   selector:@selector(textDidChange:)
			   name:NSTextDidChangeNotification
			 object: textView];
	[[textView textStorage] setDelegate:self];	
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	
	// Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
	if([aType isEqual:@"rtf"])
		return [textView RTFFromRange:
			NSMakeRange(0, [[textView string] length])];			
	else
		return (NSData *)[textView string];
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
	
	printOp = [NSPrintOperation printOperationWithView:textView 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
}


- (BOOL) loadDataRepresentation: (NSData *)data ofType:(NSString *)aType {
	if (initialContents) {
		[initialContents release];
		initialContents=nil;
	}
	
	initialContentsType = [[NSString alloc] initWithString:aType];
	initialContents = [[NSData alloc] initWithData: data];

	if (textView) [self loadInitialContents];

	return YES;	
}

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title{
		NSEnumerator *e = [[document windowControllers] objectEnumerator];
		NSWindowController *wc = nil;
		
		while (wc = [e nextObject]) {
			NSWindow *window = [wc window];
			[window setTitle: title];
		}
}

- (void) setHighlighting: (BOOL) use
{
	useHighlighting=use;
	if (textView) {
		if (use)
			[self updateSyntaxHighlightingForRange:NSMakeRange(0,[[textView textStorage] length])];
		else
			[textView setTextColor:[NSColor blackColor] range:NSMakeRange(0,[[textView textStorage] length])];
	}
}

- (void) setEditable: (BOOL) editable
{
	isEditable=editable;
	if (textView)
		[textView setEditable:editable];
}

- (void) setREditFlag: (BOOL) flag
{
	isREdit=flag;
}

- (BOOL) hasREditFlag
{
	return isREdit;
}

/* This is needed to force the NSDocument to know when edited windows are dirty */
- (void) textDidChange: (NSNotification *)notification{
	NSDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
	[ document updateChangeCount:NSChangeDone];
}

/* this method is called after editing took place - we use it for updating the syntax highlighting */
- (void)updateSyntaxHighlightingForRange: (NSRange) range
{
	NSTextStorage *ts = [textView textStorage];
	NSString *s = [ts string];
	//NSLog(@"colorize \"%@\"", [s substringWithRange:lr]);

	int i = range.location;
	int bb = i;
	int last = i+range.length;
	BOOL foundItem=NO;
	
	if (updating || !useHighlighting) return;
	
	updating=YES;
	
	[ts beginEditing];
	while (i < last) {
		foundItem=NO;
		unichar c = [s characterAtIndex:i];
		if (c=='\'' || c=='"') {
			unichar lc=c;
			int ss=i;
			NSRange fr;
			if (i-bb>0) {
				fr=NSMakeRange(bb,i-bb);
				[ts addAttribute:@"shType" value:@"none" range:fr];
				[ts addAttribute:@"NSColor" value:shColorNormal range:fr];
				
				/*
					NSRange drr;
					NSDictionary *dict = [ts attributesAtIndex:fr.location effectiveRange:&drr];
					NSLog(@"dict: %@", dict);
				*/
			}
			i++;
			while (i<last && (c=[s characterAtIndex:i])!=lc) {
				if (c=='\\') { i++; if (i>=last) break; }
				i++;
			}
			fr=NSMakeRange(ss,i-ss+((i==last)?0:1));
			[ts addAttribute:@"shType" value:@"string" range:fr];
			[ts addAttribute:@"NSColor" value:shColorString range:fr];
			bb=i; if (i==last) break;
			i++; bb=i; if (i==last) break;
			c=[s characterAtIndex:i];
			foundItem=YES;
		}
		if (c>='0' && c<='9') {
			int ss=i;
			NSRange fr;
			if (i-bb>0) {
				fr=NSMakeRange(bb,i-bb);
				[ts addAttribute:@"shType" value:@"none" range:fr];
				[ts addAttribute:@"NSColor" value:shColorNormal range:fr];
			}
			i++;
			while (i<last && ((c=[s characterAtIndex:i])=='.' || (c>='0' && c<='9'))) i++;
			fr=NSMakeRange(ss,i-ss);
			[ts addAttribute:@"shType" value:@"number" range:fr];
			[ts addAttribute:@"NSColor" value:shColorNumber range:fr];
			bb=i;
			if (i==last) break;
			c=[s characterAtIndex:i];	
			foundItem=YES;
		}
		if ((c>='a' && c<='z') || (c>='A' && c<='Z') || c=='.') {
			int ss=i;
			NSRange fr;
			if (i-bb>0) {
				fr=NSMakeRange(bb,i-bb);
				[ts addAttribute:@"shType" value:@"none" range:fr];
				[ts addAttribute:@"NSColor" value:shColorNormal range:fr];
			}
			i++;
			while (i<last && ((c=[s characterAtIndex:i])=='_' || c=='.' || (c>='a' && c<='z') || (c>='A' && c<='Z'))) i++;
			fr=NSMakeRange(ss,i-ss);
			
			if ([keywordList containsObject:[s substringWithRange:fr]]) {
				[ts addAttribute:@"shType" value:@"keyword" range:fr];
				[ts addAttribute:@"NSColor" value:shColorKeyword range:fr];
			} else {
				[ts addAttribute:@"shType" value:@"id" range:fr];
				[ts addAttribute:@"NSColor" value:shColorIdentifier range:fr];
			}
			bb=i;
			if (i==last) break;
			c=[s characterAtIndex:i];	
			foundItem=YES;
		}
		if (c=='#') {
			int ss=i;
			NSRange fr;
			if (i-bb>0) {
				fr=NSMakeRange(bb,i-bb);
				[ts addAttribute:@"shType" value:@"none" range:fr];
				[ts addAttribute:@"NSColor" value:shColorNormal range:fr];
			}
			i++;
			while (i<last && ((c=[s characterAtIndex:i])!='\n' && c!='\r')) i++;
			fr=NSMakeRange(ss,i-ss);
			[ts addAttribute:@"shType" value:@"comment" range:fr];
			[ts addAttribute:@"NSColor" value:shColorComment range:fr];
			bb=i;
			if (i==last) break;
			c=[s characterAtIndex:i];
			foundItem=YES;
		}
		if (!foundItem) i++;
	}
	if (bb<last && i-bb>0) {
		NSRange fr=NSMakeRange(bb,i-bb);
		[ts addAttribute:@"shType" value:@"none" range:fr];
		[ts addAttribute:@"NSColor" value:shColorNormal range:fr];
	}
	[ts endEditing];
	updating=NO;
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
	NSTextStorage *ts = [aNotification object];
	NSString *s = [ts string];
	NSRange er = [ts editedRange];
	
	/* get all lines that span the range that was affected. this impementation updates only lines containing the change, not beyond */
	NSRange lr = [s lineRangeForRange:er];
	
	lr.length = [ts length]-lr.location; // change everything up to the end of the document ...
	
	//NSLog(@"line range %d:%d (original was %d:%d)", lr.location, lr.length, er.location, er.length);
	[self updateSyntaxHighlightingForRange:lr];
}

- (BOOL)textView:(NSTextView *)textViewSrc doCommandBySelector:(SEL)commandSelector {
    BOOL retval = NO;
	if (textViewSrc!=textView) return NO;
	//NSLog(@"RTextView commandSelector: %@\n", NSStringFromSelector(commandSelector));
    if (@selector(insertNewline:) == commandSelector && execNewlineFlag) {
		execNewlineFlag=NO;
		return YES;
	}
    if (@selector(insertNewline:) == commandSelector) {
		// handling of indentation
		// currently we just copy what we get and add tabs for additional non-matched { brackets
		NSTextStorage *ts = [textView textStorage];
		NSString *s = [ts string];
		NSRange csr = [textView selectedRange];
		NSRange ssr = NSMakeRange(csr.location, 0);
		NSRange lr = [s lineRangeForRange:ssr]; // line on which enter was pressed - this will be taken as guide
		if (csr.location>0) {
			int i=lr.location;
			int last=csr.location;
			int whiteSpaces=0, addShift=0;
			BOOL initial=YES;
			NSString *wss=@"\n";
			while (i<last) {
				unichar c=[s characterAtIndex:i];
				if (initial) {
					if (c=='\t' || c==' ') whiteSpaces++;
					else initial=NO;
				}
				if (c=='{') addShift++;
				if (c=='}' && addShift>0) addShift--;
				i++;
			}
			if (whiteSpaces>0)
				wss = [wss stringByAppendingString:[s substringWithRange:NSMakeRange(lr.location,whiteSpaces)]];
			while (addShift>0) { wss=[wss stringByAppendingString:@"\t"]; addShift--; }
			[textView insertText:wss];
			return YES;
		}
	}
	return retval;
}

- (IBAction)executeSelection:(id)sender
{
	NSRange sr = [textView selectedRange];
	if (sr.length>0) {
		NSString *stx = [[[textView textStorage] string] substringWithRange:sr];
		[[RController getRController] sendInput:stx];
	}
	execNewlineFlag=YES;
}

@end

