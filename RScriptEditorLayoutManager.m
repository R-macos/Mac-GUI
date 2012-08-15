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
 *  RScriptEditorLayoutManager.m
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "RScriptEditorLayoutManager.h"
#import "RScriptEditorTypeSetter.h"
#import "RScriptEditorGlyphGenerator.h"
#import "RScriptEditorTextStorage.h"
#import "PreferenceKeys.h"

@implementation RScriptEditorLayoutManager

static SEL _setfSel;
 
- (id)init
{

	self = [super init];
    
	if (nil == self) return nil;

	// Setup LineFoldingTypesetter
	RScriptEditorTypeSetter *typesetter = [[RScriptEditorTypeSetter alloc] init];
	[self setTypesetter:typesetter];
	[typesetter release];
	
	// Setup LineFoldingGlyphGenerator
	RScriptEditorGlyphGenerator *glyphGenerator = [[RScriptEditorGlyphGenerator alloc] init];
	[self setGlyphGenerator:glyphGenerator];
	[glyphGenerator release];

	[self setBackgroundLayoutEnabled:YES];

	_setfSel = @selector(setLineFoldingEnabled:);

	return self;

}

- (void)dealloc
{
	if(_attributedString) [_attributedString release];
	[super dealloc];
}

- (void)replaceTextStorage:(id)textStorage
{
	if(_attributedString) [_attributedString release];
	_attributedString = [(RScriptEditorTextStorage*)textStorage retain];
	_setfImp  = [_attributedString methodForSelector:_setfSel];
	[(RScriptEditorGlyphGenerator*)[self glyphGenerator] setTextStorage:textStorage];
	[super replaceTextStorage:textStorage];
}

// - (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin
// {
// 	// (*_setfImp)(_attributedString, _setfSel, YES);
// 	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
// 	// (*_setfImp)(_attributedString, _setfSel, NO);
// }

// - (void)textStorage:(RScriptEditorTextStorage *)str edited:(NSUInteger)editedMask range:(NSRange)newCharRange changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidatedCharRange
// {
// 
// 	NSUInteger length = [str length];
// //	NSNumber *value;
// 	NSRange effectiveRange, range;
// 	NSInteger foldIndex;
// 
// 	// it's at the end. check if the last char is in foldingAttributeName
// 	if ((invalidatedCharRange.location == length) && (invalidatedCharRange.location != 0)) { 
// 		// value = [str attribute:foldingAttributeName atIndex:invalidatedCharRange.location - 1 effectiveRange:&effectiveRange];
// 		// if (value && [value boolValue]) invalidatedCharRange = NSUnionRange(invalidatedCharRange, effectiveRange);
// 		foldIndex = [str foldedForIndicatorAtIndex:invalidatedCharRange.location - 1];
// 		effectiveRange = [str foldedRangeAtIndex:foldIndex];
// 		effectiveRange.location++;
// 		effectiveRange.length-=2;
// 		if(foldIndex > -1) invalidatedCharRange = NSUnionRange(invalidatedCharRange, effectiveRange);
// 	}
// 
// 	if (invalidatedCharRange.location < length) {
// 		NSString *string = [str string];
// 		NSUInteger start, end;
// 		if (delta > 0) {
// 			NSUInteger contentsEnd;
// 			[string getParagraphStart:NULL end:&end contentsEnd:&contentsEnd forRange:newCharRange];
// 			if ((contentsEnd != end) && (invalidatedCharRange.location > 0) 
// 				&& (NSMaxRange(newCharRange) == end)) { 
// 				// there was para sep insertion. extend to both sides
// 				if (newCharRange.location <= invalidatedCharRange.location) {
// 					invalidatedCharRange.length = (NSMaxRange(invalidatedCharRange) - (newCharRange.location - 1));
// 					invalidatedCharRange.location = (newCharRange.location - 1);
// 				}
// 
// 				if ((end < length) && (NSMaxRange(invalidatedCharRange) <= end)) {
// 					invalidatedCharRange.length = ((end + 1) - invalidatedCharRange.location);
// 				}
// 			}
// 		}
// 
// 		range = invalidatedCharRange;
// 
// 		while ((range.location > 0) || (NSMaxRange(range) < length)) {
// 			[string getParagraphStart:&start end:&end contentsEnd:NULL forRange:range];
// 			range.location = start;
// 			range.length = (end - start);
// 
// 			// Extend backward
// 			foldIndex = [str foldedForIndicatorAtIndex:range.location];
// 			if(foldIndex > -1) {
// 				effectiveRange = [str foldedRangeAtIndex:foldIndex];
// 				if(effectiveRange.length) {
// 					// value = [str attribute:foldingAttributeName atIndex:range.location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, range.location + 1)];
// 					// if (value && [value boolValue] && (effectiveRange.location < range.location)) {
// 					effectiveRange.location++;
// 					if (effectiveRange.location < range.location) {
// 						range.length += (range.location - effectiveRange.location);
// 						range.location = effectiveRange.location;
// 					}
// 				}
// 			}
// 			// Extend forward
// 			if (NSMaxRange(range) < length) {
// 				// value = [str attribute:foldingAttributeName atIndex:NSMaxRange(range) longestEffectiveRange:&effectiveRange inRange:NSMakeRange(NSMaxRange(range), length - NSMaxRange(range))];
// 				// if (value && [value boolValue] && (NSMaxRange(effectiveRange) > NSMaxRange(range))) {
// 				foldIndex = [str foldedForIndicatorAtIndex:NSMaxRange(range)];
// 				if(foldIndex > -1) {
// 					effectiveRange = [str foldedRangeAtIndex:foldIndex];
// 					if(effectiveRange.length) {
// 						effectiveRange.location++;
// 						effectiveRange.length-=2;
// 						if(NSMaxRange(effectiveRange) > NSMaxRange(range)) {
// 							range.length = NSMaxRange(effectiveRange) - range.location;
// 						}
// 					}
// 				}
// 			}
// 
// 			if (NSEqualRanges(range, invalidatedCharRange)) break;
// 			invalidatedCharRange = range;
// 		}
// 	}
// 
// 	[super textStorage:str edited:editedMask range:newCharRange changeInLength:delta invalidatedRange:invalidatedCharRange];
// 
// }

@end
