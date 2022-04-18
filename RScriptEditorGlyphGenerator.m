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
 *  RScriptEditorGlyphGenerator.m
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "RGUI.h"
#import "RScriptEditorGlyphGenerator.h"
#import "RScriptEditorTypeSetter.h"
#import "RScriptEditorTextStorage.h"
#import "RScriptEditorLayoutManager.h"
#import "PreferenceKeys.h"

@implementation RScriptEditorGlyphGenerator

- (id)init
{
	self = [super init];

	if (self != nil) {
		nullGlyph = NSNullGlyph;
		sizeOfNSGlyph = sizeof(NSGlyph);
	}

	return self;
}

- (void)dealloc{
	if(theTextStorage) [theTextStorage release];
	[super dealloc];
}

- (void)setTextStorage:(RScriptEditorTextStorage*)textStorage
{
	if(theTextStorage) [theTextStorage release];
	theTextStorage = [textStorage retain];
}

- (void)generateGlyphsForGlyphStorage:(id <NSGlyphStorage>)glyphStorage desiredNumberOfCharacters:(NSUInteger)nChars glyphIndex:(NSUInteger *)glyphIndex characterIndex:(NSUInteger *)charIndex
{
	// Stash the original requester
	_destination = glyphStorage;
	[[NSGlyphGenerator sharedGlyphGenerator] generateGlyphsForGlyphStorage:self desiredNumberOfCharacters:nChars glyphIndex:glyphIndex characterIndex:charIndex];
	_destination = nil;
}

#pragma mark -
#pragma mark NSGlyphStoragePrimitives

- (void)insertGlyphs:(const NSGlyph *)glyphs length:(NSUInteger)length forStartingGlyphAtIndex:(NSUInteger)glyphIndex characterIndex:(NSUInteger)charIndex
{
	NSGlyph localBuffer[64]; /* stack-local buffer to avoid allocations */
	NSGlyph *buffer = NULL;
	NSInteger folded = [theTextStorage foldedAtIndex: charIndex];

	// SLog(@"%@ insertGlyphs: length:%d forStartingGlyphAtIndex:%d characterIndex:%d", self, (int) length, (int) glyphIndex, (int) charIndex);

	/* This part replaces the real glyphs with NSNullGlyph (empty) and/or NSControlGlyph (the symbol)
	   inside folded code.

	   FIXME: we only check whether the first glyph is inside a fold and then
	   replace the glyphs inside that fold. It is unclear if this can be called
	   with larger areas that include folds somewhere in the middle. Analogously,
	   it is unclear if there can be multiple folds in the requested glyph area.
	   Empirically, glyphs are inserted only for same attribues, so syntax highlighting
	   seems to help us here by splitting the text in a way that supports this
	   approach.
	 */
	 if (folded > -1) {
		NSRange effectiveRange = [theTextStorage foldedRangeAtIndex:folded];
		/* fold range includes the encloding { }, so we only care if we are actually inside and it's non-empty */
		if (effectiveRange.length &&
			charIndex + length > effectiveRange.location + 1 &&
			charIndex < NSMaxRange(effectiveRange) - 1) {
			SLog(@"insertGlyphs: glyphs [%d..%d] (@char %d, len %d), inside folded range %@ thus will replace glyphs",
				 (int) glyphIndex, (int) (glyphIndex + length - 1), (int) charIndex, (int) length,
				 NSStringFromRange(effectiveRange));

			/* we will be replacing something, so have to get a buffer for the glyphs we return */
			NSUInteger size = sizeOfNSGlyph * length;
			buffer = (size > sizeof(localBuffer)) ? NSZoneMalloc(NULL, size) : localBuffer;

			NSUInteger nullEnd = NSMaxRange(effectiveRange) - charIndex - 1;
			if (nullEnd > length)
				nullEnd = length;
			NSUInteger nullStart = effectiveRange.location + 1 - charIndex;
			NSUInteger nullLength = nullEnd - nullStart;
			if (nullLength < length) /* some have to be retained, so copy all and then null */
				memcpy(buffer, glyphs, sizeOfNSGlyph * length);
			/* it is actually 4 but for safety include a fall-back ... */
			if (sizeOfNSGlyph == 4)
				memset_pattern4(buffer + nullStart, &nullGlyph, sizeOfNSGlyph * nullLength);
			else {
				size_t i = nullStart;
				while (i < nullLength) buffer[i++] = nullGlyph;
			}
			/* the first glyph just after the { (position 1) is the visible glyph */
			NSInteger ctrlLocation = effectiveRange.location + 1 - charIndex;
			if (ctrlLocation >= 0 && ctrlLocation < length)
				buffer[ctrlLocation] = NSControlGlyph;
			glyphs = buffer;
		}
	}

	[_destination insertGlyphs:glyphs length:length forStartingGlyphAtIndex:glyphIndex characterIndex:charIndex];

	if (buffer && buffer != localBuffer)
		NSZoneFree(NULL, buffer);
}

- (void)setIntAttribute:(NSInteger)attributeTag value:(NSInteger)val forGlyphAtIndex:(NSUInteger)glyphIndex
{
	[_destination setIntAttribute:attributeTag value:val forGlyphAtIndex:glyphIndex];
}

- (NSAttributedString *)attributedString
{
	return [_destination attributedString];
}

- (NSUInteger)layoutOptions
{
	return [_destination layoutOptions] | NSShowControlGlyphs;
}

@end
