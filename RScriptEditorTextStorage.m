/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-12  The R Foundation
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
 *  RScriptEditorTextStorage.m
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "RScriptEditorTextStorage.h"
#import "RScriptEditorTypesetter.h"
#import "FoldingSignTextAttachmentCell.h"
#import "PreferenceKeys.h"

@implementation RScriptEditorTextStorage

@synthesize lineFoldingEnabled = _lineFoldingEnabled;

static NSTextAttachment *sharedAttachment = nil;

+ (void)initialize
{

	if ([self class] == [RScriptEditorTextStorage class]) {
		FoldingSignTextAttachmentCell *cell = [[FoldingSignTextAttachmentCell alloc] initImageCell:nil];
		sharedAttachment = [[NSTextAttachment alloc] init];
		[sharedAttachment setAttachmentCell:cell];
		[cell release];
	}
}

+ (NSTextAttachment *)attachment
{
	return sharedAttachment;
}

- (id)init
{
	self = [super init];

	if (self != nil) {
		_attributedString = [[NSTextStorage alloc] init];
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_attributedString release];
	[super dealloc];
}

// NSAttributedString primitives
- (NSString *)string
{ 
	return [_attributedString string];
}


- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{

	if(!_lineFoldingEnabled) return [_attributedString attributesAtIndex:location effectiveRange:range];

	NSDictionary *attributes = [_attributedString attributesAtIndex:location effectiveRange:range];

	if (_lineFoldingEnabled) {
		id value;
		NSRange effectiveRange;

		value = [attributes objectForKey:foldingAttributeName];
		if (value && [value boolValue]) {
			[_attributedString attribute:foldingAttributeName atIndex:location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, [_attributedString length])];

			// We adds NSAttachmentAttributeName if in lineFoldingAttributeName
			if (location == effectiveRange.location) { // beginning of a folded range
				NSMutableDictionary *dict = [attributes mutableCopyWithZone:NULL];
				[dict setObject:[RScriptEditorTextStorage attachment] forKey:NSAttachmentAttributeName];
				attributes = [dict autorelease];
				effectiveRange.length = 1;
			} else {
				++(effectiveRange.location); --(effectiveRange.length);
			}
			if (range) *range = effectiveRange;
		}
	}

	return attributes;
}

// NSMutableAttributedString primitives
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
	[_attributedString replaceCharactersInRange:range withString:str];
	[self edited:NSTextStorageEditedCharacters range:range changeInLength:[str length] - range.length];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
	[_attributedString setAttributes:attrs range:range];
	[self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

// Attribute Fixing Overrides
/*
- (void)fixAttributesInRange:(NSRange)range
{
	[super fixAttributesInRange:range];

	if(NSMaxRange(range) == 0) return;

	//	we want to avoid extending to the last paragraph separator
	NSDictionary *attributeDict;
	NSRange effectiveRange = { 0, 0 };
	NSUInteger idx = range.location;
	while (NSMaxRange(effectiveRange) < NSMaxRange(range)) {
		attributeDict = [_attributedString attributesAtIndex:idx
								   longestEffectiveRange:&effectiveRange
												 inRange:range];
		id value = [attributeDict objectForKey:foldingAttributeName];
		if (value && effectiveRange.length) {
			NSUInteger paragraphStart, paragraphEnd, contentsEnd;
			[[self string] getParagraphStart:&paragraphStart end:&paragraphEnd contentsEnd:&contentsEnd forRange:range];
			if ((NSMaxRange(range) == paragraphEnd) && (contentsEnd < paragraphEnd)) {
				[self removeAttribute:foldingAttributeName range:NSMakeRange(contentsEnd, paragraphEnd - contentsEnd)];
			}
		}
		idx = NSMaxRange(effectiveRange);
	}

	// 10.6 implementation
	// [self enumerateAttribute:lineFoldingAttributeName inRange:range options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
	// 	if (value && (range.length > 1)) {
	// 		NSUInteger paragraphStart, paragraphEnd, contentsEnd;
	// 		[[self string] getParagraphStart:&paragraphStart end:&paragraphEnd contentsEnd:&contentsEnd forRange:range];
	// 		if ((NSMaxRange(range) == paragraphEnd) && (contentsEnd < paragraphEnd)) {
	// 			[self removeAttribute:lineFoldingAttributeName range:NSMakeRange(contentsEnd, paragraphEnd - contentsEnd)];
	// 		}
	// 	}
	// }];
}
*/

@end
