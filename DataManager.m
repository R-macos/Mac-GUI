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

#import "DataManager.h"
#import "RController.h"
#import "REngine/REngine.h"

#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

static id sharedController;

@implementation DataManager

- (void)awakeFromNib
{
	[RDataSource setDoubleAction:@selector(loadRData:)];
	[RDataSource setDataSource: dataSource];
}

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		dataSource = [[SortableDataSource alloc] init];
	}
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

- (void) resetDatasets
{
	[dataSource reset];
}

- (void) updateDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url
{
	[dataSource reset];
	[dataSource addColumnOfLength:count withCStrings:name name:@"data"];
	[dataSource addColumnOfLength:count withCStrings:desc name:@"description"];
	[dataSource addColumnOfLength:count withCStrings:pkg name:@"package"];
	[dataSource addColumnOfLength:count withCStrings:url name:@"URL"];
	[self show];
}

- (id) window
{
	return DataManagerWindow;
}

+ (DataManager*) sharedController{
	return sharedController;
}

- (void) reloadData
{
	[RDataSource reloadData];
}

- (IBAction)loadRData:(id)sender
{
	int row = [sender selectedRow];
	if(row>=0)
		[[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"data(%@,package=\"%@\")",
			[dataSource objectAtColumn:@"data" row:row], [dataSource objectAtColumn:@"package" row:row]]];
}

- (IBAction)showHelp:(id)sender
{
	int row = [sender selectedRow];
	if(row<0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[dataSource objectAtColumn:@"URL" row:row]];
	[[dataInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}

- (int) count
{
	return [dataSource count];
}

- (void) show
{
	[self reloadData];
	[DataManagerWindow makeKeyAndOrderFront:self];
}

@end
