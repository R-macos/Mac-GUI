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
 *  Created by Rob Goedman, 2/9/2005
 *
 */

#import "../RController.h"
#import "SyntaxColorsPrefPane.h"


@interface SyntaxColorsPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation SyntaxColorsPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if (self = [super init]) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"colorsPP"] copy];
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

- (void) awakeFromNib
{
	[self updatePreferences];
	[[Preferences sharedPreferences] addDependent:self];
}

- (void) dealloc
{
	[[Preferences sharedPreferences] removeDependent:self];
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
		[NSBundle loadNibNamed:@"SyntaxColorsPrefPane" owner:self];
	}
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
{
	// this is a hack to make sure no well is active since strange things happen if we close with an active well
	// (fixes PR#13625)
	[normalSyntaxColorWell activate:YES];
	[normalSyntaxColorWell deactivate];
}

- (void)didUnselect
{}

	/* end of std methods implementation */


- (IBAction)changeNormalColor:(id)sender {
	[Preferences setKey:normalSyntaxColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeStringColor:(id)sender {
	[Preferences setKey:stringSyntaxColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeNumberColor:(id)sender {
	[Preferences setKey:numberSyntaxColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeKeywordColor:(id)sender {
	[Preferences setKey:keywordSyntaxColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeCommentColor:(id)sender {
	[Preferences setKey:commentSyntaxColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeIdentifierColor:(id)sender {
	[Preferences setKey:identifierSyntaxColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (void) updatePreferences
{
	NSColor *c=[Preferences unarchivedObjectForKey:normalSyntaxColorKey withDefault:nil];
	if (c && ![c isEqualTo:[normalSyntaxColorWell color]]) [normalSyntaxColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:stringSyntaxColorKey withDefault:nil];
	if (c && ![c isEqualTo:[stringSyntaxColorWell color]]) [stringSyntaxColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:numberSyntaxColorKey withDefault:nil];
	if (c && ![c isEqualTo:[numberSyntaxColorWell color]]) [numberSyntaxColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:keywordSyntaxColorKey withDefault:nil];
	if (c && ![c isEqualTo:[keywordSyntaxColorWell color]]) [keywordSyntaxColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:commentSyntaxColorKey withDefault:nil];
	if (c && ![c isEqualTo:[commentSyntaxColorWell color]]) [commentSyntaxColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:identifierSyntaxColorKey withDefault:nil];
	if (c && ![c isEqualTo:[identifierSyntaxColorWell color]]) [identifierSyntaxColorWell setColor:c];
}

- (IBAction) setDefaultSyntaxColors:(id)sender
{
	[Preferences setKey:normalSyntaxColorKey withArchivedObject:
		[NSColor colorWithDeviceRed:0.025 green:0.085 blue:0.600 alpha:1.0]];
	[Preferences setKey:stringSyntaxColorKey withArchivedObject:
		[NSColor colorWithDeviceRed:0.690 green:0.075 blue:0.000 alpha:1.0]];
	[Preferences setKey:numberSyntaxColorKey withArchivedObject:
		[NSColor colorWithDeviceRed:0.020 green:0.320 blue:0.095 alpha:1.0]];
	[Preferences setKey:keywordSyntaxColorKey withArchivedObject:
		[NSColor colorWithDeviceRed:0.765 green:0.535 blue:0.025 alpha:1.0]];
	[Preferences setKey:commentSyntaxColorKey withArchivedObject:
		[NSColor colorWithDeviceRed:0.312 green:0.309 blue:0.309 alpha:1.0]];
	[Preferences setKey:identifierSyntaxColorKey withArchivedObject:
		[NSColor colorWithDeviceRed:0.000 green:0.000 blue:0.000 alpha:1.0]];
}

@end
