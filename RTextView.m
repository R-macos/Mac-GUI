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

#import "RGUI.h"

#define kTALinked @"RTVLinkedChar"
#define TAVal @""

BOOL RTextView_autoCloseBrackets = YES;

@interface RTextView (Private)
BOOL console;
NSCharacterSet *separatingTokensSet;
NSCharacterSet *commentTokensSet;
@end

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

- (void) awakeFromNib
{
	separatingTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"()'\"+-=/* ,\t[]{}^|&!:;<>?`\n"] retain];
	 commentTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"#"] retain];
	 SLog(@"RTextView: awakeFromNib %@", self);
	 console = NO;
}

// parser context in text
#define pcStringSQ @"singe quote string"
#define pcStringDQ @"double quote string"
#define pcStringBQ @"back quote string"
#define pcComment  @"comment"
#define pcExpression @"expression"

// returns the parser context for a given position
// the current implementation ignores multi-line strings
- (NSString*) parserContextForPosition: (int) x
{
	NSString *context = pcExpression;
	if (x<1) return context;
	NSString *string = [self string];
	if (x > [string length]) x = [string length];
	NSRange thisLine = [string lineRangeForRange: NSMakeRange(x, 0)];
	
	// we do NOT support multi-line strings, so the line always starts as an expression
	if (thisLine.location == x) return context;
	SLog(@"textView: parserContextForPosition: %d, line span=%d:%d", x, thisLine.location, thisLine.length);
	
	int i = thisLine.location;
	BOOL skip = NO;
	while (i < x) {
		unichar c;
		@try {
			c = [string characterAtIndex:i];
		}
		@catch (id ae) {
			return context;
		}
		if (skip)
			skip = NO;
		else {
			if (c == '\\' && (context == pcStringDQ || context == pcStringSQ || context == pcStringBQ)) {
				skip = YES;
			} else if (c == '"') {
				if (context == pcStringDQ) context = pcExpression;
				else if (context == pcExpression) context = pcStringDQ;
			} else if (c == '`') {
				if (context == pcStringBQ) context = pcExpression;
				else if (context == pcExpression) context = pcStringBQ;
			} else if (c == '\'') {
				if (context == pcStringSQ) context = pcExpression;
				else if (context == pcExpression) context = pcStringSQ;
			} else if (c == '#' && context == pcExpression) return pcComment;
		}
		i++;
	}
	return context;	
}

- (NSRange) rangeForUserCompletion 
{
	NSRange userRange;
	NSRange selection = [self selectedRange];
	NSString *string = [self string];
	int cursor = selection.location + selection.length; // we complete at the end of the selection
	NSString *context = [self parserContextForPosition: cursor];
	SLog(@" - rangeForUserCompletion: parser context: %@", context);
	if (context == pcComment) return NSMakeRange(NSNotFound,0); // no completion in comments
	if (context == pcStringDQ || context == pcStringSQ) // we're in a string, hence file completion
														// the beginning of the range doesn't matter, because we're guaranteed to find a string separator on the same line
		userRange = [string rangeOfCharacterFromSet: [NSCharacterSet characterSetWithCharactersInString: (context == pcStringDQ)?@"\" /":@"' /"] options: NSBackwardsSearch|NSLiteralSearch range: NSMakeRange(0, selection.location)];
	if (context == pcExpression || context == pcStringBQ) // we're in an expression or back-quote, so use R separating tokens (we could be smarter about the BQ but well..)
		userRange = [string rangeOfCharacterFromSet: separatingTokensSet options: NSBackwardsSearch|NSLiteralSearch range: NSMakeRange(0, selection.location)];
	if( userRange.location == NSNotFound )
		// everything is one expression - we're guaranteed to be in the first line (because \n would match)
		return NSMakeRange( 0, cursor );
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

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *rc = [theEvent charactersIgnoringModifiers];
	NSString *cc = [theEvent characters];
	unsigned int modFlags = [theEvent modifierFlags];
	SLog(@"RTextView: keyDown: %@ *** \"%@\" %d", theEvent, rc, modFlags);
	if ([rc isEqual:@"."] && (modFlags&(NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))==NSControlKeyMask) {
		SLog(@" - send complete: to self");
		[self complete:self];
		return;
	}
	if ([rc isEqual:@"="]) {
		int mf = modFlags&(NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
		if ( mf ==NSControlKeyMask) {
			[self insertText:@"<-"];
			return;
		}
		if ( mf == NSAlternateKeyMask ) {
			[self insertText:@"!="];
			return;
		}
	}
	if ([rc isEqual:@"-"] && (modFlags&(NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))==NSAlternateKeyMask) {
		[self insertText:@" <- "];
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
	if ((modFlags&(NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))==NSControlKeyMask) {
		if ([rc isEqual:@"{"]) {
			
		} else if ([rc isEqual:@"}"]) {
			
		}
	}
	[super keyDown:theEvent];
}

// if the current position and the next one are matching pairs,
// select both (mathing means that the closing part must be linked)
- (void) selectMatchingPairAt: (int) pos
{
	@try {
		unichar c = [[self string] characterAtIndex: pos - 1];
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
			unichar cs = [[self string] characterAtIndex: pos];
			if (cs == cc) {
				id attr = [[self textStorage] attribute:kTALinked atIndex:pos effectiveRange:0];
				if (attr) 
					[self setSelectedRange:NSMakeRange(pos - 1,2)];
			}
		}
	}
	@catch (id ee) {}
}

- (void) deleteBackward: (id) sender {
	NSRange r = [self selectedRange];
	if (r.length == 0 && r.location > 0) 
		[self selectMatchingPairAt: r.location];
	[super deleteBackward: sender];
}

- (void) deleteForward: (id) sender
{
	NSRange r = [self selectedRange];
	if (r.length == 0) 
		[self selectMatchingPairAt: r.location + 1];
	[super deleteForward: sender];
}

- (void) setConsoleMode: (BOOL) isConsole {
	console = isConsole;
	SLog(@"RTextView: set console flag to %@ (%@)", isConsole?@"yes":@"no", self);
}

@end
