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
static SEL _getSel;
static SEL _setSel;
static SEL _strSel;
static SEL _replSel;
static SEL _editSel;
static SEL _getlSel;


+ (void)initialize
{

	if ([self class] == [RScriptEditorTextStorage class]) {
		FoldingSignTextAttachmentCell *cell = [[FoldingSignTextAttachmentCell alloc] initImageCell:nil];
		sharedAttachment = [[NSTextAttachment alloc] init];
		[sharedAttachment setAttachmentCell:cell];
		[cell release];
		_getSel  = @selector(attributesAtIndex:effectiveRange:);
		_setSel  = @selector(setAttributes:range:);
		_strSel  = @selector(string);
		_replSel = @selector(replaceCharactersInRange:withString:);
		_editSel = @selector(edited:range:changeInLength:);
		_getlSel = @selector(attribute:atIndex:longestEffectiveRange:inRange:);

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
		_getImp  = [_attributedString methodForSelector:_getSel];
		_setImp  = [_attributedString methodForSelector:_setSel];
		_strImp  = [_attributedString methodForSelector:_strSel];
		_replImp = [_attributedString methodForSelector:_replSel];
		_editImp = [self methodForSelector:_editSel];
		_getlImp = [_attributedString methodForSelector:_getlSel];

		foldedCounter = 0;

		for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
			foldedRanges[i][0] = -1;
			foldedRanges[i][1] = 0;
		}
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_attributedString release];
	if(sharedAttachment) [sharedAttachment release];
	[super dealloc];
}

- (BOOL)hasFoldedItems
{
	return (foldedCounter == 0) ? NO : YES;
}

- (NSInteger)foldedAtIndex:(NSInteger)index
{

	if(!foldedCounter) return -1;

	NSInteger i = 0;
	for(i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
		if(foldedRanges[i][0] <= index && foldedRanges[i][0]+foldedRanges[i][1] > index) {
			return i;
		}
	}
	return -1;
}

- (NSInteger)foldedForIndicatorAtIndex:(NSInteger)index
{

	if(!foldedCounter) return -1;

	if(index) {
		// Folded ranges are stored from { to } but indicator will drawn inside of { and }
		for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
			if(foldedRanges[i][0] > -1 && foldedRanges[i][0] <= (index-1) && foldedRanges[i][0]+foldedRanges[i][1] > index+1) {
				return i;
			}
		}
	}
	return -1;
}

- (NSInteger)registerFoldedRange:(NSRange)range
{

	NSInteger index = -1;
	for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
		if(foldedRanges[i][0] == -1) {
			index = i;
			foldedRanges[i][0] = (NSInteger)range.location;
			foldedRanges[i][1] = (NSInteger)range.length;
			foldedCounter++;
			break;
		}
	}

	return(index);

}

- (BOOL)removeFoldedRangeWithId:(NSNumber*)index
{

	NSInteger i = [index integerValue];

	if(i < 0 || i >= R_MAX_FOLDED_ITEMS) {
		[self removeAllFoldedRanges];
		return NO;
	}

	[[[self delegate] undoManager] disableUndoRegistration];

	NSRange range = NSMakeRange(foldedRanges[i][0], foldedRanges[i][1]);
	range = NSIntersectionRange(NSMakeRange(0, [_attributedString length]), range);
	if(range.length) {
		[self beginEditing];
		// [self removeAttribute:foldingAttributeName range:range];
		[self removeAttribute:foldingAttributeId range:range];
		[self removeAttribute:NSCursorAttributeName range:range];
		[self removeAttribute:NSToolTipAttributeName range:range];
		[self endEditing];
	}

	foldedRanges[i][0] = -1;
	foldedRanges[i][1] = 0;
	foldedCounter--;
	if(foldedCounter < 0) foldedCounter = 0;

	[[[self delegate] undoManager] enableUndoRegistration];

	return YES;
}

- (void)removeAllFoldedRanges
{
	for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
		foldedRanges[i][0] = -1;
		foldedRanges[i][1] = 0;
	}
	[[[self delegate] undoManager] disableUndoRegistration];
	NSRange range = NSMakeRange(0, [_attributedString length]);
	[self beginEditing];
	// [self removeAttribute:foldingAttributeName range:range];
	[self removeAttribute:foldingAttributeId range:range];
	[self removeAttribute:NSCursorAttributeName range:range];
	[self removeAttribute:NSToolTipAttributeName range:range];
	[self endEditing];
	[[[self delegate] undoManager] enableUndoRegistration];
	foldedCounter = 0;
}

- (BOOL)existsFoldedRange:(NSRange)range
{

	if(!foldedCounter) return NO;

	BOOL success = NO;
	for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
		if(foldedRanges[i][0] == range.location && foldedRanges[i][1] == range.length) {
			success = YES;
			break;
		}
	}

	return success;
	
}

- (NSRange)foldedRangeAtIndex:(NSInteger)index
{

	if(!foldedCounter || index < 0 || index > R_MAX_FOLDED_ITEMS) return NSMakeRange(NSNotFound, 0);

	NSInteger loc = foldedRanges[index][0];
	if(loc == -1) return NSMakeRange(NSNotFound, 0);
	return NSMakeRange(loc, foldedRanges[index][1]-foldedRanges[index][0]);
}

// NSAttributedString primitives
- (NSString *)string
{ 
	return (*_strImp)(_attributedString, _strSel);
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{

	NSDictionary *attributes = (*_getImp)(_attributedString, _getSel, location, range);

	if(!foldedCounter) return attributes;

	NSRange effectiveRange;

	// Check if location is inside folded range for drawing indicator
	NSInteger index = -1;
	if(location) {
		// Notes folded ranges are stored from { to } but indicator will drawn inside of { and }
		for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
			if(foldedRanges[i][0] <= (location-1) && foldedRanges[i][0]+foldedRanges[i][1] > location+2) {
				index = i;
				break;
			}
		}
	}

	if (index > -1) {
		effectiveRange = NSMakeRange(foldedRanges[index][0]+1, foldedRanges[index][1]-2);
		// We adds NSAttachmentAttributeName if in lineFoldingAttributeName
		if (location == effectiveRange.location) { // beginning of a folded range

			NSMutableDictionary *dict = [attributes mutableCopyWithZone:NULL];
			[dict setObject:sharedAttachment forKey:NSAttachmentAttributeName];
			attributes = [dict autorelease];
			effectiveRange.length = 1;

		} else {
			++(effectiveRange.location); --(effectiveRange.length);
		}
		if (range) *range = effectiveRange;
	}

	return attributes;

}

- (void)edited:(NSUInteger)mask range:(NSRange)oldRange changeInLength:(NSInteger)lengthChange
{

	if(foldedCounter && mask == NSTextStorageEditedCharacters) {
		// update foldedRanges array
		NSInteger index = oldRange.location;
		for(NSInteger i = 0; i < R_MAX_FOLDED_ITEMS; i++) {
			if(index < foldedRanges[i][0]) {
				if(foldedRanges[i][0] >= oldRange.location && foldedRanges[i][0]+foldedRanges[i][1] <= NSMaxRange(oldRange)) {
					[self removeFoldedRangeWithId:[NSNumber numberWithInt:i]];
					continue;
				}
				foldedRanges[i][0] += lengthChange;
				if(foldedRanges[i][0] < -1) {
					[self removeFoldedRangeWithId:[NSNumber numberWithInt:i]];
				}
			}
		}
	}

	[super edited:mask range:oldRange changeInLength:lengthChange];
}

// NSMutableAttributedString primitives
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
	(*_replImp)(_attributedString, _replSel, range, str);
	(*_editImp)(self, _editSel, NSTextStorageEditedCharacters, range, [str length] - range.length);
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
	(*_setImp)(_attributedString, _setSel, attrs, range);
	(*_editImp)(self, _editSel, NSTextStorageEditedAttributes, range, 0);
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
