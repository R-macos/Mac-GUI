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
 *  REditorToolbar.h
 *  Toolbar for the integrated document editor
 *
 *  Created by Simon Urbanek on 4/1/05.
 */

#import "RGUI.h"
#import "REditorToolbar.h"
#import "RDocumentWinCtrl.h"

@implementation REditorToolbar

- initWithEditor: (RDocumentWinCtrl *)dwCtrl
{
	self = [super init];
	if (self) {
		winCtrl = dwCtrl;
		toolbar = [[[NSToolbar alloc] initWithIdentifier: @"REditorToolbar"] autorelease];

		[toolbar setAllowsUserCustomization: YES];
		[toolbar setAutosavesConfiguration: YES];
		[toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
		
		// We are the delegate
		[toolbar setDelegate: self];
		
		// Attach the toolbar to the document window 
		[[winCtrl window] setToolbar: toolbar];		
	}
	return self;
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    
    if ([itemIdent isEqual: RETI_Save]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"Save")];
		[toolbarItem setPaletteLabel: NLS(@"Save")];
		[toolbarItem setToolTip: NLS(@"Save current document")];
		[toolbarItem setImage: [NSImage imageNamed: @"SaveDocumentItemImage"]];
		[toolbarItem setTarget: [winCtrl document]];
		[toolbarItem setAction: @selector(saveDocument:)];
	} else if ([itemIdent isEqual: RETI_HelpSearch]) { /* help search filed - view item */
		NSView *myView = [winCtrl searchToolbarView];
		// Set up the standard properties 
		[toolbarItem setLabel:@"Search"];
		[toolbarItem setPaletteLabel:@"Search"];
		[toolbarItem setToolTip:@"Search Help"];
		// Use a custom view, a rounded text field, attached to searchFieldOutlet in InterfaceBuilder as the custom view 
		[toolbarItem setView:myView];
		[toolbarItem setMinSize:NSMakeSize(100,NSHeight([myView frame]))];
		[toolbarItem setMaxSize:NSMakeSize(300,NSHeight([myView frame]))];
		// Create the custom menu (alternative if icons are disabled)
		NSMenu *submenu=[[[NSMenu alloc] init] autorelease];
		NSMenuItem *submenuItem=[[[NSMenuItem alloc] initWithTitle: @"Search Panel"
															action: @selector(searchUsingSearchPanel:)
													 keyEquivalent: @""] autorelease];
		NSMenuItem *menuFormRep=[[[NSMenuItem alloc] init] autorelease];
		[submenu addItem: submenuItem];
		[submenuItem setTarget:self];
		[menuFormRep setSubmenu:submenu];
		[menuFormRep setTitle:[toolbarItem label]];
		[toolbarItem setMenuFormRepresentation:menuFormRep];
	} else if ([itemIdent isEqual: RETI_FnList]) { /* function list - view item */
		NSView *myView = [winCtrl fnListView];
		[toolbarItem setLabel:@"Functions"];
		[toolbarItem setPaletteLabel:@"Functions"];
		[toolbarItem setToolTip:@"List of Functions"];
		[toolbarItem setView:myView];
		[toolbarItem setMinSize:NSMakeSize(100,NSHeight([myView frame]))];
		[toolbarItem setMaxSize:NSMakeSize(200,NSHeight([myView frame]))];
	} else
		toolbarItem = nil;

	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects: RET_ListDefault, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects: RET_ListAll, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place 
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being 
    // added is found by referencing the @"item" key in the userInfo 
    // NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
    //if ([[addedItem itemIdentifier] isEqual: ...]) {
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
    // the chance to tear down information related to the item that may have been cached.   The notification object
    // is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
    // key in the userInfo 
	// NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
	NSString *iid = [toolbarItem itemIdentifier];
    BOOL enable = YES; // default is YES, if there are any that need to be disabled - check for them
    
	if ([iid isEqual: RETI_Save ])
		enable = [[winCtrl document] isDocumentEdited];
	
    return enable;
}

@end
