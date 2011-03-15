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

// linked character attributes
#define kTALinked    @"RTVLinkedChar"
#define TAVal        @""

// context menu tags
#define kShowHelpContextMenuItemTag 10001

// parser context in text
#define pcStringSQ   1
#define pcStringDQ   2
#define pcStringBQ   3
#define pcComment    4
#define pcExpression 5

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

/* we don't need custom init, but in case it's necessary just uncomment this
- (id) initWithCoder: (NSCoder*) coder
{
	self = [super initWithCoder:coder];
	if (self) {
	}
	return self;
}
*/

- (void)awakeFromNib
{
	SLog(@"RTextView: awakeFromNib %@", self);
	separatingTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"()'\"+-=/* ,\t[]{}^|&!:;<>?`\n"] retain];
	// commentTokensSet    = [[NSCharacterSet characterSetWithCharactersInString: @"#"] retain];
	console = NO;
	RTextView_autoCloseBrackets = YES;
    SLog(@" - delegate: %@", [self delegate]);
    // FIXME: this is a really ugly hack ... behavior should not depend on class names ...
	isRConsole = ([(NSObject*)[self delegate] isKindOfClass:[RController class]]) ? YES : NO;
}

- (void)dealloc
{
	if(separatingTokensSet) [separatingTokensSet release];
	// if(commentTokensSet) [commentTokensSet release];
	[super dealloc];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
	NSMenu *menu = [[self class] defaultMenu];
	int insertionIndex = 0;
	NSArray* items = [menu itemArray];

	// Check if context menu additions were added already
	for(insertionIndex = 0; insertionIndex < [items count]; insertionIndex++) {
		if([[items objectAtIndex:insertionIndex] tag] == kShowHelpContextMenuItemTag)
			return menu;
	}

	// Add additional menu items
	// Look for insertion index (after the first separator)
	for(insertionIndex = 0; insertionIndex < [items count]; insertionIndex++) {
		if([[items objectAtIndex:insertionIndex] isSeparatorItem])
			break;
	}
	insertionIndex++;

	SLog(@"RTextView: add additional menu items at postion %d to context menu", insertionIndex);

	NSMenuItem *anItem;
	anItem = [[NSMenuItem alloc] initWithTitle:NLS(@"Show Help for current Function") action:@selector(showHelpForCurrentFunction) keyEquivalent:@"h"];
	[anItem setKeyEquivalentModifierMask:NSControlKeyMask];
	[anItem setTag:kShowHelpContextMenuItemTag];
	[menu insertItem:anItem atIndex:insertionIndex++];
	[anItem release];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:insertionIndex++];

	return menu;

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

	SLog(@"RTextView: keyDown: %@ *** \"%@\" %d", theEvent, rc, modFlags);

	if ([rc isEqual:@"."] && (modFlags&allFlags)==NSControlKeyMask) {
		SLog(@" - send complete: to self");
		[self complete:self];
		return;
	}
	if ([rc isEqual:@"="]) {
		int mf = modFlags&allFlags;
		if ( mf ==NSControlKeyMask) {
			[self insertText:@"<-"];
			return;
		}
		if ( mf == NSAlternateKeyMask ) {
			[self insertText:@"!="];
			return;
		}
	}
	if ([rc isEqual:@"-"] && (modFlags&allFlags)==NSAlternateKeyMask) {
		[self insertText:@" <- "];
		return;
	}
	if ([rc isEqual:@"h"] && (modFlags&allFlags)==NSControlKeyMask) {
		SLog(@" - send showHelpForCurrentFunction to self");
		[self showHelpForCurrentFunction];
		return;
	}
	if (cc && [cc length]==1 && RTextView_autoCloseBrackets) {
		unsigned int ck = [cc characterAtIndex:0];
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
						[ts addAttribute:kTALinked value:TAVal range:r];
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
			} else if (c == '#' && context == pcExpression)
				return pcComment;
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

	if(!separatingTokensSet)
		separatingTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"()'\"+-=/* ,\t[]{}^|&!:;<>?`\n"] retain];

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
		userRange.length = 1;
	} else { // normal completion
		userRange.location++; // skip past first bad one
		userRange.length = selection.location - userRange.location;
		SLog(@" - returned range: %d:%d", userRange.location, userRange.length);
		[self setSelectedRange:userRange];
	}

	return userRange;

}

/**
 * Returns the range of the current word relative the current cursor position
 *   finds: [| := caret]  |word  wo|rd  word|
 *   if | is in between whitespaces range length is zero.
 */
- (NSRange)getRangeForCurrentWord
{
	return [self getRangeForCurrentWordOfRange:[self selectedRange]];
}

- (NSRange)getRangeForCurrentWordOfRange:(NSRange)curRange
{

	if (curRange.length) return curRange;

	NSString *str = [self string];
	int curLocation = curRange.location;
	int start = curLocation;
	int end = curLocation;
	unsigned int strLen = [[self string] length];
	NSMutableCharacterSet *wordCharSet = [NSMutableCharacterSet alphanumericCharacterSet];
	[wordCharSet addCharactersInString:@"_."];

	if(start) {
		start--;
		if(CFStringGetCharacterAtIndex((CFStringRef)str, start) != '\n' || CFStringGetCharacterAtIndex((CFStringRef)str, start) != '\r') {
			while([wordCharSet characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)str, start)]) {
				start--;
				if(start < 0) break;
			}
		}
		start++;
	}

	while(end < strLen && [wordCharSet characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)str, end)])
		end++;

	// correct range if found range ends with a .
	NSRange wordRange = NSMakeRange(start, end-start);
	if(wordRange.length && CFStringGetCharacterAtIndex((CFStringRef)str, NSMaxRange(wordRange)-1) == '.')
		wordRange.length--;

	SLog(@"RTextView: returned range for current word: %@", NSStringFromRange(wordRange));

	return(wordRange);

}

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

	if(helpString) {
		[[HelpManager sharedController] showHelpFor:helpString];
		return;
	}

	if(isRConsole)
		[[NSApp keyWindow] makeFirstResponder:[[self delegate] valueForKeyPath:@"helpSearch"]];
	else
		[[NSApp keyWindow] makeFirstResponder:[[self delegate] valueForKeyPath:@"searchToolbarField"]];

}


- (void)currentFunctionHint
{

	NSString *helpString = [self functionNameForCurrentScope];

	if(helpString && ![helpString isMatchedByRegex:@"(?s)[^\\w\\d_\\.]"] && [[self delegate] respondsToSelector:@selector(hintForFunction:)]) {
		SLog(@"RTextView: currentFunctionHint for '%@'", helpString);
		[(RController*)[self delegate] hintForFunction:helpString];
	}

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
	if(isRConsole) {
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
	for(index = NSMaxRange(parseRange) - 1; index > parseRange.location; index--) {
		unichar c = CFStringGetCharacterAtIndex((CFStringRef)parseString, index);
		closed = (c == ')');
		opened = (c == '(');
		// Check if we're not inside of quotes or comments
		if( ( closed || opened)
			&& (index > parseRange.location)
			&& [self parserContextForPosition:(index-1)] != pcExpression) {
			continue;
		}
		if(closed) parentheses--;
		if(opened) parentheses++;
		if(parentheses > 0) break;
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

@end
