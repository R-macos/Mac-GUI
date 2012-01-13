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
#import "REngine/REngine.h"
#import "Tools/FileCompletion.h"
#import "Tools/CodeCompletion.h"
#import "RegexKitLite.h"
#import "RTextView.h"
#import "HelpManager.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif

BOOL defaultsInitialized = NO;

NSColor *shColorNormal;
NSColor *shColorString;
NSColor *shColorNumber;
NSColor *shColorKeyword;
NSColor *shColorComment;
NSColor *shColorIdentifier;

NSInteger _alphabeticSort(id string1, id string2, void *reverse);

@implementation RDocumentWinCtrl

//- (id)init { // NOTE: init is *not* used! put any initialization in windowDidLoad

static RDocumentWinCtrl *staticCodedRWC = nil;

// FIXME: this is a very, very ugly hack to work around a bug in Cocoa: 
// "Customize Toolbar.." creates a copy of the custom views in the tollbar and
// one of it is the help search view (defined in the RDocument NIB). It turns
// out that a copy is made by encoding and decoding it. However, due to some
// strange bug in Cocoa this leads to instantiation of RDocumentWinCtrl via initWithCoder:
// which is then released immediately. This leads to a crash, so we work
// around this by retaining that copy thus making sure it won't be released.
// In order to reduce the memory overhead we keep around only one instance
// of this "special" controller and keep returning it.
- (id)initWithCoder: (NSCoder*) coder {
	SLog(@"RDocumentWinCtrl.initWithCoder<%@>: %@ **** this is due to a bug in Cocoa! Working around it:", self, coder);
	if (!staticCodedRWC) {
		staticCodedRWC = [super initWithCoder:coder];
		SLog(@" - creating static answer: %@", staticCodedRWC);
	} else {
		SLog(@" - release original, return static answer %@", staticCodedRWC);
		[self release];
		self = staticCodedRWC;
	}
	return [self retain]; // add a retain because it will be matched by the caller
}

- (void)dealloc {
	SLog(@"RDocumentWinCtrl.dealloc<%@>", self);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[Preferences sharedPreferences] removeDependent:self];
	[texItems release];
	if (helpTempFile) [[NSFileManager defaultManager] removeFileAtPath:helpTempFile handler:nil];
	if (functionMenuInvalidAttribute) [functionMenuInvalidAttribute release];
	if (functionMenuCommentAttribute) [functionMenuCommentAttribute release];
	[super dealloc];
}

/**
 * Sort function (mainly used to sort the words in the textView)
 */
NSInteger _alphabeticSort(id string1, id string2, void *reverse)
{
	return [string1 localizedCaseInsensitiveCompare:string2];
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:prefShowArgsHints])
		argsHints = [Preferences flagForKey:prefShowArgsHints withDefault:YES];
	else if ([keyPath isEqualToString:showBraceHighlightingKey])
		showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault:YES];

}

- (void) replaceContentsWithRtf: (NSData*) rtfContents
{
	[textView replaceCharactersInRange:
		NSMakeRange(0, [[textView textStorage] length])
							   withRTF:rtfContents];
	[textView setSelectedRange:NSMakeRange(0,0)];
}

- (void)layoutTextView
{
	[[textView layoutManager] ensureLayoutForCharacterRange:NSMakeRange([[textView string] length],0)];
}

- (void) replaceContentsWithString: (NSString*) strContents
{
	[textView setString:strContents];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	[textView setSelectedRange:NSMakeRange(0,0)];
	[self performSelector:@selector(layoutTextView) withObject:nil afterDelay:0.5];
#endif
	[textView performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.05];
	[[self window] setDocumentEdited:NO];
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
		[textView performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.0];
}

- (BOOL) plain
{
	return plainFile;
}

- (BOOL) isRdDocument
{
	return ([[[self document] fileType] isEqualToString:ftRdDoc]) ? YES : NO;
}

// fileEncoding is passed through to the document - bound by the save box
- (int) fileEncoding
{
	SLog(@"%@ fileEncoding (%@ gives %d)", self, [self document], [[self document] fileEncoding]);
	return [[self document] fileEncoding];
}

- (void) setFileEncoding: (int) encoding
{
	SLog(@"%@ setFileEncoding: %d (doc %@)", self, encoding, [self document]);
	[[self document] setFileEncoding:encoding];
}

- (id) initWithWindowNibName:(NSString*) nib
{
	self = [super initWithWindowNibName:nib];
	SLog(@"RDocumentWinCtrl<%@>.initWithNibName:%@", self, nib);
	if (self) {
		plainFile=NO;
		hsType=1;
		currentHighlight=-1;
		updating=NO;
		helpTempFile=nil;
		execNewlineFlag=NO;

		texItems = [[NSArray arrayWithObjects:
			@"R",
			@"RdOpts",
			@"Rdversion",
			@"CRANpkg",
			@"S3method",
			@"S4method",
			@"Sexpr",
			@"acronym",
			@"alias",
			@"arguments",
			@"author",
			@"begin",
			@"bold",
			@"cite",
			@"code",
			@"command",
			@"concept",
			@"cr",
			@"dQuote",
			@"deqn",
			@"describe",
			@"description",
			@"details",
			@"dfn",
			@"docType",
			@"dontrun",
			@"dontshow",
			@"donttest",
			@"dots",
			@"email",
			@"emph",
			@"enc",
			@"encoding",
			@"end",
			@"enumerate",
			@"env",
			@"eqn",
			@"examples",
			@"file",
			@"format",
			@"ge",
			@"href",
			@"if",
			@"ifelse",
			@"item",
			@"itemize",
			@"kbd",
			@"keyword",
			@"ldots",
			@"left",
			@"link",
			@"linkS4class",
			@"method",
			@"name",
			@"newcommand",
			@"note",
			@"option",
			@"out",
			@"pkg",
			@"preformatted",
			@"references",
			@"renewcommand",
			@"right",
			@"sQuote",
			@"samp",
			@"section",
			@"seealso",
			@"source",
			@"special",
			@"strong",
			@"subsection",
			@"synopsis",
			@"tab",
			@"tabular",
			@"testonly",
			@"title",
			@"url",
			@"usage",
			@"value",
			@"var",
			@"verb",
			nil] retain];

		// TODO control font size due to tollbar setting small or normal
		functionMenuInvalidAttribute = [[NSDictionary dictionaryWithObjectsAndKeys:
			[NSColor redColor], NSForegroundColorAttributeName,
			[NSFont menuFontOfSize:0], NSFontAttributeName,
		nil] retain];
		functionMenuCommentAttribute =[[NSDictionary dictionaryWithObjectsAndKeys:
			[NSColor grayColor], NSForegroundColorAttributeName,
			[NSFont menuFontOfSize:0], NSFontAttributeName,
		nil] retain];

		[self setShouldCloseDocument:YES];

		[[NSNotificationCenter defaultCenter] addObserver:self 
							 selector:@selector(helpSearchTypeChanged) 
							     name:@"HelpSearchTypeChanged" 
							   object:nil];

		[[NSNotificationCenter defaultCenter] 
			addObserver:self
			   selector:@selector(RDocumentDidResize:)
				   name:NSWindowDidResizeNotification
				 object:nil];

	}
	return self;
}

// we don't need this one, because the default implementation automatically calls the one w/o owner
// - (id) initWithWindowNibName:(NSString*) nib owner: (id) owner

- (void) windowDidLoad
{

	SLog(@"RDocumentWinCtrl(%@).windowDidLoad", self);

	showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault: YES];
	argsHints = [Preferences flagForKey:prefShowArgsHints withDefault:YES];

	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:showBraceHighlightingKey options:NSKeyValueObservingOptionNew context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:prefShowArgsHints options:NSKeyValueObservingOptionNew context:NULL];

	[[self window] setBackgroundColor:[NSColor clearColor]];
	[[self window] setOpaque:NO];

	SLog(@" - load document contents into textView");
	[(RDocument*)[self document] loadInitialContents];

	// If not line wrapping update textView explicitly in order to set scrollView correctly
	if(![Preferences flagForKey:enableLineWrappingKey withDefault: YES])
		[textView updateLineWrappingMode];

	SLog(@" - scan document for functions");
	[self functionRescan];

	[[textView undoManager] removeAllActions];

	[self helpSearchTypeChanged];

	if(plainFile) [fnListBox setHidden:YES];

	[super windowDidLoad];

	SLog(@" - windowDidLoad is done");

	return;

}

- (void) RDocumentDidResize: (NSNotification *)notification
{
	[self setStatusLineText:[self statusLineText]];
}

- (NSView*) saveOpenAccView
{
	return saveOpenAccView;
}

- (NSUndoManager*) windowWillReturnUndoManager: (NSWindow*) sender
{
	return [[self document] undoManager];
}

- (void) setStatusLineText: (NSString*) text
{

	SLog(@"RDocumentWinCtrl.setStatusLine: \"%@\"", [text description]);

	if(text == nil || ![text length]) {
		[statusLine setStringValue:@""];
		[statusLine setToolTip:@""];
		return;
	}

	// Adjust status line to show a single line in the middle of the status bar
	// otherwise to come up with at least two visible lines
	float w = NSSizeToCGSize([text sizeWithAttributes:[NSDictionary dictionaryWithObject:[statusLine font] forKey:NSFontAttributeName]]).width + 2.0f;
	NSSize p = [statusLine frame].size;
	p.height = (w > p.width) ? 22 : 17;
	[statusLine setFrameSize:p];
	[statusLine setNeedsDisplay:YES];
	// Run NSDefaultRunLoopMode to allow to update status line
	[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
							 beforeDate:[NSDate distantPast]];
	[statusLine setToolTip:text];
	[statusLine setStringValue:text];

}

- (BOOL) hintForFunction: (NSString*) fn
{

	BOOL success = NO;

	if([[self document] hasREditFlag]) {
		[self setStatusLineText:NLS(@"(arguments lookup is disabled while R is busy)")];
		return NO;
	}

	if (preventReentrance && insideR>0) {
		[self setStatusLineText:NLS(@"(arguments lookup is disabled while R is busy)")];
		return NO;
	}
	if (![[REngine mainEngine] beginProtected]) {
		[self setStatusLineText:NLS(@"(arguments lookup is disabled while R is busy)")];
		return NO;		
	}
	RSEXP *x = [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try(gsub('\\\\s+',' ',paste(capture.output(print(args(%@))),collapse='')),silent=TRUE)", fn]];
	if (x) {
		NSString *res = [x string];
		if (res && [res length]>10 && [res hasPrefix:@"function"]) {
			NSRange lastClosingParenthesis = [res rangeOfString:@")" options:NSBackwardsSearch];
			if(lastClosingParenthesis.length) {
				res = [res substringToIndex:NSMaxRange(lastClosingParenthesis)];
				res = [fn stringByAppendingString:[res substringFromIndex:9]];
				success = YES;
				[self setStatusLineText:res];
			}
		}
		[x release];
	}
	[[REngine mainEngine] endProtected];
	return success;
}

- (NSString*) statusLineText
{
	return [statusLine stringValue];
}

- (void) functionReset
{
	SLog(@"RDocumentWinCtrl.functionReset");
	if (fnListBox) {
		NSString *placeHolderStr = @"";
		NSString *tooltipStr = @"";
		if([[[self document] fileType] isEqualToString:ftRSource]) {
			placeHolderStr = NLS(@"<functions>");
			tooltipStr = NLS(@"List of Functions");
		}
		else if([[[self document] fileType] isEqualToString:ftRdDoc]) {
			placeHolderStr = NLS(@"<sections>");
			tooltipStr = NLS(@"List of Sections");
		}
		NSMenuItem *fmi = [[NSMenuItem alloc] initWithTitle:placeHolderStr action:nil keyEquivalent:@""];
		[fmi setTag:-1];
		[fnListBox removeAllItems];
		[fnListBox setToolTip:tooltipStr];
		[[fnListBox menu] addItem:fmi];
		[fmi release];
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

	// Cancel pending functionRescan calls
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(functionRescan) 
							object:nil];

	if(plainFile) {
		return;
	}

	[fnListBox setEnabled:NO];

	NSTextStorage *ts = [textView textStorage];
	NSString *s = [ts string];
	unsigned long strLength = [s length];
	int oix = 0;
	int pim = 0;
	int sit = 0;
	int fnf = 0;
	NSMenu *fnm = [fnListBox menu];
	NSRange sr = [textView selectedRange];
	[self functionReset];

	if([s length]<8) return;

	SLog(@"RDoumentWinCtrl.functionRescan");
	if([[[self document] fileType] isEqualToString:ftRSource]) {
		while (1) {
			NSRange r = [s rangeOfRegex:@"\\bfunction\\s*\\(" inRange:NSMakeRange(oix,strLength-oix)];
			if (r.length<8) break;
			oix=NSMaxRange(r);
			int li = r.location-1;
			SLog(@" - potential function at %d", li);
			unichar fc;
			while (li>0 && ((fc=CFStringGetCharacterAtIndex((CFStringRef)s, li)) ==' ' || fc=='\t' || fc=='\r' || fc=='\n')) li--;
			if (li>0) {
				fc=CFStringGetCharacterAtIndex((CFStringRef)s, li);
				if (fc=='=' || (fc=='-' && CFStringGetCharacterAtIndex((CFStringRef)s, --li)=='<')) {
					int lci;
					li--;
					SLog(@" - matched =/<- at %d", li);
					while (li>0 && ((fc=CFStringGetCharacterAtIndex((CFStringRef)s, li)) ==' ' || fc=='\t' || fc=='\r' || fc=='\n')) li--;
					lci=li;
					// while (li>=0 && (((fc=CFStringGetCharacterAtIndex((CFStringRef)s, li))>='0' && fc<='9')||(fc>='a' && fc<='z')||(fc>='A' && fc<='Z')|| //(fc>=0x00C && fc<=0xFF9F)||
					// 				 fc=='.'||fc=='_')) li--;
					while (li>=0 && ((fc=CFStringGetCharacterAtIndex((CFStringRef)s, li)) !='\n' && fc!=' ' && fc!='\r' && fc!='\t' && fc!=';' && fc!='#')) li--;
					if (lci!=li) {

						NSString *fn = [s substringWithRange:NSMakeRange(li+1,lci-li)];

						int type = 1; // invalid function name
						if([textView parserContextForPosition:li+2] == 4)
							type = 2; // function declaration is commented out
						else if([fn isMatchedByRegex:@"^[[:alpha:]\\.]"])
							type = 0; // function name is valid

						int fp = li+1;

						NSMenuItem *mi = nil;
						SLog(@" - found identifier %d:%d \"%@\"", li+1, lci-li, fn);
						fnf++;
						if (fp<=sr.location) sit=pim;
						mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
						if(type == 1) {
							NSAttributedString *fna = [[NSAttributedString alloc] initWithString:fn attributes:functionMenuInvalidAttribute];
							[mi setAttributedTitle:fna];
							[fna release];
						}
						else if(type == 2) {
							NSAttributedString *fna = [[NSAttributedString alloc] initWithString:fn attributes:functionMenuCommentAttribute];
							[mi setAttributedTitle:fna];
							[fna release];
						}
						[mi setTag:fp];
						[mi setTarget:self];
						[fnm addItem:mi];
						[mi release];
						pim++;
					}
				}
			}
		}
	}
	else if([[[self document] fileType] isEqualToString:ftRdDoc]) {
		while (1) {
			NSError *err = nil;
			NSRange r = [s rangeOfRegex:@"\\\\(s(ynopsis\\{|ource\\{|e(ction\\{|ealso\\{))|Rd(Opts\\{|version\\{)|n(ote\\{|ame\\{)|concept\\{|title\\{|Sexpr(\\{|\\[)|d(ocType\\{|e(scription\\{|tails\\{))|usage\\{|e(ncoding\\{|xamples\\{)|value\\{|keyword\\{|format\\{|a(uthor\\{|lias\\{|rguments\\{)|references\\{)" options:0 inRange:NSMakeRange(oix,strLength-oix) capture:1 error:&err];
			// RdOpts{, Rdversion{, Sexpr[, Sexpr{, alias{, arguments{, author{, concept{, description{, details{, docType{, encoding{, examples{, format{, keyword{, name{, note{, references{, section{, seealso{, source{, synopsis{, title{, usage{, value{
			if (!r.length) break;
			oix=NSMaxRange(r);
			SLog(@" - potential section at %d", r.location);
			// due to finial bracket decrease range length by 1
			r.length--;
			NSString *fn = [s substringWithRange:r];

			int li = r.location-1;

			unichar fc;
			while (li>0 && ((fc=CFStringGetCharacterAtIndex((CFStringRef)s, li)) ==' ' || fc=='\t' || fc=='\r' || fc=='\n')) li--;

			int type = 0; // invalid function name
			if([textView parserContextForPosition:li+2] == 4)
				type = 2; // function declaration is commented out
			// else if([fn isMatchedByRegex:@"^[[:alpha:]\\.]"])
			// 	type = 0; // function name is valid

			int fp = r.location-1;
			
			NSMenuItem *mi = nil;
			// SLog(@" - found identifier %d:%d \"%@\"", li+1, lci-li, fn);
			fnf++;
			if (fp<=sr.location) sit=pim;
			mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
			if(type == 2) { // section was commented out
				NSAttributedString *fna = [[NSAttributedString alloc] initWithString:fn attributes:functionMenuCommentAttribute];
				[mi setAttributedTitle:fna];
				[fna release];
			}
			[mi setTag:fp];
			[mi setTarget:self];
			[fnm addItem:mi];
			[mi release];
			pim++;
		}
	}
	if (fnf) {
		[fnListBox setEnabled:YES];
		[fnListBox removeItemAtIndex:0];
		[fnListBox selectItemAtIndex:sit];
	}

	SLog(@" - rescan finished (%d sections)", fnf);
}

- (void) updatePreferences {
	SLog(@"RDocumentWinCtrl.updatePreferences");
	// for sanity's sake
	// if (!defaultsInitialized) {
	// 	[RDocumentWinCtrl setDefaultSyntaxHighlightingColors];
	// 	defaultsInitialized=YES;
	// }
	// 
	// NSColor *c = [Preferences unarchivedObjectForKey: backgColorKey withDefault: nil];
	// if (c && c != [[self window] backgroundColor]) {
	// 	[[self window] setBackgroundColor:c];
	// 	//		[[self window] display];
	// }
	// c=[Preferences unarchivedObjectForKey:normalSyntaxColorKey withDefault:nil];
	// if (c) { [shColorNormal release]; shColorNormal = [c retain]; [textView setInsertionPointColor:c]; }
	// c=[Preferences unarchivedObjectForKey:stringSyntaxColorKey withDefault:nil];
	// if (c) { [shColorString release]; shColorString = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:numberSyntaxColorKey withDefault:nil];
	// if (c) { [shColorNumber release]; shColorNumber = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:keywordSyntaxColorKey withDefault:nil];
	// if (c) { [shColorKeyword release]; shColorKeyword = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:commentSyntaxColorKey withDefault:nil];
	// if (c) { [shColorComment release]; shColorComment = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:identifierSyntaxColorKey withDefault:nil];
	// if (c) { [shColorIdentifier release]; shColorIdentifier = [c retain]; }

	// argsHints=[Preferences flagForKey:prefShowArgsHints withDefault:YES];
	// 
	// [self setHighlighting:[Preferences flagForKey:showSyntaxColoringKey withDefault: YES]];
	// showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault: YES];
	// [textView setNeedsDisplay:YES];
	SLog(@" - preferences updated");
}

- (IBAction)saveDocumentAs:(id)sender
{

	RDocument *cd = [[RDocumentController sharedDocumentController] currentDocument];

	// if cd document is a REdit call do not allow to save it under another name
	// to preserving REdit editing
	if (cd && [cd hasREditFlag]) {
		[cd saveDocument:sender];
		return;
	}
	[cd saveDocumentAs:sender];
}

- (IBAction)saveDocument:(id)sender
{

	RDocument *cd = [[RDocumentController sharedDocumentController] currentDocument];

	// if cd document is a REdit call ensure that the last character is a line ending
	// to avoid error in edit()
	if (cd && [cd hasREditFlag]) {
		NSRange selectedRange = [textView selectedRange];
		if(![[textView string] length])
			[[[textView textStorage] mutableString] setString:@"\n"];
		if([[textView string] characterAtIndex:[[textView string] length]-1] != '\n') {
			[[[textView textStorage] mutableString] appendString:@"\n"];
			[textView setSelectedRange:NSIntersectionRange(selectedRange, NSMakeRange(0, [[textView string] length]))];
		}
	}
	[cd saveDocument:sender];
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

	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
	[self updatePreferences];
}

- (IBAction)reInterpretDocument:(id)sender;
{

	RDocument* doc = [[NSDocumentController sharedDocumentController] documentForWindow:[NSApp keyWindow]];
	if(doc)
		[doc reinterpretInEncoding:(NSStringEncoding)[[sender representedObject] unsignedIntValue]];
	else
		NSBeep();

}

- (IBAction)shiftRight:(id)sender
{
	[textView shiftSelectionRight];
}

- (IBAction)shiftLeft:(id)sender
{
	[textView shiftSelectionLeft];
}

- (IBAction)goToLine:(id)sender
{
	[NSApp beginSheet:goToLineSheet
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:@"goToLine"];
}

- (IBAction)goToLineCloseSheet:(id)sender
{
	[NSApp endSheet:goToLineSheet returnCode:[sender tag]];
}

- (void) setHighlighting: (BOOL) use
{
	useHighlighting=use;
	if (textView) {
		if (use)
			[textView performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.0];
		else
			[textView setTextColor:[NSColor blackColor] range:NSMakeRange(0,[[textView textStorage] length])];
	}
}

- (void)highlightBracesAfterDidProcessEditing
{
	[self highlightBracesWithShift:0 andWarn:YES];
}

- (void) highlightBracesWithShift: (int) shift andWarn: (BOOL) warn
{

	NSString *completeString = [[textView textStorage] string];
	NSUInteger completeStringLength = [completeString length];
	if (completeStringLength < 2) return;
	
	NSRange selRange = [textView selectedRange];
	NSInteger cursorLocation = selRange.location;
	cursorLocation += shift; // add any shift as cursor movement guys need it
	if (cursorLocation < 0 || cursorLocation >= completeStringLength) return;

	// bail if current character is in quotes or comments
	if([textView parserContextForPosition:cursorLocation] != pcExpression) return;

	unichar characterToCheck;
	unichar openingChar = 0;
	characterToCheck = [completeString characterAtIndex:cursorLocation];
	int skipMatchingBrace = 0;
	
	[textView resetHighlights];
	if (characterToCheck == ')') openingChar='(';
	else if (characterToCheck == ']') openingChar='[';
	else if (characterToCheck == '}') openingChar='{';
	
	// well, this is rather simple so far, because it ignores cross-quoting, but for a first shot it's not too bad ;)
	if (openingChar) {
		while (cursorLocation--) {
			unichar c = [completeString characterAtIndex:cursorLocation];
			if([textView parserContextForPosition:cursorLocation] == pcExpression) {
				if (c == openingChar) {
					if (!skipMatchingBrace) {
						[textView highlightCharacter:cursorLocation];
						return;
					} else
						skipMatchingBrace--;
				} else if (c == characterToCheck)
					skipMatchingBrace++;
			}
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
				if([textView parserContextForPosition:cursorLocation] == pcExpression) {
					if (c == openingChar) {
						if (!skipMatchingBrace) {
							[textView highlightCharacter:cursorLocation];
							return;
						} else
							skipMatchingBrace--;
					} else if (c == characterToCheck)
						skipMatchingBrace++;
				}
			}
		}
	}
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

		if(![[NSUserDefaults standardUserDefaults] boolForKey:indentNewLines]) return NO;

		// handling of indentation
		// currently we just copy what we get and add tabs for additional non-matched { brackets
		NSTextStorage *ts = [textView textStorage];
		NSString *s = [ts string];
		NSRange csr = [textView selectedRange];
		NSRange ssr = NSMakeRange(csr.location, 0);
		NSRange lr = [s lineRangeForRange:ssr];

		[self setStatusLineText:@""];
		// line on which enter was pressed - this will be taken as guide
		if (csr.location>0) {
			int i = lr.location;
			int last = csr.location;
			int whiteSpaces = 0, addShift = 0;
			BOOL initial=YES;
			BOOL caretIsAdjacentCurlyBrackets = NO;
			NSString *wss = @"\n";
			NSString *wssForClosingCurlyBracket = @"";
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
			if(last > 0 && [s characterAtIndex:last-1] == '{' && last < NSMaxRange(lr) && [s characterAtIndex:last] == '}') {
				wssForClosingCurlyBracket = [NSString stringWithString:wss];
				caretIsAdjacentCurlyBrackets = YES;
			}
			while (addShift>0) { wss=[wss stringByAppendingString:@"\t"]; addShift--; }
			// add an undo checkpoint before actually committing the changes
			[textView breakUndoCoalescing];
			[textView insertText:wss];

			// if caret is adjacent by {} add new line with the original indention
			// and place the caret one line up at the line's end
			if(caretIsAdjacentCurlyBrackets) {
				[textView insertText:wssForClosingCurlyBracket];
				[textView doCommandBySelector:@selector(moveUp:)];
				[textView doCommandBySelector:@selector(moveToEndOfLine:)];
			}
			return YES;
		}
	}
	if (showMatchingBraces && ![self plain]) {
		if (commandSelector == @selector(deleteBackward:)) {
			[textView setDeleteBackward:YES];
		}
		if (commandSelector == @selector(moveLeft:))
			[self highlightBracesWithShift: -1 andWarn:NO];
		if(commandSelector == @selector(moveRight:))
			[self highlightBracesWithShift: 0 andWarn:NO];
	}
	return retval;
}

- (NSArray *)textView:(NSTextView *)aTextView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index 
{

	NSRange sr = [aTextView selectedRange];
	BOOL texMode = (sr.location && [[textView string] characterAtIndex:sr.location-1] == '\\') ? YES : NO;

	unsigned caretPosition = NSMaxRange(sr);

	SLog(@"completion attempt; cursor at %d, complRange: %d-%d", sr.location, charRange.location, charRange.location+charRange.length);

	*index=0;

	// avoid selecting of token if nothing was found
	// [textView setSelectedRange:NSMakeRange(NSMaxRange(sr), 0)];

	NSMutableSet *uniqueArray = [NSMutableSet setWithCapacity:100];

	NSString *currentWord = [[aTextView string] substringWithRange:charRange];

	if([self isRdDocument]) {
		if(texMode) {
			if(sr.length) {
				NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", currentWord];
				NSArray *result = [texItems filteredArrayUsingPredicate:predicate];
				if(result && [result count])
					[uniqueArray addObjectsFromArray:result];
			} else {
				[uniqueArray addObjectsFromArray:texItems];
			}
		} else {
			// For better current function detection we pass maximal 1000 left from caret
			[uniqueArray addObjectsFromArray:[CodeCompletion retrieveSuggestionsForScopeRange:(sr.location > 1000) ? NSMakeRange(caretPosition-1000, 1000) : NSMakeRange(0, caretPosition)
														 inTextView:aTextView]];
			[uniqueArray addObjectsFromArray:words];
		}
	} else {
		// For better current function detection we pass maximal 1000 left from caret
		[uniqueArray addObjectsFromArray:[CodeCompletion retrieveSuggestionsForScopeRange:(sr.location > 1000) ? NSMakeRange(caretPosition-1000, 1000) : NSMakeRange(0, caretPosition)
													 inTextView:aTextView]];
	}

	// Only parse for words if text size is less than 3MB
	if([currentWord length]>1 && [[aTextView string] length] && [[aTextView string] length]<3000000) {
		NSMutableString *parserString = [NSMutableString string];
		[parserString setString:[aTextView string]];
		// ignore any words in quotes or comments
		[parserString replaceOccurrencesOfRegex:@"(?<!\\\\)\\\\['\"]" withString:@""];
		[parserString replaceOccurrencesOfRegex:@"([\"']).*?\\1" withString:@""];
		if(![self isRdDocument])
			[parserString replaceOccurrencesOfRegex:@"#.*" withString:@""];
		NSString *re;
		if(texMode && [self isRdDocument])
			re = [NSString stringWithFormat:@"(?<=\\\\)%@[\\w\\d]+", currentWord];
		else
		 	re = [NSString stringWithFormat:@"(?<!\\.)\\b%@[\\w\\d\\.:_]+", currentWord];

		if([re isRegexValid]) {
			NSArray *words = [parserString componentsMatchedByRegex:re];
			if(words && [words count]) {
				[uniqueArray addObjectsFromArray:words];
			}
		}
	}

	[uniqueArray removeObject:currentWord];

	NSInteger reverseSort = NO;

	return [[uniqueArray allObjects] sortedArrayUsingFunction:_alphabeticSort context:&reverseSort];
}

- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	RTextView *tv = [aNotification object];

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	// TODO set it to YES for fast editing of very large docs
	// but there're issues for syntax hiliting and scrollview stability
	[[tv layoutManager] setAllowsNonContiguousLayout:NO];
#endif

	if([[NSUserDefaults standardUserDefaults] boolForKey:highlightCurrentLine])
		[tv setNeedsDisplayInRect:[tv bounds] avoidAdditionalLayout:YES];

	if(argsHints && ![[self document] hasREditFlag] && ![self plain]) {

		// show functions hints due to current caret position or selection
		SLog(@"RDocumentWinCtrl: textViewDidChangeSelection and calls currentFunctionHint");

		// Cancel pending currentFunctionHint calls
		[NSObject cancelPreviousPerformRequestsWithTarget:tv 
								selector:@selector(currentFunctionHint) 
								object:nil];

		[tv performSelector:@selector(currentFunctionHint) withObject:nil afterDelay:0.1];

	}
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	SLog(@"RDocumentWinCtrl: sheetDidEnd: returnCode: %d contextInfo: %@", returnCode, contextInfo);

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	// callback for "Go To Line Number"
	if([contextInfo isEqualToString:@"goToLine"]) {
		if(returnCode == 1) {
			NSRange currentLineRange = NSMakeRange(0, 0);
			NSString *s = [[textView textStorage] string];
			int lineCounter = 0;
			int l = [goToLineField intValue];

			while(lineCounter++ < l)
				currentLineRange = [s lineRangeForRange:NSMakeRange(NSMaxRange(currentLineRange), 0)];

			SLog(@" - go to line %d", l);
			// select found line
			[textView setSelectedRange:currentLineRange];
			// scroll to found line
			[textView centerSelectionInVisibleArea:nil];
			// remove selection after 300ms
			[textView performSelector:@selector(moveLeft:) withObject:nil afterDelay:0.3];

		}
	}

	// Make window at which the sheet was attached key window
	[[self window] makeKeyAndOrderFront:nil];

}

- (BOOL)windowShouldClose:(id)sender
{

	SLog(@"RDocumentWinCtrl%@.windowShouldClose: (doc=%@, win=%@, self.rc=%d)", self, [self document], [self window], [self retainCount]);

	// Cancel pending calls
	[NSObject cancelPreviousPerformRequestsWithTarget:textView 
							selector:@selector(currentFunctionHint) 
							object:nil];

	[NSObject cancelPreviousPerformRequestsWithTarget:textView 
							selector:@selector(doSyntaxHighlighting) 
							object:nil];

	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(functionRescan) 
							object:nil];

	return YES;

}

- (void) close
{
	SLog(@"RDocumentWinCtrl<%@>.close", self);	
	[super close];
}

- (void) setEditable: (BOOL) editable
{
	[textView setEditable:editable];
}

- (IBAction)comment: (id)sender
{

	NSString *commentString = @"#";
	if([self isRdDocument])
		commentString = @"%";

	NSRange sr = [textView selectedRange];

	if (sr.length == 0) { // comment out the current line only by inserting a "# " after the indention

		SLog(@"RDocumentWinCtrl: comment current line");
		NSRange lineRange = [[textView string] lineRangeForRange:sr];
		// for empty line simply insert "# "
		if(!lineRange.length) {
			SLog(@" - empty line thus insert # only");
			[textView insertText:[NSString stringWithFormat:@"%@ ", commentString]];
			return;
		}
		[textView setSelectedRange:lineRange];

		// set undo break point
		[textView breakUndoCoalescing];
		// insert commented string
		[textView insertText:
			[[[textView string] substringWithRange:lineRange] stringByReplacingOccurrencesOfRegex:@"^(\\s*)(.*)" 
					withString:[NSString stringWithFormat:@"%@%@ %@", @"$1", commentString, @"$2"]]
			];
		// restore cursor position
		sr.location+=2;
		[textView setSelectedRange:sr];
		return;
	}

	SLog(@"RDocumentWinCtrl: comment selected block");

	// comment out the selected block by inserting a "# " after the indention for each line;
	// empty lines won't be commented out
	NSMutableString *selectedString = [NSMutableString stringWithCapacity:sr.length];
	[selectedString setString:[[textView string] substringWithRange:sr] ];
	// handle first line separately since it doesn't start with a \n or \r
	NSRange firstLineRange = [selectedString lineRangeForRange:NSMakeRange(0,0)];
	NSString *firstLineString = [[selectedString substringWithRange:firstLineRange] stringByReplacingOccurrencesOfRegex:@"^(\\s*)(.*)" 
		withString:[NSString stringWithFormat:@"%@%@ %@", @"$1", commentString, @"$2"]];
	[selectedString replaceCharactersInRange:firstLineRange withString:firstLineString];
	NSString *commentedString = [selectedString stringByReplacingOccurrencesOfRegex:@"(?m)([\r\n]+)(\\s*)(?=\\S)" 
			withString:[NSString stringWithFormat:@"%@%@%@ ", @"$1", @"$2", commentString]];
	[textView setSelectedRange:sr];

	// set undo break point
	[textView breakUndoCoalescing];
	// insert commented string
	[textView insertText:commentedString];
	// restore selection
	[textView setSelectedRange:NSMakeRange(sr.location, [commentedString length])];

}

- (IBAction)uncomment: (id)sender
{

	NSString *commentString = @"#";
	if([self isRdDocument])
		commentString = @"%";

	NSRange sr = [textView selectedRange];

	if (sr.length == 0) { // uncomment the current line only

		SLog(@"RDocumentWinCtrl: uncomment current line");
		NSRange lineRange = [[textView string] lineRangeForRange:sr];
		// for empty line does nothing
		if(!lineRange.length) {
			SLog(@" - no line found");
			return;
		}
		
		[textView setSelectedRange:lineRange];
		// set undo break point
		[textView breakUndoCoalescing];
		NSString *uncommentedString = [[[textView string] substringWithRange:lineRange] stringByReplacingOccurrencesOfRegex:
			[NSString stringWithFormat:@"^(\\s*)(%@ ?)", commentString] withString:@"$1"];
		[textView insertText:uncommentedString];
		// restore cursor position
		[textView setSelectedRange:NSMakeRange(sr.location - lineRange.length + [uncommentedString length], 0)];
		return;
	}

	SLog(@"RDocumentWinCtrl: uncomment selected block");

	// uncomment selected block
	NSString *uncommentedString = [[[textView string] substringWithRange:sr] stringByReplacingOccurrencesOfRegex:
		[NSString stringWithFormat:@"(?m)^(\\s*)(%@ ?)", commentString] withString:@"$1"];
	// set undo break point
	[textView breakUndoCoalescing];
	[textView insertText:uncommentedString];
	// restore selection
	[textView setSelectedRange:NSMakeRange(sr.location, [uncommentedString length])];

}

- (IBAction)executeSelection:(id)sender
{
	NSRange sr = [textView selectedRange];
	if (sr.length>0) {
		NSString *stx = [[[textView textStorage] string] substringWithRange:sr];
		[[RController sharedController] sendInput:stx];
	} else { // if nothing is selected, execute the current line
		NSRange lineRange = [[[textView textStorage] string] lineRangeForRange:sr];
		if (lineRange.length < 1)
			NSBeep(); // nothing to execute
		else
			[[RController sharedController] sendInput:
			 [[[textView textStorage] string] substringWithRange: lineRange]];
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
				[[RController sharedController] sendInput:[NSString stringWithFormat:@"source(\"%@\")\nunlink(\"%@\")", fn, fn]];
			}
		}
	} else {
		NSString *fn=[[self document] fileName];
		if (fn) {
			[[RController sharedController] sendInput:[NSString stringWithFormat:@"source(\"%@\")", fn]];
		}
	}
}


- (IBAction)setHelpSearchType:(id)sender
{
	NSMenuItem *mi = (NSMenuItem*) sender;
	NSMenu *m = [(NSSearchFieldCell*) searchToolbarField searchMenuTemplate];
	int hst = [mi tag];
	if (mi && m && hst!=hsType) {
		SLog(@"setHelpSearchType: old=%d, new=%d", hsType, hst);
		NSMenuItem *cmi = [m itemWithTag:hsType];
		if (cmi) [cmi setState:NSOffState];
		hsType = hst;
		cmi = (NSMenuItem*) [m itemWithTag:hsType];
		if (cmi) [cmi setState:NSOnState];
		// sounds weird, but we have to re-set the tempate to force sf to update the real menu
		[(NSSearchFieldCell*) searchToolbarField setSearchMenuTemplate:m];
		[[HelpManager sharedController] setSearchType:hsType];
	}
}

- (IBAction)goHelpSearch:(id)sender
{

	NSString *ss = [[(NSSearchField*)sender stringValue] stringByTrimmingCharactersInSet:
										[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	SLog(@"%@.goHelpSearch: \"%@\", type=%d", self, ss, hsType);

	if(![ss length]) return;

	SLog(@" - call [HelpManager showHelpFor:]");

	[[HelpManager sharedController] showHelpFor:ss];

// 	if ([ss length]<1)
// 		[helpDrawer close];
// 	else {
// 		[helpDrawer open];
// 		switch (hsType) {
// 			case hsTypeExact: {
// 				RSEXP *x = [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try(help(\"%@\"),silent=TRUE)", ss]];
// 				if (x) {
// 					NSString *path = [[[x string] copy] autorelease];
// 					[x release];
// 					if (path) {
// #if R_VERSION < R_Version(2, 10, 0)
// 						NSString *url = [NSString stringWithFormat:@"file://%@", path];
// #else
// 						int port = [[RController sharedController] helpServerPort];
// 						if (port == 0) {
// 							NSRunInformationalAlertPanel(NLS(@"Cannot start HTML help server."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
// 							return;
// 						}
// 						// is will be ..../package/html/topic.html - so extract the package name from there - the internal help relies on the same logic
// 						NSArray *pc = [path pathComponents];
// 						if ([pc count] < 3) {
// 							NSRunInformationalAlertPanel(NLS(@"Cannot determine package for the topic."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
// 							return;
// 						}
// 						NSString *pkg = (NSString*) [pc objectAtIndex:[pc count] - 3];
// 						NSString *url = [NSString stringWithFormat:@"http://127.0.0.1:%d/library/%@/html/%@.html", port, pkg, ss];
// #endif
// 						[[helpWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
// 					}
// 				}
// 				break;
// 			}
// 			case hsTypeApprox: {
// 				if (!helpTempFile)
// 					helpTempFile = [NSString stringWithFormat:@"/tmp/RguiHS%p.html", self];
// 				SLog(@" - approx search will use %@", helpTempFile);
// #if R_VERSION < R_Version(2, 10, 0)
// 				RSEXP * x= [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try({function(a){sink('%@'); cat(paste('<html><table>',paste('<tr><td><b>',a[,1],'</b> (<a href=\"file://',a[,4],'/html/00Index.html\">',a[,3],'</a></td><td>',a[,2],'</td></tr>',sep='',collapse=''),'</table></html>',sep=''));sink();'OK'}}(help.search(\"%@\")$matches),silent=TRUE)", helpTempFile, ss]];
// #else
// 				int port = [[RController sharedController] helpServerPort];
// 				if (port == 0) {
// 					NSRunInformationalAlertPanel(NLS(@"Cannot start HTML help server."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
// 					return;
// 				}
// 				RSEXP * x= [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try({function(a){sink('%@'); cat(paste('<html><table>',paste('<tr><td><b>',a[,1],'</b> (<a href=\"http://127.0.0.1:',tools:::httpdPort,'/library/',a[,3],'/html/',a[,1],'.html\">',a[,3],'</a>)</td><td>',a[,2],'</td></tr>',sep='',collapse=''),'</table></html>',sep=''));sink();'OK'}}(help.search(\"%@\")$matches),silent=TRUE)", helpTempFile, ss]];			
// #endif
// 				SLog(@" - resulting SEXP=%@", x);
// 				if (x && [x string] && [[x string] isEqual:@"OK"]) {
// 					NSString *url = [NSString stringWithFormat:@"file://%@",helpTempFile];
// 					NSLog(@":%@", url);
// 					[[helpWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
// 				}
// 				[x release];
// 				break;
// 			}
// 		}
// 	}
}

- (NSView*) searchToolbarView
{
	return searchToolbarView;
}

- (NSView*) fnListView
{
	return fnListView;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	if ([menuItem action] == @selector(reInterpretDocument:)) {
		return ([[RDocumentController sharedDocumentController] currentDocument] && [[[RDocumentController sharedDocumentController] currentDocument] fileURL]);
	}

	if ([menuItem action] == @selector(comment:) || [menuItem action] == @selector(uncomment:)) {
		id firstResponder = [[NSApp keyWindow] firstResponder];
		return ([firstResponder respondsToSelector:@selector(isEditable)] && [firstResponder isEditable]);
	}

	if ([menuItem action] == @selector(sourceCurrentDocument:)) {
		id firstResponder = [[NSApp keyWindow] firstResponder];
		if([[firstResponder delegate] respondsToSelector:@selector(isRdDocument)])
			return ![[firstResponder delegate] isRdDocument];
		return YES;
	}


	return YES;
}

- (void) helpSearchTypeChanged
{
	int type = [[HelpManager sharedController] searchType];
	NSMenu *m = [[searchToolbarField cell] searchMenuTemplate];
	SLog(@"RDocumentWinCtrl - received notification about search type change to %d", type);
	[[m itemWithTag:kExactMatch] setState:(type == kExactMatch) ? NSOnState : NSOffState];
	[[m itemWithTag:kFuzzyMatch] setState:(type == kExactMatch) ? NSOffState : NSOnState];
	[[searchToolbarField cell] setSearchMenuTemplate:m];
}

@end
