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


#import "MiscPrefPane.h"
#import "../RController.h"
#import "../Tools/Authorization.h"

@interface MiscPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation MiscPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if (self = [super init]) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"miscPP"] copy];
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
	if (!mainView && [NSBundle loadNibNamed:@"MiscPrefPane" owner:self]) {
		// load the default for RAquaLibPath
		NSData *theData=[[NSUserDefaults standardUserDefaults] dataForKey:miscRAquaLibPathKey];
		BOOL flag = !isAdmin(); // the default is YES for users and NO for admins
		if (theData!=nil)
			flag=[(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"];
		[cbRAquaPath setState: flag?NSOnState:NSOffState];
	}
	
	return mainView;
}

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

- (IBAction) changeEditOrSource:(id)sender {
	BOOL flag = ([[sender cellAtRow:0 column:0] state] == NSOffState)?NO:YES;
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:flag?@"YES":@"NO"] forKey:editOrSourceKey];
	[self setOpenInEditor:flag] ;
}

- (void) setOpenInEditor:(BOOL)flag {
	//	NSLog(@"setOpenInEditor called: %d on %@", flag, editOrSource);
	[editOrSource setState:flag?NSOffState:NSOnState atRow:1 column:0];
	[editOrSource setState:flag?NSOnState:NSOffState atRow:0 column:0];
	[[RController getRController] setOpenInEditor: flag];
}

- (IBAction) changeLibPaths:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[sender state]?@"YES":@"NO"] forKey:miscRAquaLibPathKey];
}

@end
