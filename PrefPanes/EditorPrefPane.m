/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004  The R Foundation
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
 */


#import "EditorPrefPane.h"
#import "../RController.h"
#import "../Tools/Authorization.h"

@interface EditorPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation EditorPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if (self = [super init]) {
		[[Preferences sharedPreferences] addDependent:self];
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"RDoc"] copy];
		[theImage setFlipped:NO];
		[theImage lockFocus];
		[[NSColor blackColor] set];
		//		[theIdentifier drawAtPoint:NSZeroPoint withAttributes:nil];
		[theImage unlockFocus];
		[theImage recache];
		[self setIcon:theImage];
	}
	return self;
}

- (void) dealloc
{
	[[Preferences sharedPreferences] removeDependent: self];
}


- (NSString *)identifier
{
    return identifier;
}

- (void)setIdentifier:(NSString *)newIdentifier
{
    id old = nil;
	
    if (newIdentifier != identifier) {
        old = identifier;
        identifier = [newIdentifier copy];
        [old release];
    }
}

- (NSString *)label
{
    return label;
}

- (void)setLabel:(NSString *)newLabel
{
    id old = nil;
	
    if (newLabel != label) {
        old = label;
        label = [newLabel copy];
        [old release];
    }
}

- (NSString *)category
{
    return category;
}

- (void)setCategory:(NSString *)newCategory
{
    id old = nil;
	
    if (newCategory != category) {
        old = category;
        category = [newCategory copy];
        [old release];
    }
}

- (NSImage *)icon
{
    return icon;
}

- (void)setIcon:(NSImage *)newIcon
{
    id old = nil;
	
    if (newIcon != icon) {
        old = icon;
        icon = [newIcon retain];
        [old release];
    }
}


// AMPrefPaneProtocol
- (NSView *)mainView
{
	if (!mainView && [NSBundle loadNibNamed:@"EditorPrefPane" owner:self])
		[self updatePreferences];
	return mainView;
}

// AMPrefPaneInformalProtocol

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

/* end of std methods implementation */

- (void) awakeFromNib
{
	[self updatePreferences];
}

- (void) updatePreferences
{
	BOOL flag=[Preferences flagForKey:internalOrExternalKey withDefault: YES];
	[internalOrExternal setState:(flag?NSOnState:NSOffState) atRow:0 column:0];
	[internalOrExternal setState:(flag?NSOffState:NSOnState) atRow:0 column:1];
//	[builtInPrefs setHidden:flag?NSOffState:NSOnState];
	[showSyntaxColoring setEnabled:flag?NSOnState:NSOffState];
	[showBraceHighlighting setEnabled:flag?NSOnState:NSOffState];
	[highlightInterval setEnabled:flag?NSOnState:NSOffState];
//	[externalSettings setHidden:flag?NSOffState:NSOnState];
	[changeEditor setEnabled:(flag?NSOffState:NSOnState)];
	[appOrCommand setEnabled:(flag?NSOffState:NSOnState)];
	[externalEditorName setEnabled:(flag?NSOffState:NSOnState)];
	
	NSArray *pathComps = [[Preferences stringForKey:externalEditorNameKey withDefault: @"TextEdit"] componentsSeparatedByString:@"/"];
	NSString *name = [pathComps objectAtIndex: ([pathComps count] - 1)];
	pathComps = [name componentsSeparatedByString:@".app"];
	name = [pathComps objectAtIndex:0];
	[externalEditorName setStringValue:name];

	[showSyntaxColoring setState:[Preferences flagForKey:showSyntaxColoringKey withDefault: YES]?NSOnState:NSOffState];

	[showBraceHighlighting setState:[Preferences flagForKey:showBraceHighlightingKey withDefault: YES]?NSOnState:NSOffState];

	[highlightInterval setStringValue:[Preferences stringForKey:highlightIntervalKey withDefault: @"0.30"]];

	[showLineNumbers setState:[Preferences flagForKey:showLineNumbersKey withDefault: YES]?NSOnState:NSOffState];

	flag=[Preferences flagForKey:appOrCommandKey withDefault: YES];
	[appOrCommand setState:flag?NSOffState:NSOnState atRow:1 column:0];
	[appOrCommand setState:flag?NSOnState:NSOffState atRow:0 column:0];
}

- (IBAction) changeInternalOrExternal:(id)sender
{
	BOOL flag=[Preferences flagForKey:internalOrExternalKey withDefault: YES];
	[Preferences setKey:internalOrExternalKey withFlag:!flag];
}

- (void)changeExternalEditorName:(id)sender {
	NSString *name = ([[sender stringValue] length] == 0)?@"TextEdit":[sender stringValue];
	[Preferences setKey:externalEditorNameKey withObject:name];
}

- (IBAction) changeShowSyntaxColoring:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:showSyntaxColoringKey withFlag:flag];
}

- (IBAction) changeShowBraceHighlighting:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:showBraceHighlightingKey withFlag:flag];
}

- (IBAction) changeHighlightInterval:(id)sender {
	NSString *interval = ([[sender stringValue] length] == 0)?@"0.2":[sender stringValue];
	if ([interval length] == 0) {
		interval = @"0.2";
	} else {
		double value = [interval doubleValue];
		if (value < 0.1)
			interval = @"0.1";
		else if (value > 0.8)
			interval = @"0.8";
	}
	[Preferences setKey:highlightIntervalKey withObject:interval];
}

- (IBAction) changeShowLineNumbers:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:showLineNumbersKey withFlag:flag];
}

- (IBAction) changeAppOrCommand:(id)sender {
	BOOL flag=[Preferences flagForKey:appOrCommandKey withDefault: YES];
	[Preferences setKey:appOrCommandKey withFlag:!flag];
}

- (IBAction) changeEditor:(id)sender;
{
	int answer;
	NSOpenPanel *sp;
	sp = [NSOpenPanel openPanel];
	[sp setTitle:@"Select editor application"];
	answer = [sp runModalForDirectory:@"/Applications" file:nil types:nil];
	if(answer == NSOKButton) {
		[Preferences setKey:externalEditorNameKey withObject:[sp filename]];
	}
}

@end
