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

#import "SearchTable.h"
#import "RController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

extern int NumOfMatches;
extern char **hs_topic; 
extern char **hs_pkg;
extern char **hs_desc;
extern char **hs_url;


static id sharedHSController;

@implementation SearchTable

- (id)init
{

    self = [super init];
    if (self) {
		sharedHSController = self;
		// Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		    [topicsDataSource setTarget: self];

    }
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return NumOfMatches;
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
		row: (int)row
{
			if([[tableColumn identifier] isEqualToString:@"topic"])
					return [NSString stringWithCString:hs_topic[row]];
			else if([[tableColumn identifier] isEqualToString:@"package"])
					return [NSString stringWithCString:hs_pkg[row]];
			else if([[tableColumn identifier] isEqualToString:@"description"])
					return [NSString stringWithCString:hs_desc[row]];
			else return nil;
				
}



- (IBAction) showInfo:(id)sender
{
	int row = [sender selectedRow];
	if(row < 0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[NSString stringWithCString:hs_url[row]]];
	[[TopicHelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}


- (id) window
{
	return searchTableWindow;
}

+ (id) getHSController{
	return sharedHSController;
}


- (void) doReloadData
{
	[topicsDataSource reloadData];
}

+ (void) reloadData
{
	[[SearchTable getHSController] doReloadData];
	
}

+ (void) toggleHSBrowser:(NSString *)winTitle
{
			[SearchTable reloadData];
			[[[SearchTable getHSController] window] setTitle:winTitle];
			[[[SearchTable getHSController] window] orderFront:self];
}

@end
