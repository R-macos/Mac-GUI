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
	SLog(@"RTextView: awakeFromNib %@", self);
	console = NO;
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
		switch (ck) {
			case '{':
				complement = @"}";
			case '(':
				if (!complement) complement = @")";
			case '[':
				if (!complement) complement = @"]";
				SLog(@"RTextView: open bracket chracter %c", ck);
				[super keyDown:theEvent];
				{
					NSRange r = [self selectedRange];
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
				{
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

- (void) setConsoleMode: (BOOL) isConsole {
	console = isConsole;
	SLog(@"RTextView: set console flag to %@ (%@)", isConsole?@"yes":@"no", self);
}

@end
