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
 *
 *  Created by Simon Urbanek on 1/11/05.
 */

#import "RDocumentWinCtrl.h"
#import "PreferenceKeys.h"
#import "RController.h"
#import "REngine.h"
#import "REditorTextStorage.h"
#import "RRulerView.h"

BOOL defaultsInitialized = NO;

NSColor *shColorNormal;
NSColor *shColorString;
NSColor *shColorNumber;
NSColor *shColorKeyword;
NSColor *shColorComment;
NSColor *shColorIdentifier;

NSArray *keywordList=nil;

@implementation RDocumentWinCtrl

+ (void) setDefaultSyntaxHighlightingColors
{
	shColorNormal=[NSColor blackColor]; [shColorNormal retain];
	shColorString=[NSColor blueColor]; [shColorString retain];
	shColorNumber=[NSColor blueColor]; [shColorNumber retain];
	shColorKeyword=[NSColor colorWithDeviceRed:0.7 green:0.6 blue:0.0 alpha:1.0]; [shColorKeyword retain];
	shColorComment=[NSColor colorWithDeviceRed:0.6 green:0.4 blue:0.4 alpha:1.0]; [shColorComment retain];
	shColorIdentifier=[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.4 alpha:1.0]; [shColorIdentifier retain];
	
	keywordList = [[NSArray alloc] initWithObjects: @"for", @"if", @"else", @"function", @"TRUE", @"FALSE", @"while",
		@"do", @"NULL", @"Inf", @"NA", @"NaN", @"in", nil];
}

- (id)init
{
    self = [super init];
    if (self) {
		document=nil;
		updating=NO;
		[[Preferences sharedPreferences] addDependent:self];
		execNewlineFlag=NO;
		if (!defaultsInitialized) {
			[RDocumentWinCtrl setDefaultSyntaxHighlightingColors];
			defaultsInitialized=YES;
		}
		highlightColorAttr = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor selectedTextBackgroundColor], NSBackgroundColorAttributeName, nil];
    }
    return self;
}



- (void)dealloc {
	if (highlightColorAttr) [highlightColorAttr release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[Preferences sharedPreferences] removeDependent:self];
	[super dealloc];
}

- (void) replaceContentsWithRtf: (NSData*) rtfContents
{
	[textView replaceCharactersInRange:
		NSMakeRange(0, [[textView textStorage] length])
							   withRTF:rtfContents];
	[self updateSyntaxHighlightingForRange:NSMakeRange(0, [[textView textStorage] length])];
}

- (void) replaceContentsWithString: (NSString*) strContents
{
	[textView replaceCharactersInRange: NSMakeRange(0, [[textView textStorage] length]) withString:strContents];
	[self updateSyntaxHighlightingForRange:NSMakeRange(0, [[textView textStorage] length])];
}

- (NSData*) contentsAsRtf
{
	return [textView RTFFromRange:
		NSMakeRange(0, [[textView string] length])];
}

- (NSString*) contentsAsString
{
	return [textView string];
}	

- (NSTextView *) textView {
	return textView;
}

- (void) windowDidLoad
{
    if (self) {
		document=nil;
		updating=NO;
		[[Preferences sharedPreferences] addDependent:self];
		execNewlineFlag=NO;
		if (!defaultsInitialized) {
			[RDocumentWinCtrl setDefaultSyntaxHighlightingColors];
			defaultsInitialized=YES;
		}
		// For now replaced selectedTextBackgroundColor by redColor
		highlightColorAttr = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor redColor], NSBackgroundColorAttributeName, nil];
    }
	BOOL showLineNos = [Preferences flagForKey:showLineNumbersKey withDefault: NO];
	if (showLineNos) {
		// This should probably get loaded from NSUserDefaults.
		NSFont *font = [NSFont fontWithName:@"Monaco" size: 10];
		
		// Make sure that we don't wrap lines.
		[scrollView setHasHorizontalScroller: YES];
		[textView setHorizontallyResizable: YES]; 
		NSSize layoutSize = [textView maxSize];
		layoutSize.width = layoutSize.height;
		[textView setMaxSize: layoutSize];
		[[textView textContainer] setWidthTracksTextView: NO];
		[[textView textContainer] setHeightTracksTextView: NO];
		[[textView textContainer] setContainerSize: layoutSize];
		
		// Create and install our line numbers
		if (theRulerView) [theRulerView release];
		theRulerView = [[RRulerView alloc] initWithScrollView: scrollView orientation: NSVerticalRuler showLineNumbers: showLineNos textView:textView];
		
		[scrollView setHasHorizontalRuler: NO];
		[scrollView setHasVerticalRuler: YES];
		[scrollView setVerticalRulerView: theRulerView];
		[scrollView setRulersVisible: YES];    
		[scrollView setLineScroll: [font pointSize]];
		
		// Add a small pad to the textViews
		[[textView textContainer] setLineFragmentPadding: 10.0];
		
		[textView setUsesRuler: YES];
		[textView setFont: font];
		
	}
	[scrollView setDocumentView:textView];		
    [textView setDelegate: self];
	
	document=(RDocument*) [self document];
	
	// instead of building the whole text storage network, we just replace the text storage - but ti's not trivial since ts is actually the root of the network
	
	NSLayoutManager *lm = [[textView layoutManager] retain];
	NSTextStorage *origTS = [[textView textStorage] retain];
	REditorTextStorage * textStorage = [[REditorTextStorage alloc] init];
	[origTS removeLayoutManager:lm];
	[textStorage addLayoutManager:lm];
	[lm release];
	[origTS release];
	
	[[self window] setOpaque:NO]; // Needed so we can see through it when we have clear stuff on top
	[textView setDrawsBackground:NO];
	[[textView enclosingScrollView] setDrawsBackground:NO];
	[self updatePreferences];
	
	[textView setFont:[[RController getRController] currentFont]];
	[textView setContinuousSpellCheckingEnabled:NO]; // by default no continuous spell checking
	[textView setAllowsUndo: YES];
	[document loadInitialContents];
	[textView setEditable: [document editable]];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		   selector:@selector(textDidChange:)
			   name:NSTextDidChangeNotification
			 object: textView];
/*
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		   selector:@selector(windowDidBecomeKey:)
			   name:NSWindowDidBecomeKeyNotification
			 object:theRulerView];
*/
	[[textView textStorage] setDelegate:self];	
	[self updatePreferences];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification {
	[theRulerView updateView];
}

- (NSUndoManager*) windowWillReturnUndoManager: (NSWindow*) sender
{
	return [[self document] undoManager];
}

- (void) updatePreferences {
	NSColor *c = [Preferences unarchivedObjectForKey: backgColorKey withDefault: nil];
	if (c && c!=[[self window] backgroundColor]) {
		[[self window] setBackgroundColor:c];
//		[[self window] display];
	}
	[self setHighlighting:[Preferences flagForKey:showSyntaxColoringKey withDefault: YES]];
	showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault: YES];
	braceHighlightInterval = [[Preferences stringForKey:highlightIntervalKey withDefault: @"0.2"] doubleValue];
	[self updateSyntaxHighlightingForRange:NSMakeRange(0,[[textView textStorage] length])];
	[textView setNeedsDisplay:YES];
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
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	[textView setBackgroundColor:[NSColor whiteColor]];
	printOp = [NSPrintOperation printOperationWithView:textView 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
	[self updatePreferences];
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

/* This is needed to force the NSDocument to know when edited windows are dirty */
- (void) textDidChange: (NSNotification *)notification{
	[[self document] updateChangeCount:NSChangeDone];
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
	
	if (!keywordList) [RDocumentWinCtrl setDefaultSyntaxHighlightingColors];
//	if (showMatchingBraces) [self highlightBracesWithShift:0 andWarn:YES];
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
			
			{
				NSString *word = [s substringWithRange:fr];
				if (word && keywordList && [keywordList containsObject:word]) {
					[ts addAttribute:@"shType" value:@"keyword" range:fr];
					[ts addAttribute:@"NSColor" value:shColorKeyword range:fr];
				} else {
					[ts addAttribute:@"shType" value:@"id" range:fr];
					[ts addAttribute:@"NSColor" value:shColorIdentifier range:fr];
				}
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

- (void) highlightBracesWithShift: (int) shift andWarn: (BOOL) warn
{
	NSString *completeString = [[textView textStorage] string];
	unsigned int completeStringLength = [completeString length];
	if (completeStringLength < 2) return;
	
	NSRange selRange = [textView selectedRange];
	unsigned int cursorLocation = selRange.location;
	cursorLocation+=shift; // add any shift as cursor movement guys need it
	if (cursorLocation<0 || cursorLocation>=completeStringLength) return;
	
	unichar characterToCheck;
	unichar openingChar = 0;
	characterToCheck = [completeString characterAtIndex:cursorLocation];
	int skipMatchingBrace = 0;
	
	if (characterToCheck == ')') openingChar='(';
	else if (characterToCheck == ']') openingChar='[';
	else if (characterToCheck == '}') openingChar='{';
	
	// well, this is rather simple so far, because it ignores cross-quoting, but for a first shot it's not too bad ;)
	if (openingChar) {
		while (cursorLocation--) {
			unichar c = [completeString characterAtIndex:cursorLocation];
			if (c == openingChar) {
				if (!skipMatchingBrace) {
					[[textView layoutManager] setTemporaryAttributes:highlightColorAttr forCharacterRange:NSMakeRange(cursorLocation, 1)];
					[self performSelector:@selector(resetBackgroundColor:) withObject:NSStringFromRange(NSMakeRange(cursorLocation, 1)) afterDelay:braceHighlightInterval];
					return;
				} else
					skipMatchingBrace--;
			} else if (c == characterToCheck)
				skipMatchingBrace++;
		}
		if (warn) NSBeep();
	} else { // ok, now reverse the roles and find the closing brace (if any)
		unsigned maxLimit=completeStringLength;
		//if (cursorLocation-maxLimit>4000) maxLimit=cursorLocation+4000; // just a soft limit to not search too far (but I think we're fast enough...)
		if (characterToCheck == '(') openingChar=')';
		else if (characterToCheck == '[') openingChar=']';
		else if (characterToCheck == '{') openingChar='}';		
		if (openingChar) {
			while ((++cursorLocation)<maxLimit) {
				unichar c = [completeString characterAtIndex:cursorLocation];
				if (c == openingChar) {
					if (!skipMatchingBrace) {
						[[textView layoutManager] addTemporaryAttributes:highlightColorAttr forCharacterRange:NSMakeRange(cursorLocation, 1)];
						[self performSelector:@selector(resetBackgroundColor:) withObject:NSStringFromRange(NSMakeRange(cursorLocation, 1)) afterDelay:braceHighlightInterval];
						return;
					} else
						skipMatchingBrace--;
				} else if (c == characterToCheck)
					skipMatchingBrace++;
			}
		}
	}
}

-(void)resetBackgroundColor:(id)sender
{
	// we need to clear the whole BG because the text may have changed in between and we have the old position and not NSRangeFromString(sender)
	[[textView layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:NSMakeRange(0,[[[textView textStorage] string] length])];
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
	if (!deleteBackward) 
		if (showMatchingBraces) [self highlightBracesWithShift:0 andWarn:YES];
	deleteBackward = NO;
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
		NSRange lr = [s lineRangeForRange:ssr]; 
		// line on which enter was pressed - this will be taken as guide
		if (csr.location>0) {
			int i=lr.location;
			int last=csr.location;
			int whiteSpaces=0, addShift=0;
			BOOL initial=YES;
			NSString *wss=@"\n";
			while (i<last) {
				unichar c=[s characterAtIndex:i];
				if (initial) {
					if (c=='\t' || c==' ') {
						whiteSpaces++;
					}
					else initial=NO;
				}
				if (c=='{') addShift++;
				if (c=='}' && addShift>0) addShift--;
				i++;
			}
			if (whiteSpaces>0)
				wss = [wss stringByAppendingString:[s substringWithRange:NSMakeRange(lr.location,whiteSpaces)]];
			while (addShift>0) { wss=[wss stringByAppendingString:@"\t"]; addShift--; }
			// add an undo checkpoint before actually committing the changes
			if ([[textView undoManager] groupingLevel]>0) {
				[[textView undoManager] endUndoGrouping];
				[[textView undoManager] beginUndoGrouping];
			}
			[textView insertText:wss];
			return YES;
		}
	}
    if (showMatchingBraces) {
		if (commandSelector == @selector(deleteBackward:)) {
//			[self highlightBracesWithShift: -1 andWarn:NO];
			deleteBackward = YES;
		}
		//		if (commandSelector == @selector(deleteBackwardByDecomposingPreviousCharacter:))
		//			[self highlightBracesWithShift: -1 andWarn:NO];
		if (commandSelector == @selector(moveLeft:))
			[self highlightBracesWithShift: -1 andWarn:NO];
		if(commandSelector == @selector(moveRight:))
			[self highlightBracesWithShift: 0 andWarn:NO];
	}	
	return retval;
}

	/*
	 Here we only break the modal loop for the R_Edit call. Wether a window
	 is to be saved on exit or no, is up to Cocoa
	 */ 
- (BOOL)windowShouldClose:(id)sende
{	
	if([[self document] hasREditFlag]) {
		[NSApp stopModal];
		[document setREditFlag: NO];
	}
	return YES;
}

- (void) setEditable: (BOOL) editable
{
	[textView setEditable:editable];
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

- (IBAction)sourceCurrentDocument:(id)sender
{
	if ([[self document] isDocumentEdited]) {
		RSEXP *x=[[REngine mainEngine] evaluateString:@"tempfile()"];
		NSString *fn=nil;
		if (x && (fn=[x string])) {
			if ([[self document] writeToFile:fn ofType:@"R"]) {
				[[RController getRController] sendInput:[NSString stringWithFormat:@"source(\"%@\")\nunlink(\"%@\")", fn, fn]];
			}
		}
	} else {
		NSString *fn=[[self document] fileName];
		if (fn) {
			[[RController getRController] sendInput:[NSString stringWithFormat:@"source(\"%@\")", fn]];
		}
	}
}

@end
