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

#import "../RGUI.h"
#import "MiscPrefPane.h"
#import "../RController.h"
#import "../Tools/Authorization.h"

#import <unistd.h>
#import <sys/fcntl.h>

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
		[[Preferences sharedPreferences] addDependent:self];
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

- (void) dealloc {
	[[Preferences sharedPreferences] removeDependent:self];
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
	if (!mainView && [NSBundle loadNibNamed:@"MiscPrefPane" owner:self])
		[self updatePreferences];
	return mainView;
}

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

- (void) updatePreferences
{
	// load the default for RAquaLibPath
	// the default is YES for users and NO for admins
	BOOL flag = [Preferences flagForKey:miscRAquaLibPathKey withDefault: !isAdmin()];
	[cbRAquaPath setState: flag?NSOnState:NSOffState];
	
	flag=[Preferences flagForKey:editOrSourceKey withDefault: YES];
	if (flag)
		[editOrSource selectCellAtRow:0 column:0];
	else
		[editOrSource selectCellAtRow:1 column:0];
	[workingDir setStringValue:[Preferences stringForKey:initialWorkingDirectoryKey withDefault:@"~"]];
	
	flag = [Preferences flagForKey:importOnStartupKey withDefault:YES];
	[importOnStartup setState: flag?NSOnState:NSOffState];

	[rAppHistoryFileNamePath setStringValue:[Preferences stringForKey:rAppHistoryFileNamePathKey withDefault:[[Preferences stringForKey:initialWorkingDirectoryKey withDefault:@"~"] stringByAppendingString:@"/Rhistory.history"]]];
	
	[historyFileNamePath setStringValue:[Preferences stringForKey:historyFileNamePathKey withDefault:@"~/.Rhistory"]];	
}

- (IBAction) changeEditOrSource:(id)sender {
	BOOL flag;
	int res = (int)[sender selectedRow];
	if (res)
		flag = NO;
	else
		flag = YES;
	[Preferences setKey:editOrSourceKey withFlag:flag];
}

- (IBAction) changeLibPaths:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:miscRAquaLibPathKey withFlag:flag];
}

- (IBAction) changeWorkingDir:(id)sender {
	NSString *name = ([[sender stringValue] length] == 0)?@"~":[sender stringValue];
	[Preferences setKey:initialWorkingDirectoryKey withObject:name];
}

- (IBAction) chooseWorkingDir:(id)sender {
	NSOpenPanel *op;
	int answer;
	
	op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setTitle:NLS(@"Choose Initial Working Directory")];
	
	answer = [op runModalForDirectory:[workingDir stringValue] file:nil types:[NSArray arrayWithObject:@""]];
	
	if(answer == NSOKButton && [op directory] != nil)
		[Preferences setKey:initialWorkingDirectoryKey withObject:[[op directory] stringByAbbreviatingWithTildeInPath]];
}

- (IBAction) changeImportOnStartup:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:importOnStartupKey withFlag:flag];
}

- (IBAction) changeRAppHistoryFileNamePathToDefault: (id)sender {
	[Preferences setKey:rAppHistoryFileNamePathKey withObject:[[Preferences stringForKey:initialWorkingDirectoryKey withDefault:@"~"] stringByAppendingString:@"/Rhistory.history"]];
}

- (IBAction) changeHistoryFileNamePathToDefault: (id)sender {
	[Preferences setKey:historyFileNamePathKey withObject:@"~/.Rhistory"];	
}

- (IBAction) changeRAppHistoryFileNamePath:(id)sender {
	NSString *name = ([[sender stringValue] length] == 0)?@"~/.Rhistory":[sender stringValue];
	[Preferences setKey:rAppHistoryFileNamePathKey withObject:[name stringByAbbreviatingWithTildeInPath]];
}

- (IBAction) changeHistoryFileNamePath:(id)sender {
	NSString *name = ([[sender stringValue] length] == 0)?[Preferences stringForKey:rAppHistoryFileNamePathKey withDefault:[[Preferences stringForKey:initialWorkingDirectoryKey withDefault:@"~"] stringByAppendingString:@"/Rhistory.history"]]:[sender stringValue];
	[Preferences setKey:historyFileNamePathKey withObject:[name stringByAbbreviatingWithTildeInPath]];
}

@end
