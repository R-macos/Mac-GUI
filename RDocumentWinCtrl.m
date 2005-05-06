/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
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

#import "RGUI.h"
#import "RDocumentWinCtrl.h"
#import "PreferenceKeys.h"
#import "RController.h"
#import "RDocumentController.h"
#import "REngine.h"
#import "REditorTextStorage.h"
#import "RRulerView.h"
#import "REditorToolbar.h"
#import "REngine.h"

BOOL defaultsInitialized = NO;

NSColor *shColorNormal;
NSColor *shColorString;
NSColor *shColorNumber;
NSColor *shColorKeyword;
NSColor *shColorComment;
NSColor *shColorIdentifier;

NSArray *keywordList=nil;

// note: those must match tags in the NIB!
#define hsTypeExact   1
#define hsTypeApprox  2

@implementation RDocumentWinCtrl

+ (void) setDefaultSyntaxHighlightingColors
{
	NSColor *c=[Preferences unarchivedObjectForKey:normalSyntaxColorKey withDefault:nil];
	if (c) shColorNormal = c;
	else shColorNormal=[NSColor colorWithDeviceRed:0.025 green:0.085 blue:0.600 alpha:1.0];
	[shColorNormal retain];
	c=[Preferences unarchivedObjectForKey:stringSyntaxColorKey withDefault:nil];
	if (c) shColorString = c;
	else shColorString=[NSColor colorWithDeviceRed:0.690 green:0.075 blue:0.000 alpha:1.0];
	[shColorString retain];	
	c=[Preferences unarchivedObjectForKey:numberSyntaxColorKey withDefault:nil];
	if (c) shColorNumber = c;
	else shColorNumber=[NSColor colorWithDeviceRed:0.020 green:0.320 blue:0.095 alpha:1.0];
	[shColorNumber retain];
	c=[Preferences unarchivedObjectForKey:keywordSyntaxColorKey withDefault:nil];
	if (c) shColorKeyword = c;
	else shColorKeyword=[NSColor colorWithDeviceRed:0.765 green:0.535 blue:0.035 alpha:1.0];
	[shColorKeyword retain];
	c=[Preferences unarchivedObjectForKey:commentSyntaxColorKey withDefault:nil];
	if (c) shColorComment = c;
	else shColorComment=[NSColor colorWithDeviceRed:0.312 green:0.309 blue:0.309 alpha:1.0];
	[shColorComment retain];
	c=[Preferences unarchivedObjectForKey:identifierSyntaxColorKey withDefault:nil];
	if (c) shColorIdentifier = c;
	else shColorIdentifier=[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0];
	[shColorIdentifier retain]; 
	//	NSLog(@"shColorIdentifier %f %f %f %f", [c redComponent], [c greenComponent], [c blueComponent], [c alphaComponent]);
	
	keywordList = [[NSArray alloc] initWithObjects: 
		@"for", @"if", @"else", @"function", @"TRUE", @"FALSE", @"while",
		@"do", @"NULL", @"Inf", @"NA", @"NaN", @"in", nil];
}

//- (id)init // NOTE: init is *not* used! put any initialization in windowDidLoad

- (void)dealloc {
	if (highlightColorAttr) [highlightColorAttr release];
	if (helpTempFile) [[NSFileManager defaultManager] removeFileAtPath:helpTempFile handler:nil];
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

- (void) setPlain: (BOOL) plain
{
	plainFile=plain;
	if (plain && useHighlighting && textView)
		[textView setTextColor:[NSColor blackColor] range:NSMakeRange(0,[[textView textStorage] length])];
	else if (!plain && useHighlighting && textView)
		[self setHighlighting:YES];
}

- (BOOL) plain
{
	return plainFile;
}

- (id) initWithWindowNibName:(NSString*) nib
{
	self = [super initWithWindowNibName:nib];
	SLog(@"RDocumentWinCtrl.initWithNibName:%@", nib);
	if (self) {
		plainFile=NO;
		hsType=1;
		currentHighlight=-1;
		updating=NO;
		helpTempFile=nil;
		execNewlineFlag=NO;
	}
	return self;
}

// we don't need this one, because the default implementation automatically calls the one w/o owner
// - (id) initWithWindowNibName:(NSString*) nib owner: (id) owner

- (void) windowDidLoad
{
	SLog(@"RDocumentWinCtrl(%@).windowDidLoad", self);
	
	if (!defaultsInitialized) {
		[RDocumentWinCtrl setDefaultSyntaxHighlightingColors];
		defaultsInitialized=YES;
	}
		// For now replaced selectedTextBackgroundColor by redColor
	highlightColorAttr = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor redColor], NSBackgroundColorAttributeName, nil];

	BOOL showLineNos = [Preferences flagForKey:showLineNumbersKey withDefault: NO];
	BOOL lineWrappingEnabled = [Preferences flagForKey:enableLineWrappingKey withDefault: YES];
	if (showLineNos) {
		SLog(@" - line numbers requested");
		// This should probably get loaded from NSUserDefaults.
		NSFont *font = [NSFont fontWithName:@"Monaco" size: 10];
		
		NSSize layoutSize = [textView maxSize];
		layoutSize.width = layoutSize.height;
		if (!lineWrappingEnabled) {
			// Make sure that we don't wrap lines.
			[scrollView setHasHorizontalScroller: YES];
			[textView setHorizontallyResizable: YES]; 
			[textView setMaxSize: layoutSize];
			[[textView textContainer] setWidthTracksTextView: NO];
			[[textView textContainer] setHeightTracksTextView: NO];
			[[textView textContainer] setContainerSize: layoutSize];			
		} else {
			[scrollView setHasHorizontalScroller: NO];
			[textView setHorizontallyResizable: YES]; 
			[textView setMaxSize: layoutSize];
			[[textView textContainer] setWidthTracksTextView: YES];
			[[textView textContainer] setHeightTracksTextView: NO];
			[[textView textContainer] setContainerSize: layoutSize];						
		}
		
		// Create and install our line numbers
		if (theRulerView) [theRulerView release];
		theRulerView = [[RRulerView alloc] initWithScrollView: scrollView orientation: NSVerticalRuler showLineNumbers: showLineNos textView:textView];
		
		[scrollView setHasHorizontalRuler: NO];
		[scrollView setHasVerticalRuler: YES];
		[scrollView setVerticalRulerView: theRulerView];
		[scrollView setRulersVisible: YES];    
		[scrollView setLineScroll: [font pointSize]];
		
		// Add a small pad to the textViews
		float lineFragmentPadding;
		lineFragmentPadding = [[Preferences stringForKey:lineFragmentPaddingWidthKey withDefault: @"6.0"] floatValue];
		[[textView textContainer] setLineFragmentPadding: lineFragmentPadding];
		
		[textView setUsesRuler: YES];
		[textView setFont: font];
		
	}
	SLog(@" - setup views");
	[scrollView setDocumentView:textView];		
    [textView setDelegate: self];
		
	// instead of building the whole text storage network, we just replace the text storage - but ti's not trivial since ts is actually the root of the network
	SLog(@" - replace back-end with REditorTextStorage");
	NSLayoutManager *lm = [[textView layoutManager] retain];
	NSTextStorage *origTS = [[textView textStorage] retain];
	REditorTextStorage * textStorage = [[REditorTextStorage alloc] init];
	[origTS removeLayoutManager:lm];
	[textStorage addLayoutManager:lm];
	[lm release];
	[origTS release];
	
	SLog(@" - setup window, preferences and widgets");
	[[self window] setOpaque:NO]; // Needed so we can see through it when we have clear stuff on top
	[textView setDrawsBackground:NO];
	[[textView enclosingScrollView] setDrawsBackground:NO];
	
	[textView setFont:[[RController getRController] currentFont]];
	[textView setContinuousSpellCheckingEnabled:NO]; // by default no continuous spell checking
	[textView setAllowsUndo: YES];

	SLog(@" - load document contents into textView");
	[(RDocument*)[self document] loadInitialContents];
	[textView setEditable: [[self document] editable]];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		   selector:@selector(textDidChange:)
			   name:NSTextDidChangeNotification
			 object: textView];
	[[textView textStorage] setDelegate:self];
	[self updatePreferences];
	[[Preferences sharedPreferences] addDependent:self];
	
	SLog(@" - setup editor toolbar");
	editorToolbar = [[REditorToolbar alloc] initWithEditor:self];
	SLog(@" - scan document for functions");
	[self functionRescan];
	SLog(@" - windowDidLoad is done");
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification {
	[theRulerView updateView];
}

- (NSUndoManager*) windowWillReturnUndoManager: (NSWindow*) sender
{
	return [[self document] undoManager];
}

- (void) functionReset
{
	SLog(@"RDocumentWinCtrl.functionReset");
	if (fnListBox) {
		NSMenuItem *fmi = [[NSMenuItem alloc] initWithTitle:@"<functions>" action:nil keyEquivalent:@""];
		[fmi setTag:-1];
		[fnListBox removeAllItems];
		[[fnListBox menu] addItem:fmi];
	}
	SLog(@" - reset done");
}

- (void) functionAdd: (NSString*) fn atPosition: (int) pos
{
	if (fnListBox) {
		if ([[[fnListBox menu] itemAtIndex:0] tag]==-1)
			[fnListBox removeAllItems];
		NSMenuItem *mi = [fnListBox itemWithTitle:fn];
		if (!mi) {
			mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(goFunction:) keyEquivalent:@""];
			[mi setTag: pos];
			[[fnListBox menu] addItem:mi];
		} else {
			[mi setTag:pos];
		}
	}
}

- (void) functionGo: (id) sender
{
	NSString *s = [[textView textStorage] string];
	NSMenuItem *mi = (NSMenuItem*) sender;
	int pos = [mi tag];
	if (pos>=0 && pos<[s length]) {
		NSRange fr = NSMakeRange(pos,0);
		[textView setSelectedRange:fr];
		[textView scrollRangeToVisible:fr];
	}
}

- (void) functionRescan
{
	NSTextStorage *ts = [textView textStorage];
	NSString *s = [ts string];
	int oix = 0;
	int pim = 0;
	int sit = 0;
	int fnf = 0;
	NSMenu *fnm = [fnListBox menu];
	NSRange sr = [textView selectedRange];
	
	SLog(@"RDoumentWinCtrl.functionRescan");
	while (1) {
		NSRange r = [s rangeOfString:@"function" options:0 range:NSMakeRange(oix,[s length]-oix)];
		if (r.length<8) break;
		oix=r.location+r.length;
		
		{
			int li = r.location-1;
			SLog(@" - potential function at %d", li);
			unichar fc;
			while (li>0 && ((fc=[s characterAtIndex:li])==' ' || fc=='\t' || fc=='\r' || fc=='\n')) li--;
			if (li>0) {
				fc=[s characterAtIndex:li];
				if (fc=='=' || (fc=='-' && [s characterAtIndex:--li]=='<')) {
					int lci;
					li--;
					SLog(@" - matched =/<- at %d", li);
					while (li>0 && ((fc=[s characterAtIndex:li])==' ' || fc=='\t' || fc=='\r' || fc=='\n')) li--;
					lci=li;
					while (li>=0 && (((fc=[s characterAtIndex:li])>='0' && fc<='9')||(fc>='a' && fc<='z')||(fc>='A' && fc<='Z')||
									 fc=='.'||fc=='_')) li--;
					if (lci!=li) {
						NSString *fn = [s substringWithRange:NSMakeRange(li+1,lci-li)];
						int fp = li+1;
						NSMenuItem *mi = nil;
						SLog(@" - found identifier %d:%d \"%@\"", li+1, lci-li, fn);
						fnf++;
						if (fp<sr.location) sit=pim;
						if (pim<[fnm numberOfItems]) {
							mi = (NSMenuItem*) [fnm itemAtIndex:pim];
							if ([[mi title] isEqual:fn]) {
								SLog(@" - replacing function at %d (title match)", pim);
								[mi setTag:fp];
								pim++;
							} else if ([mi tag]==fp) {
								SLog(@" - replacing function at %d (position match)", pim);
								if (![[mi title] isEqual:fn])
									[mi setTitle:fn];
								pim++;
							} else {
								while (mi && [mi tag]<fp) {
									[fnm removeItemAtIndex:pim];
									mi=nil;
									if (pim<[fnm numberOfItems])
										mi=(NSMenuItem*) [fnm itemAtIndex:pim];
								}
								if (mi) {
									SLog(@" - inserting at %d", pim);
									mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
									[mi setTag:fp];
									[mi setTarget:self];
									[fnm insertItem:mi atIndex:pim];
									pim++;
								}
							}
						}
						if (!mi && pim>=[fnm numberOfItems]) {
							SLog(@" - appending");
							mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
							[mi setTag:fp];
							[mi setTarget:self];
							[fnm addItem:[mi autorelease]];
							pim++;
						} 
					}
				}
			}
		}
	}
	while (pim<[fnm numberOfItems])
		[fnm removeItemAtIndex:pim];
	if (fnf==0)
		[self functionReset];
	else
		[fnListBox selectItemAtIndex:sit];
	SLog(@" - rescan finished (%d functions)", fnf);
}

- (void) updatePreferences {
	SLog(@"RDocumentWinCtrl.updatePreferences");
	NSColor *c = [Preferences unarchivedObjectForKey: backgColorKey withDefault: nil];
	if (c && c!=[[self window] backgroundColor]) {
		[[self window] setBackgroundColor:c];
		//		[[self window] display];
	}
	c=[Preferences unarchivedObjectForKey:normalSyntaxColorKey withDefault:nil];
	if (c) shColorNormal = c;
	c=[Preferences unarchivedObjectForKey:stringSyntaxColorKey withDefault:nil];
	if (c) shColorString = c;
	c=[Preferences unarchivedObjectForKey:numberSyntaxColorKey withDefault:nil];
	if (c) shColorNumber = c;
	c=[Preferences unarchivedObjectForKey:keywordSyntaxColorKey withDefault:nil];
	if (c) shColorKeyword = c;
	c=[Preferences unarchivedObjectForKey:commentSyntaxColorKey withDefault:nil];
	if (c) shColorComment = c;
	c=[Preferences unarchivedObjectForKey:identifierSyntaxColorKey withDefault:nil];
	if (c) shColorIdentifier = c;
	
	[self setHighlighting:[Preferences flagForKey:showSyntaxColoringKey withDefault: YES]];
	showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault: YES];
	braceHighlightInterval = [[Preferences stringForKey:highlightIntervalKey withDefault: @"0.2"] doubleValue];
	[self updateSyntaxHighlightingForRange:NSMakeRange(0,[[textView textStorage] length])];
	[textView setNeedsDisplay:YES];
	SLog(@" - preferences updated");
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


- (IBAction)goToLine:(id)sender
{
	[NSApp beginSheet: goToLineSheet modalForWindow: [self window] modalDelegate: goToLineSheet didEndSelector: @selector(orderOut:) contextInfo: nil];
}

- (IBAction)goToLineCloseSheet:(id)sender
{
	if ([((NSButton*) sender) tag] == 1) { // OK
		NSString *s = [[textView textStorage] string];
		int l = [goToLineField intValue];
		// I know of no simple way to determine line #s, so let's just count them
		int i=0, cl=1, tl = [s length];
		if (l<1) l=1;
		if (tl>0) {		
			if (cl!=l) while (i<tl) {
				if ([s characterAtIndex:i]=='\n') { // we could use indexOf, but ...
					cl++;
					if (cl==l) break;
				}
				i++;
			};
			if (l>1) i++; // get past the detected newline
			if (i>=tl) i=tl-1; // make sure the range is valid
			[textView setSelectedRange:NSMakeRange(i,0)];
		}
	}
    [NSApp endSheet:goToLineSheet];
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
	
	int i = range.location;    // index in the string
	int bb = i;                // index of the beginning of the currently detected segment
	int last = i+range.length; // proposed stop - index behind the last character (must be <=hardStop)
	int hardStop = last;       // hard-stop; it is ok to look beyond last when necessary, but not ok to look beyond hardStop
	BOOL foundItem=NO;
	
	SLog(@"RDocumentWinCtrl(%@).updateSyntaxHL: %d:%d (%d/%d)", self, range.location, range.length, (int)useHighlighting, (int)plainFile);

	if (!keywordList) [RDocumentWinCtrl setDefaultSyntaxHighlightingColors];

	if ([self document] == nil) {
		SLog(@" - no document, skipping.");
		return;
	}

	if (range.length<1 || updating || !useHighlighting || plainFile) {
		SLog(@" - no need to update, skipping.");
		return;
	}
	updating=YES;

	
	NSDictionary *trailAttr = nil;
	int trailPos = 0;
	
	if (last>0 && last<[s length]) {
		int sl = [s length];
		unichar c;

		trailPos=last+1;
		while (trailPos<sl && ((c = [s characterAtIndex:trailPos])==' ' || c=='\n' || c=='\r' || c=='\t')) trailPos++;
		if (trailPos>=[s length]) {
			hardStop = last = [s length]; trailPos=0;
		} else {
			NSRange efr;
			last = trailPos--;
			hardStop = [s length]; // feel free to go up to the end if necessary (in fact max(last+64,[s length]) should be sufficient, but it shouldn't matter)
			trailAttr = [ts attributesAtIndex:trailPos effectiveRange:&efr];
			//SLog(@"trailDict: %@, last was %d and is now %d", trailAttr, last, trailPos);
		}
	}
	
	[ts beginEditing];
reHilite:
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
			// unlike all others id/keyword use hardStop, because keywords cannot be determined until the entire string is known
			while (i<hardStop && ((c=[s characterAtIndex:i])=='_' || c=='.' || (c>='a' && c<='z') || (c>='A' && c<='Z') || (c>='0' && c<='9'))) i++;
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
			if (i>=last) break;
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

	if (trailAttr) { // it's partial update and there is trailing contents - let's check whether we need to go beyond the required scope
		NSRange efr;
		NSDictionary *newAttr = [ts attributesAtIndex:trailPos effectiveRange:&efr];
		NSString *oldA = (NSString*) [trailAttr objectForKey:@"shType"];
		NSString *newA = (NSString*) [newAttr objectForKey:@"shType"];
		if (oldA && newA && ![oldA isEqual:newA]) {  // trailing contents must be changed, too
			SLog(@" - syntaxHL: old [%@] new [%@] at %d - need to re-process to the end of the file", oldA, newA, trailPos);
			trailAttr=nil;
			last=[s length];
			bb = i = range.location; // the HL code doesn't support continuation out of the loop, because of the inner loops, so we just re-do it all ...
			goto reHilite;
		}
	}
	SLog(@" - sh done, rescan and finish");
	[self functionRescan];
	[ts endEditing];
	updating=NO;
	SLog(@" - finished syntax hilite, whew ..");
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
	
	[(REditorTextStorage*)[textView textStorage] resetHighlights];
	if (characterToCheck == ')') openingChar='(';
	else if (characterToCheck == ']') openingChar='[';
	else if (characterToCheck == '}') openingChar='{';
	
	// well, this is rather simple so far, because it ignores cross-quoting, but for a first shot it's not too bad ;)
	if (openingChar) {
		while (cursorLocation--) {
			unichar c = [completeString characterAtIndex:cursorLocation];
			if (c == openingChar) {
				if (!skipMatchingBrace) {
					[(REditorTextStorage*)[textView textStorage] highlightCharacter:cursorLocation];
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
						[(REditorTextStorage*)[textView textStorage] highlightCharacter:cursorLocation];
						return;
					} else
						skipMatchingBrace--;
				} else if (c == characterToCheck)
					skipMatchingBrace++;
			}
		}
	}
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
	NSTextStorage *ts = [aNotification object];
	NSString *s = [ts string];
	NSRange er = [ts editedRange];
	
	/* get all lines that span the range that was affected. this impementation updates only lines containing the change, not beyond */
	NSRange lr = [s lineRangeForRange:er];
	
	//lr.length = [ts length]-lr.location; // change everything up to the end of the document ...
	
	SLog(@"line range %d:%d (original was %d:%d)", lr.location, lr.length, er.location, er.length);
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
			deleteBackward = YES;
		}
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

- (BOOL)windowShouldClose:(id)sender
{	
	if([[self document] hasREditFlag]) {
		[NSApp stopModal];
		[(RDocument*)[self document] setREditFlag: NO];
	}
	[[[RDocumentController sharedDocumentController] currentDocument] close];
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

- (IBAction)setHelpSearchType:(id)sender
{
	NSMenuItem *mi = (NSMenuItem*) sender;
	NSMenu *m = [mi menu];
	int hst = [mi tag];
	if (mi && m && hst!=hsType) {
		SLog(@"setHelpSearchType: old=%d, new=%d", hsType, hst);
		NSMenuItem *cmi = [m itemWithTag:hsType];
		if (cmi) [cmi setState:NSOffState];
		hsType = hst;
		[mi setState:NSOnState];
	}
}

- (IBAction)goHelpSearch:(id)sender
{
	NSSearchField *sf = (NSSearchField*) sender;
	NSString *ss = [sf stringValue];
	SLog(@"RDocumentWinCtrl.goHelpSearch: \"%@\", type=%d", ss, hsType);
	if ([ss length]<1)
		[helpDrawer close];
	else {
		[helpDrawer open];
		switch (hsType) {
			case hsTypeExact: {
				RSEXP *x = [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try(help(\"%@\"),silent=TRUE)", ss]];
				if (x) {
					NSString *path = [x string];
					if (path) {
						NSString *url = [NSString stringWithFormat:@"file://%@",path];
						[[helpWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
					}
					[x release];
				}
				break;
			}
			case hsTypeApprox: {
				if (!helpTempFile)
					helpTempFile = [NSString stringWithFormat:@"/tmp/RguiHS%x", (int) self];
				SLog(@" - approx search will use %@", helpTempFile);
				RSEXP * x= [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try({function(a){sink('%@'); cat(paste('<html><table>',paste('<tr><td><b>',a[,1],'</b> (<a href=\"file://',a[,4],'/html/00Index.html\">',a[,3],'</a></td><td>',a[,2],'</td></tr>',sep='',collapse=''),'</table></html>',sep=''));sink();'OK'}}(help.search(\"%@\")$matches),silent=TRUE)", helpTempFile, ss]];
				SLog(@" - resulting SEXP=%@", x);
				if (x && [x string] && [[x string] isEqual:@"OK"]) {
					NSString *url = [NSString stringWithFormat:@"file://%@",helpTempFile];
					[[helpWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
				}
				[x release];
				break;
			}
		}
	}
}

- (NSView*) searchToolbarView
{
	return searchToolbarView;
}

- (NSView*) fnListView
{
	return fnListView;
}

@end
