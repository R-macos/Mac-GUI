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

#import "RGUI.h"
#import "SearchTable.h"
#import "RController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

static id sharedHSController;

@implementation SearchTable

- (id)init
{
    self = [super init];
    if (self) {
		sharedHSController = self;
		windowTitle = nil;
		dataSource = [[SortableDataSource alloc] init];
    }
	
    return self;
}

- (void) awakeFromNib
{
	[topicsDataSource setTarget: self];
	[topicsDataSource setDataSource: dataSource];
}

- (void)dealloc {
	[super dealloc];
}

- (void) updateHelpSearch: (int) count withTopics: (char**) topics packages: (char**) pkgs descriptions: (char**) descs urls: (char**) urls title: (char*) title
{
	[dataSource reset];
	[dataSource addColumnOfLength:count withCStrings:topics name:@"topic"];
	[dataSource addColumnOfLength:count withCStrings:pkgs name:@"package"];
	[dataSource addColumnOfLength:count withCStrings:descs name:@"description"];
	[dataSource addColumnOfLength:count withCStrings:urls name:@"URL"];
	if (windowTitle) [windowTitle release];
	windowTitle = [[NSString alloc] initWithCString: title];
	[self show];
}

- (int) count
{
	return [dataSource count];
}

- (void) show
{
	[self reloadData];
	[searchTableWindow setTitle:(windowTitle)?windowTitle:NLS(@"<unknown>")];
	[searchTableWindow makeKeyAndOrderFront:self];
}

- (IBAction) showInfo:(id)sender
{
	int row = [sender selectedRow];
	if(row < 0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[dataSource objectAtColumn:@"URL" row:row]];
	[[TopicHelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}


- (id) window
{
	return searchTableWindow;
}

+ (id) sharedController{
	return sharedHSController;
}

- (void) reloadData
{
	[topicsDataSource reloadData];
}

@end
