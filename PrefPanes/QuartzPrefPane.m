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
 */

#import "QuartzPrefPane.h"
#import "PreferenceKeys.h"
#import "Preferences.h"


@interface QuartzPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation QuartzPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if (self = [super init]) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"quartzPP"] copy];
		[theImage setFlipped:NO];
		[theImage lockFocus];
		[[NSColor blackColor] set];
	//	[theIdentifier drawAtPoint:NSZeroPoint withAttributes:nil];
		[theImage unlockFocus];
		[theImage recache];
		[self setIcon:theImage];
	}
	return self;
}

- (void) dealloc {
	[[Preferences sharedPreferences] removeDependent: self];
	[super dealloc];
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
	if (!mainView) {
		[NSBundle loadNibNamed:@"QuartzPrefPane" owner:self];
	}
	[self updatePreferences];
	return mainView;
}


// AMPrefPaneInformalProtocol

- (void)willSelect
{}

- (void)didSelect
{}

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

- (void)willUnselect
{}

- (void)didUnselect
{}

// QuartzPrefPane specific

- (void) awakeFromNib
{
	[self updatePreferences];
	[[Preferences sharedPreferences] addDependent:self];
}

- (void) updatePreferences
{
	[useQuartzPrefPaneSettings setEnabled:NSOnState];
	BOOL flag=[Preferences flagForKey:useQuartzPrefPaneSettingsKey withDefault: NO];
	[useQuartzPrefPaneSettings setState:(flag?NSOnState:NSOffState)];
	if (flag) {
		[quartzPrefPaneWidth setEnabled:NSOnState];
		[quartzPrefPaneHeight setEnabled:NSOnState];
	} else {
		[quartzPrefPaneWidth setEnabled:NSOffState];
		[quartzPrefPaneHeight setEnabled:NSOffState];
	}
	[quartzPrefPaneWidth setStringValue:
		[Preferences stringForKey:quartzPrefPaneWidthKey withDefault: @"4.5"]];
	[quartzPrefPaneHeight setStringValue:
		[Preferences stringForKey:quartzPrefPaneHeightKey withDefault: @"4.5"]];
	
	[quartzPrefPaneLocation setEnabled:NSOnState];
	NSString *i = [Preferences stringForKey:quartzPrefPaneLocationKey withDefault: @"Top Left"];
	if (i) [quartzPrefPaneLocation selectItemWithTitle:i];
}

- (IBAction) changeUseQuartzPrefPaneSettings:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:useQuartzPrefPaneSettingsKey withFlag:flag];
}

- (IBAction) changeQuartzPrefPaneWidth:(id)sender {
	NSString *width = ([[sender stringValue] length] == 0)?@"4.5":[sender stringValue];
	if ([width length] == 0) {
		width = @"4.5";
	} else {
		double value = [width doubleValue];
		if (value < 4.5)
			width = @"4.5";
		else if (value > 12.0)
			width = @"12.0";
	}
	[Preferences setKey:quartzPrefPaneWidthKey withObject:width];
}

- (IBAction) changeQuartzPrefPaneHeight:(id)sender {
	NSString *height = ([[sender stringValue] length] == 0)?@"4.5":[sender stringValue];
	if ([height length] == 0) {
		height = @"4.5";
	} else {
		double value = [height doubleValue];
		if (value < 4.5)
			height = @"4.5";
		else if (value > 10.0)
			height = @"10.0";
	}
	[Preferences setKey:quartzPrefPaneHeightKey withObject:height];
}

- (IBAction) changeQuartzPrefPaneLocation:(id)sender {
	NSString *val = [quartzPrefPaneLocation titleOfSelectedItem];
	NSNumber *ival = [[NSNumber alloc] initWithInt:[quartzPrefPaneLocation indexOfSelectedItem]];
	[Preferences setKey:quartzPrefPaneLocationKey withObject:val];
	[Preferences setKey:quartzPrefPaneLocationIntKey withObject:ival];
}

- (void) changeQuartzPrefPaneFont:(id)sender {
}

- (void) changeQuartzPrefPaneDefaults:(id)sender {
	[[Preferences sharedPreferences] beginBatch];
	[useQuartzPrefPaneSettings setState:NSOffState];
	[Preferences setKey:useQuartzPrefPaneSettingsKey withFlag:NSOffState];
	[quartzPrefPaneWidth setStringValue:@"4.5"];
	[Preferences setKey:quartzPrefPaneWidthKey withObject:@"4.5"];
	[quartzPrefPaneHeight setStringValue:@"4.5"];
	[Preferences setKey:quartzPrefPaneHeightKey withObject:@"4.5"];

	[quartzPrefPaneLocation selectItemWithTitle:@"Top Left"];
	[Preferences setKey:quartzPrefPaneLocationKey withObject:@"Top Left"];
	[Preferences setKey:quartzPrefPaneLocationIntKey withObject:[NSNumber numberWithInt:3]];

	[useQuartzPrefPaneSettings setEnabled:NSOnState];
	[quartzPrefPaneWidth setEnabled:NSOnState];
	[quartzPrefPaneHeight setEnabled:NSOnState];
	[quartzPrefPaneLocation setEnabled:NSOnState];
	[quartzPrefPaneFont setEnabled:NSOffState];

//	[quartzPrefPaneFont ...];
//	[quartzPrefPaneFontSize ...];
	[quartzPrefPaneFontSize setEnabled:NSOffState];
	[[Preferences sharedPreferences] endBatch];
}


@end
