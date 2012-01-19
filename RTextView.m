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
 *  Created by Simon Urbanek on 5/11/05.
 *  $Id$
 */

#import "RTextView.h"
#import "HelpManager.h"
#import "RGUI.h"
#import "RegexKitLite.h"
#import "RController.h"
#import "NSTextView_RAdditions.h"
#import "RDocumentWinCtrl.h"

// linked character attributes
#define kTALinked    @"link"
#define kTAVal       @"x"


// declared external
BOOL RTextView_autoCloseBrackets = YES;

#pragma mark -
#pragma mark Private API

@interface RTextView (Private)

- (void)selectMatchingPairAt:(int)position;
- (NSString*)functionNameForCurrentScope;

@end

#pragma mark -

@implementation RTextView

- (id) initWithCoder: (NSCoder*) coder
{
	self = [super initWithCoder:coder];
	if (self) {
		separatingTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"()'\"+-=/* ,\t]{}^|&!;<>?`\n\\"] retain];
		undoBreakTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"+- .,|&*/:!?<>=\n"] retain];
	}
	return self;
}


- (void)awakeFromNib
{
	SLog(@"RTextView: awakeFromNib %@", self);
	// commentTokensSet    = [[NSCharacterSet characterSetWithCharactersInString: @"#"] retain];
	console = NO;
	RTextView_autoCloseBrackets = YES;
    SLog(@" - delegate: %@", [self delegate]);

	isRdDocument = NO;
	if([[self window] windowController] && [[[self window] windowController] respondsToSelector:@selector(isRdDocument)])
		isRdDocument = ([[[self window] windowController] isRdDocument]);

	// work-arounds for brain-dead "features" in Lion
	if ([self respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)])
		[self setAutomaticQuoteSubstitutionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
		[self setAutomaticTextReplacementEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticSpellingCorrectionEnabled:)])
		[self setAutomaticSpellingCorrectionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticLinkDetectionEnabled:)])
		[self setAutomaticLinkDetectionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticDataDetectionEnabled:)])
		[self setAutomaticDataDetectionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticDashSubstitutionEnabled:)])
		[self setAutomaticDashSubstitutionEnabled:NO];

}

- (void)dealloc
{
	if(separatingTokensSet) [separatingTokensSet release];
	if(undoBreakTokensSet) [undoBreakTokensSet release];
	// if(commentTokensSet) [commentTokensSet release];
	[super dealloc];
}

- (void)keyDown:(NSEvent *)theEvent
{

	if(![self isEditable]) {
		[super keyDown:theEvent];
		return;
	}

	NSString *rc = [theEvent charactersIgnoringModifiers];
	NSString *cc = [theEvent characters];
	unsigned int modFlags = [theEvent modifierFlags];
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);

	BOOL hilite = NO;

	SLog(@"RTextView: keyDown: %@ *** \"%@\" %d", theEvent, rc, modFlags);

	if([rc length] && [undoBreakTokensSet characterIsMember:[rc characterAtIndex:0]]) [self breakUndoCoalescing];

	if ([rc isEqual:@"."] && (modFlags&allFlags)==NSControlKeyMask) {
		SLog(@" - send complete: to self");
		[self complete:self];
		return;
	}
	if ([rc isEqual:@"="]) {
		int mf = modFlags&allFlags;
		if ( mf ==NSControlKeyMask) {
			[self breakUndoCoalescing];
			[self insertText:@"<-"];
			return;
		}
		if ( mf == NSAlternateKeyMask ) {
			[self breakUndoCoalescing];
			[self insertText:@"!="];
			return;
		}
	}
	if ([rc isEqual:@"-"] && (modFlags&allFlags)==NSAlternateKeyMask) {
		[self breakUndoCoalescing];
		[self insertText:[NSString stringWithFormat:@"%@<- ", 
			([self selectedRange].location && [[self string] characterAtIndex:[self selectedRange].location-1] != ' ')?@" ":@""]];
		return;
	}
	if ([rc isEqual:@"h"] && (modFlags&allFlags)==NSControlKeyMask) {
		SLog(@" - send showHelpForCurrentFunction to self");
		[self showHelpForCurrentFunction];
		return;
	}
	// Detect if matching bracket should be highlighted
	if(cc && [cc length]==1 && [[[NSUserDefaults standardUserDefaults] objectForKey:showBraceHighlightingKey] isEqualToString:@"YES"]) {
		switch([cc characterAtIndex:0]) {
			case '(':
			case '[':
			case '{':
			case ')':
			case ']':
			case '}':
			hilite = YES;
		}
	}
	if (cc && [cc length]==1 && [[[NSUserDefaults standardUserDefaults] objectForKey:kAutoCloseBrackets] isEqualToString:@"YES"]) {
		unichar ck = [cc characterAtIndex:0];
		NSString *complement = nil;
		NSRange r = [self selectedRange];
		BOOL acCheck = NO;
		switch (ck) {
			case '{':
				complement = @"}";
			case '(':
				if (!complement) complement = @")";
			case '[':
				if (!complement) complement = @"]";
			case '"':
				if (!complement) {
					complement = @"\"";
					acCheck = YES;
					if ([self parserContextForPosition:r.location] != pcExpression) break;
				}
			case '`':
				if (!complement) {
					complement = @"`";
					acCheck = YES;
					if ([self parserContextForPosition:r.location] != pcExpression) break;
				}
			case '\'':
				if (!complement) {
					complement = @"\'";
					acCheck = YES;
					if ([self parserContextForPosition:r.location] != pcExpression) break;
				}

				// Check if something is selected and wrap it into matching pair characters and preserve the selection
				// - in RConsole only if selection is in the last line
				if(((console && [[self string] lineRangeForRange:NSMakeRange([[self string] length]-1,0)].location+1 < r.location) || !console) 
					&& [self wrapSelectionWithPrefix:[NSString stringWithFormat:@"%c", ck] suffix:complement]) {
					SLog(@"RTextView: selection was wrapped with auto-pairs");
					return;
				}

				// Try to suppress unnecessary auto-pairing
				if( !isRdDocument && [self isCursorAdjacentToAlphanumCharWithInsertionOf:ck] && ![self isNextCharMarkedBy:kTALinked withValue:kTAVal] && ![self selectedRange].length ){ 
					SLog(@"RTextView: suppressed auto-pairing");
					[super keyDown:theEvent];
					if(hilite && [[self delegate] respondsToSelector:@selector(highlightBracesWithShift:andWarn:)])
						[[self delegate] highlightBracesWithShift:-1 andWarn:YES];
					return;
				}

				SLog(@"RTextView: open bracket chracter %c", ck);
				[super keyDown:theEvent];
				{
					r = [self selectedRange];
					if (r.location != NSNotFound) {
						// NSAttributedString *as = [[NSAttributedString alloc] initWithString:complement attributes:
						// [NSDictionary dictionaryWithObject:TAVal forKey:kTALinked]];
						NSTextStorage *ts = [self textStorage];
						// Register the auto-pairing for undo and insert the complement
						[self shouldChangeTextInRange:r replacementString:complement];
						[self replaceCharactersInRange:r withString:complement];
						r.length=1;
						[ts addAttribute:kTALinked value:kTAVal range:r];
						r.length=0;
						[self setSelectedRange:r];
					}
					return;
				}
			case '}':
			case ')':
			case ']':
				acCheck = YES;
		}

		if (acCheck) {
			NSRange r = [self selectedRange];
			if (r.location != NSNotFound && r.length == 0) {
				NSTextStorage *ts = [self textStorage];
				id attr = nil;
				@try {
					attr = [ts attribute:kTALinked atIndex:r.location effectiveRange:0];
				}
				@catch (id ue) {}
				if (attr) {
					unsigned int cuc = [[ts string] characterAtIndex:r.location];
					SLog(@"RTextView: encountered linked character '%c', while writing '%c'", cuc, ck);
					if (cuc == ck) {
						r.length = 1;
						SLog(@"RTextView: selecting linked character for removal on type");
						[self setSelectedRange:r];
					}
				}
			}
			SLog(@"RTextView: closing bracket chracter %c", ck);
		}
	}
	// if ((modFlags&(NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))==NSControlKeyMask) {
	// 	if ([rc isEqual:@"{"]) {
	//
	// 	} else if ([rc isEqual:@"}"]) {
	//
	// 	}
	// }
	[super keyDown:theEvent];

	if(hilite && [[self delegate] respondsToSelector:@selector(highlightBracesWithShift:andWarn:)])
		[[self delegate] highlightBracesWithShift:-1 andWarn:YES];
}

- (void)deleteBackward:(id)sender
{

	NSRange r = [self selectedRange];
	if (r.length == 0 && r.location > 0)
		[self selectMatchingPairAt:r.location];

	[super deleteBackward:sender];

}

- (void)deleteForward:(id)sender
{

	NSRange r = [self selectedRange];
	if (r.length == 0)
		[self selectMatchingPairAt:r.location + 1];

	[super deleteForward:sender];

}

/**
 * If the textview has a selection, wrap it with the supplied prefix and suffix strings;
 * return whether or not any wrap was performed.
 */
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix
{

	NSRange currentRange = [self selectedRange];

	// Only proceed if a selection is active
	if (currentRange.length == 0 || ![self isEditable])
		return NO;

	NSString *selString = [[self string] substringWithRange:currentRange];

	// Replace the current selection with the selected string wrapped in prefix and suffix
	[self insertText:[NSString stringWithFormat:@"%@%@%@", prefix, selString, suffix]];
	
	// Re-select original selection
	NSRange innerSelectionRange = NSMakeRange(currentRange.location+1, [selString length]);
	[self setSelectedRange:innerSelectionRange];

	// Mark last autopair character as autopair-linked
	[[self textStorage] addAttribute:kTALinked value:kTAVal range:NSMakeRange(NSMaxRange(innerSelectionRange), 1)];

	return YES;
}

/**
 * Returns the parser context for the passed cursor position
 *
 * @param position The cursor position to test
 */
- (int)parserContextForPosition:(int)position
{

	int context = pcExpression;

	if (position < 1)
		return context;

	NSString *string = [self string];
	if (position > [string length])
		position = [string length];

	NSRange thisLine = [string lineRangeForRange:NSMakeRange(position, 0)];

	// we do NOT support multi-line strings, so the line always starts as an expression
	if (thisLine.location == position)
		return context;

	SLog(@"RTextView: parserContextForPosition: %d, line span=%d:%d", position, thisLine.location, thisLine.length);

	int i = thisLine.location;
	BOOL skip = NO;
	unichar c;
	while (i < position && i >= 0) {
		c = CFStringGetCharacterAtIndex((CFStringRef)string, i);
		if (skip) {
			skip = NO;
		} else {
			if (c == '\\' && (context == pcStringDQ || context == pcStringSQ || context == pcStringBQ)) {
				skip = YES;
			} else if (c == '"') {
				if (context == pcStringDQ)
					context = pcExpression;
				else if (context == pcExpression)
					context = pcStringDQ;
			} else if (c == '\'') {
				if (context == pcStringSQ)
					context = pcExpression;
				else if (context == pcExpression)
					context = pcStringSQ;
			} else if (c == '`') {
				if (context == pcStringBQ)
					context = pcExpression;
				else if (context == pcExpression)
					context = pcStringBQ;
			}
			else if(context == pcExpression) {
				if(isRdDocument && c == '%')
					return pcComment;
				else if(c == '#')
					return pcComment;
			}

		}
		i++;
	}

	return context;

}

/**
 * Returns the range for user completion
 */
- (NSRange)rangeForUserCompletion
{

	NSRange userRange = NSMakeRange(NSNotFound, 0);
	NSRange selection = [self selectedRange];
	NSString *string  = [self string];
	int cursor = NSMaxRange(selection); // we complete at the end of the selection
	int context = [self parserContextForPosition:cursor];

	SLog(@"RTextView: rangeForUserCompletion: parser context: %d", context);

	if (context == pcComment) return NSMakeRange(NSNotFound,0); // no completion in comments

	if (context == pcStringDQ || context == pcStringSQ) // we're in a string, hence file completion
														// the beginning of the range doesn't matter, because we're guaranteed to find a string separator on the same line
		userRange = [string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:(context == pcStringDQ) ? @"\" /" : @"' /"]
											options:NSBackwardsSearch|NSLiteralSearch
											  range:NSMakeRange(0, selection.location)];

	if (context == pcExpression || context == pcStringBQ) // we're in an expression or back-quote, so use R separating tokens (we could be smarter about the BQ but well..)
		userRange = [string rangeOfCharacterFromSet:separatingTokensSet
											options:NSBackwardsSearch|NSLiteralSearch
											  range:NSMakeRange(0, selection.location)];

	if( userRange.location == NSNotFound )
		// everything is one expression - we're guaranteed to be in the first line (because \n would match)
		return NSMakeRange(0, cursor);

	if( userRange.length < 1 ) // nothing to complete
		return NSMakeRange(NSNotFound, 0);

	if( userRange.location == selection.location - 1 ) { // just before cursor means empty completion
		userRange.location++;
		userRange.length = 0;
	} else { // normal completion
		userRange.location++; // skip past first bad one
		userRange.length = selection.location - userRange.location;
		SLog(@" - returned range: %d:%d", userRange.location, userRange.length);

		// FIXME: do we really need to change it? Cocoa should be doing it .. (and does in Lion)
		if (os_version < 11.0)
			[self setSelectedRange:userRange];
	}

	return userRange;

}

/**
 * Checks if the char after the current caret position/selection matches a supplied attribute
 */
- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue
{
	NSUInteger caretPosition = [self selectedRange].location;

	// Perform bounds checking
	if (caretPosition >= [[self string] length]) return NO;
	
	// Perform the check
	if ([[[self textStorage] attribute:attribute atIndex:caretPosition effectiveRange:nil] isEqualToString:aValue])
		return YES;

	return NO;
}

/**
 * Checks if the caret adjoins to an alphanumeric char  |word or word| or wo|rd
 * Exception for word| and char is a “(” or “[” to allow e.g. auto-pairing () for functions
 */
- (BOOL) isCursorAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar
{
	NSUInteger caretPosition = [self selectedRange].location;
	NSCharacterSet *alphanum = [NSCharacterSet alphanumericCharacterSet];
	BOOL leftIsAlphanum = NO;
	BOOL rightIsAlphanum = NO;
	BOOL charIsOpenBracket = (aChar == '(' || aChar == '[');
	NSUInteger bufferLength = [[self string] length];

	if(!bufferLength) return NO;
	
	// Check previous/next character for being alphanum
	// @try block for bounds checking
	@try
	{
		if(caretPosition==0)
			leftIsAlphanum = NO;
		else
			leftIsAlphanum = [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition-1]] && !charIsOpenBracket;
	} @catch(id ae) { }
	@try {
		if(caretPosition >= bufferLength)
			rightIsAlphanum = NO;
		else
			rightIsAlphanum= [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition]];
		
	} @catch(id ae) { }

	return (leftIsAlphanum ^ rightIsAlphanum || (leftIsAlphanum && rightIsAlphanum));
}

/**
 * Returns the range of the current word relative the current cursor position
 *   finds: [| := caret]  |word  wo|rd  word|
 *   if | is in between whitespaces range length is zero.
 */

/**
 * Sets the console mode
 *
 * @param isConsole If self is in console mode (YES) or not (NO)
 */
- (void)setConsoleMode:(BOOL)isConsole
{
	console = isConsole;
	SLog(@"RTextView: set console flag to %@ (%@)", isConsole?@"yes":@"no", self);
}

/**
 * Shows the Help page for the current function relative to the current cursor position or
 * if something is selected for the selection in the HelpManager
 *
 * Notes:
 *  - if the cursor is in between or adjacent to an alphanumeric word take this one if it not a pure numeric value
 *  - if nothing found try to parse backwards from cursor position to find the active function name according to opened and closed parentheses
 *      examples | := cursor
 *        a(b(1,2|,3)) -> b
 *        a(b(1,2,3)|) -> a
 * - if nothing found set the input focus to the Help search field either in RConsole or in R script editor
 */
- (void) showHelpForCurrentFunction
{

	NSString *helpString = [self functionNameForCurrentScope];

	if(helpString && [helpString length]) {
		int oldSearchType = [[HelpManager sharedController] searchType];
		[[HelpManager sharedController] setSearchType:kExactMatch];
		[[HelpManager sharedController] showHelpFor:helpString];
		[[HelpManager sharedController] setSearchType:oldSearchType];
		return;
	}

	id aSearchField = nil;

	NSWindow *keyWin = [NSApp keyWindow];

	if(![[keyWin toolbar] isVisible])
		[keyWin toggleToolbarShown:nil];

	if([[self delegate] respondsToSelector:@selector(searchToolbarView)])
		aSearchField = [[self delegate] searchToolbarView];

	if(aSearchField == nil || ![aSearchField isKindOfClass:[NSSearchField class]]) return;

	[aSearchField setStringValue:[[self string] substringWithRange:[self getRangeForCurrentWord]]];

	if([[aSearchField stringValue] length])
		[[HelpManager sharedController] showHelpFor:[aSearchField stringValue]];
	else
		[[NSApp keyWindow] makeFirstResponder:aSearchField];

}


- (void)currentFunctionHint
{

	NSString *helpString = [self functionNameForCurrentScope];

	if(helpString && ![helpString isMatchedByRegex:@"(?s)[\\s\\[\\]\\(\\)\\{\\};\\?!]"] && [[self delegate] respondsToSelector:@selector(hintForFunction:)]) {
		SLog(@"RTextView: currentFunctionHint for '%@'", helpString);
		[(RController*)[self delegate] hintForFunction:helpString];
	}

}

/**
 * Shifts the selection, if any, rightwards by indenting any selected lines with one tab.
 * If the caret is within a line, the selection is not changed after the index; if the selection
 * has length, all lines crossed by the length are indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionRight
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSRange selectedRange = [self selectedRange];

	if (selectedRange.location == NSNotFound || ![self isEditable]) return NO;

	NSString *indentString = @"\t";
	// if ([prefs soft]) {
	// 	NSUInteger numberOfSpaces = [prefs soft width];
	// 	if(numberOfSpaces < 1) numberOfSpaces = 1;
	// 	if(numberOfSpaces > 32) numberOfSpaces = 32;
	// 	NSMutableString *spaces = [NSMutableString string];
	// 	for(NSUInteger i = 0; i < numberOfSpaces; i++)
	// 		[spaces appendString:@" "];
	// 	indentString = [NSString stringWithString:spaces];
	// }

	// Indent the currently selected line if the caret is within a single line
	if (selectedRange.length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:selectedRange];

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 0) replacementString:indentString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString:indentString];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange(selectedRange.location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange(selectedRange)-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but not the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Replace \n by \n\t of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [indentString stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\r" withString:[NSString stringWithFormat:@"\r%@", indentString]]];
	else
		newString = [indentString stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\n" withString:[NSString stringWithFormat:@"\n%@", indentString]]];

	// Register the indent for undo
	[self shouldChangeTextInRange:blockRange replacementString:newString];

	[self replaceCharactersInRange:blockRange withString:newString];

	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;

}


/**
 * Shifts the selection, if any, leftwards by un-indenting any selected lines by one tab if possible.
 * If the caret is within a line, the selection is not changed after the undent; if the selection has
 * length, all lines crossed by the length are un-indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionLeft
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;

	if ([self selectedRange].location == NSNotFound || ![self isEditable]) return NO;

	// Undent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| ([textViewString characterAtIndex:currentLineRange.location] != '\t' && [textViewString characterAtIndex:currentLineRange.location] != ' '))
			return NO;

		NSRange replaceRange;

		// Check for soft indention
		NSUInteger indentStringLength = 1;
		// if ([prefs soft]) {
		// 	NSUInteger numberOfSpaces = [prefs soft width];
		// 	if(numberOfSpaces < 1) numberOfSpaces = 1;
		// 	if(numberOfSpaces > 32) numberOfSpaces = 32;
		// 	indentStringLength = numberOfSpaces;
		// 	replaceRange = NSIntersectionRange(NSMakeRange(currentLineRange.location, indentStringLength), NSMakeRange(0,[[self string] length]));
		// 	// Correct length for only white spaces
		// 	NSString *possibleIndentString = [[[self textStorage] string] substringWithRange:replaceRange];
		// 	NSUInteger numberOfLeadingWhiteSpaces = [possibleIndentString rangeOfRegex:@"^(\\s*)" capture:1L].length;
		// 	if(numberOfLeadingWhiteSpaces == NSNotFound) numberOfLeadingWhiteSpaces = 0;
		// 	replaceRange = NSMakeRange(currentLineRange.location, numberOfLeadingWhiteSpaces);
		// } else {
			replaceRange = NSMakeRange(currentLineRange.location, indentStringLength);
		// }

		// Register the undent for undo
		[self shouldChangeTextInRange:replaceRange replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:replaceRange withString:@""];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange([self selectedRange])-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Check for soft or hard indention
	NSString *indentString = @"\t";
	NSUInteger indentStringLength = 1;
	// if ([prefs soft]) {
	// 	indentStringLength = [prefs soft width];
	// 	if(indentStringLength < 1) indentStringLength = 1;
	// 	if(indentStringLength > 32) indentStringLength = 32;
	// 	NSMutableString *spaces = [NSMutableString string];
	// 	for(NSUInteger i = 0; i < indentStringLength; i++)
	// 		[spaces appendString:@" "];
	// 	indentString = [NSString stringWithString:spaces];
	// }

	// Check if blockRange starts with SPACE or TAB
	// (this also catches the first line of the entire text buffer or
	// if only one line is selected)
	NSInteger leading = 0;
	if([textViewString characterAtIndex:blockRange.location] == ' ' 
		|| [textViewString characterAtIndex:blockRange.location] == '\t')
		leading += indentStringLength;

	// Replace \n[ \t] by \n of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
			stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\r%@", indentString] withString:@"\r"];
	else
		newString = [[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
		stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\n%@", indentString] withString:@"\n"];

	// Register the unindent for undo
	[self shouldChangeTextInRange:blockRange replacementString:newString];

	[self replaceCharactersInRange:blockRange withString:newString];

	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;
}

#pragma mark -

/**
 * Selects matching pairs if the character before position and at position are linked
 *
 * @param position The cursor position to test
 */
- (void)selectMatchingPairAt:(int)position
{

	if(position < 1 || position >= [[self string] length])
		return;

	unichar c = [[self string] characterAtIndex:position - 1];
	unichar cc = 0;
	switch (c) {
		case '(': cc=')'; break;
		case '{': cc='}'; break;
		case '[': cc=']'; break;
		case '"':
		case '`':
		case '\'':
			cc=c; break;
	}
	if (cc) {
		unichar cs = [[self string] characterAtIndex:position];
		if (cs == cc) {
			id attr = [[self textStorage] attribute:kTALinked atIndex:position effectiveRange:0];
			if (attr) {
				[self setSelectedRange:NSMakeRange(position - 1, 2)];
				SLog(@"RTextView: selected matching pair");
			}
		}
	}

}

- (NSString*)functionNameForCurrentScope
{

	NSString *helpString;
	NSString *parseString = [self string];
	NSRange  selectedRange = [self selectedRange];
	NSRange parseRange;

	int parentheses = 0;
	int index       = 0;

	SLog(@"RTextView: functionNameForCurrentScope");

	// if user selected something take the selection only; otherwise take the current word
	if (selectedRange.length) {
		helpString = [parseString substringWithRange:selectedRange];
		SLog(@" - return selection");
		return helpString;
	} else {
		helpString = [parseString substringWithRange:[self getRangeForCurrentWord]];
	}

	SLog(@" - current word “%@”", helpString);

	// if a word was found and the word doesn't represent a numeric value
	// and a ( follows then return word
	if([helpString length] && ![[[NSNumber numberWithFloat:[helpString floatValue]] stringValue] isEqualToString:helpString]) {
		int start = NSMaxRange(selectedRange);
		if(start < [parseString length]) {
			BOOL found = NO;
			int i = 0;
			int end = ([parseString length] > 100) ? 100 : [parseString length];
			unichar c;
			for(i = start; i < end; i++) {
                if ((c = CFStringGetCharacterAtIndex((CFStringRef)parseString, i)) == '(') {
					found = YES;
					break;
				}
				if (c != ' ' || c != '\t' || c != '\n' || c != '\r') break;
			}
			if(found) {
				SLog(@" - caret was inside function name; return it");
				return helpString;
			}
		}
	}

	SLog(@" - invalid current word -> start parsing for current function scope");

	// if we're in the RConsole do parse the current line only
	if(console) {
		parseRange = [parseString lineRangeForRange:NSMakeRange(selectedRange.location, 0)];
		// ignore any prompt signs
		parseRange.location += 1;
		parseRange.length -= 1;
	} else {
		parseRange = NSMakeRange(0, [parseString length]);
	}

	// sanety check; if it fails bail
	if(selectedRange.location - parseRange.location <= 0) {
		SLog(@" - parse range invalid - bail");
		return nil;
	}

	// set the to be parsed range
	parseRange.length =  selectedRange.location - parseRange.location;

	// go back according opened/closed parentheses
	BOOL opened, closed;
	BOOL found = NO;
	for(index = NSMaxRange(parseRange) - 1; index > parseRange.location; index--) {
		unichar c = CFStringGetCharacterAtIndex((CFStringRef)parseString, index);
		closed = (c == ')');
		opened = (c == '(');
		// Check if we're not inside of quotes or comments
		if( ( closed || opened)
			&& (index > parseRange.location)
			&& [self parserContextForPosition:(index)] != pcExpression) {
			continue;
		}
		if(closed) parentheses--;
		if(opened) parentheses++;
		if(parentheses > 0) {
			found = YES;
			break;
		}
	}

	if(!found) {
		SLog(@" - parsing unsuccessfull; bail");
		return nil;
	}

	SLog(@" - first not closed ( found at index: %d", index);

	// check if we still are in the parse range; otherwise bail
	if(parseRange.location > index) {
		SLog(@" - found index invalid - bail");
		return nil;
	}

	// check if char in front of ( is not a white space; if so go back
	if(index > 0) {
		while(index > 0 && index >= parseRange.location) {
			unichar c = CFStringGetCharacterAtIndex((CFStringRef)parseString, --index);
			if(c == ' ' || c == '\t' || c == '\n' || c == '\r') {
				;
			} else {
				break;
			}
		}
	}

	SLog(@" - function name found at index: %d", index);

	// check if we still are in the parse range; otherwise bail
	if(parseRange.location > index) {
		SLog(@" - found index invalid - bail");
		return nil;
	}

	// get the adjacent word according
	helpString = [parseString substringWithRange:[self getRangeForCurrentWordOfRange:NSMakeRange(index, 0)]];

	SLog(@" - found function name: “%@”", helpString);
	// if a word was found and the word doesn't represent a numeric value return it
	if([helpString length] && ![[[NSNumber numberWithFloat:[helpString floatValue]] stringValue] isEqualToString:helpString]) {
		SLog(@" - return found function name");
		return helpString;
	}

	SLog(@" - found function name wasn't valid, i.e. empty or represents a numeric value; return nil");
	return nil;

}

- (BOOL) isRConsole
{
	return console;
}

#pragma mark -

- (void)changeFont:(id)sender
{

	NSFont *font= [[NSFontPanel sharedFontPanel] panelConvertFont:
			[NSUnarchiver unarchiveObjectWithData:
				[[NSUserDefaults standardUserDefaults] dataForKey:console ? RConsoleDefaultFont : RScriptEditorDefaultFont]]];

	if(!font) return;

	// If user selected something change the selection's font only
	if(!console && ([[[[self window] windowController] document] isRTF] || [self selectedRange].length)) {
		// register font change for undo
		NSRange r = [self selectedRange];
		[self shouldChangeTextInRange:r replacementString:[[self string] substringWithRange:r]];
		[[self textStorage] addAttribute:NSFontAttributeName value:font range:r];
		[self setAllowsUndo:NO];
		[self setSelectedRange:NSMakeRange(r.location, 0)];
		[self insertText:@""];
		[self setSelectedRange:r];
		[self setAllowsUndo:YES];
		[self setNeedsDisplay:YES];
	// otherwise update view and save new font in Preferences
	} else {
		[[RController sharedController] fontSizeChangedBy:0.0f withSender:nil];
	}

}

@end
