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
#import "RController.h"
#import "Authorization.h"

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
	if (!mainView && [NSBundle loadNibNamed:@"EditorPrefPane" owner:self]);
	return mainView;
}

// AMPrefPaneInformalProtocol

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

/* end of std methods implementation */

- (IBAction) changeEditor:(id)sender;
{
	int answer;
	NSOpenPanel *sp;
	sp = [NSOpenPanel openPanel];
	[sp setTitle:@"Select editor application"];
	answer = [sp runModalForDirectory:@"/Applications" file:nil types:nil];
	if(answer == NSOKButton) {
		NSArray *pathComps = [[sp filename] componentsSeparatedByString:@"/"];
		NSString *name = [pathComps objectAtIndex: ([pathComps count] - 1)];
		pathComps = [name componentsSeparatedByString:@".app"];
		name = [pathComps objectAtIndex:0];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject: name] 
												  forKey:externalEditorNameKey];
		[self setExternalEditor:name];
	}
}

- (IBAction) changeInternalOrExternal:(id)sender
{
	BOOL flag = (int)[sender selectCellAtRow:0 column:0];
	if (flag==0 || flag==1)
	{
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:flag?@"YES":@"NO"]
												  forKey:internalOrExternalKey];
		[self setUseInternalEditor:flag?YES:NO];
	}
}

- (NSMatrix *) internalOrExternal;
{
	return internalOrExternal;
}

- (void) setUseInternalEditor:(BOOL)flag 
{
	if (!(flag==0 || flag==1)) return;
//	NSLog(@"setUseExternalEditor %d", flag);
	[internalOrExternal setState:(flag?NSOnState:NSOffState) atRow:0 column:0];
	[internalOrExternal setState:(flag?NSOffState:NSOnState) atRow:0 column:1];
	[externalSettings setHidden:flag?NSOnState:NSOffState]; 
	[builtInPrefs setHidden:flag?NSOffState:NSOnState];
	[[RController getRController] setUseInternalEditor: flag];
}

- (void)changeExternalEditorName:(id)sender {
	NSString *name = ([[sender stringValue] length] == 0)?@"TextEdit":[sender stringValue];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject: name] 
											  forKey:externalEditorNameKey];
	[self setExternalEditor:name];
}

- (NSTextField *) externalEditorName;
{
	return externalEditorName;
}

- (void)setExternalEditor:(NSString *)name {
//	NSLog(@"setExternalEditor %@", name);
	if (!name) name=@"";
	[externalEditorName setStringValue: name];
	[[RController getRController] setExternalEditor:name];
}

- (IBAction) changeShowSyntaxColoring:(id)sender {
	int flag = [sender state];
	if (!(flag==0 || flag==1)) return;
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:flag?@"YES":@"NO"]
											  forKey:showSyntaxColoringKey];
    [self setDoSyntaxColoring:flag];
}

- (NSButton *) showSyntaxColoring;
{
	return showSyntaxColoring;
}

- (void) setDoSyntaxColoring:(BOOL)flag {
	if (!(flag==0 || flag==1)) return;
	[showSyntaxColoring setState:flag?NSOnState:NSOffState];
	[[RController getRController] setDoSyntaxColoring: flag];
}

- (IBAction) changeShowBraceHighlighting:(id)sender {
	int flag = [sender state];
	if (!(flag==0 || flag==1)) return;
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:flag?@"YES":@"NO"]
											  forKey:showBraceHighlightingKey];
    [self setDoBraceHighlighting:[sender state]];
}

- (NSButton *) showBraceHighlighting;
{
	return showBraceHighlighting;
}

- (void) setDoBraceHighlighting:(BOOL)flag {
	if (!(flag==0 || flag==1)) return;
	[showBraceHighlighting setState:flag?NSOnState:NSOffState];
	[[RController getRController] setDoBraceHighlighting: flag];
}

- (IBAction) changeHighlightInterval:(id)sender {
	NSString *interval = [sender stringValue];
	if ([[sender stringValue] length] == 0) {
		interval = @"0.2";
	} else {
		double value = [[sender stringValue] doubleValue];
		if (value < 0.1)
			interval = @"0.1";
		else if (value > 0.8)
			interval = @"0.8";
	}
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:interval] 
											  forKey:highlightIntervalKey];
	[self setCurrentHighlightInterval:interval];
}

- (NSTextField *) highlightInterval;
{
	return highlightInterval;
}

- (void) setCurrentHighlightInterval:(NSString *)aString {
	[highlightInterval setStringValue:aString];
	[[RController getRController] setCurrentHighlightInterval:aString]; 
}

- (IBAction) changeShowLineNumbers:(id)sender {
	int flag = [sender state];
	if (!(flag==0 || flag==1)) return;
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:flag?@"YES":@"NO"]
											  forKey:showLineNumbersKey];
    [self setDoLineNumbers:flag];
}

- (NSButton *) showLineNumbers;
{
	return showLineNumbers;
}

- (void) setDoLineNumbers:(BOOL)flag {
	if (!(flag==0 || flag==1)) return;
	[showLineNumbers setState:flag?NSOnState:NSOffState];
	[[RController getRController] setDoLineNumbers: flag];
}

- (IBAction) changeAppOrCommand:(id)sender {
	BOOL flag = (int)[sender selectCellAtRow:0 column:0];
	if (!(flag==0 || flag==1)) return;
	if (flag==0 || flag==1)
	{
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:flag?@"YES":@"NO"]
												  forKey:appOrCommandKey];
		[self setEditorIsApp:flag?YES:NO];
	}
}

- (NSMatrix *) appOrCommand;
{
	return appOrCommand;
}

- (void) setEditorIsApp:(BOOL)flag {
	if (!(flag==0 || flag==1)) return;
	[appOrCommand setState:flag?NSOffState:NSOnState atRow:1 column:0];
	[appOrCommand setState:flag?NSOnState:NSOffState atRow:0 column:0];
	[[RController getRController] setEditorIsApp: flag];
}

@end
