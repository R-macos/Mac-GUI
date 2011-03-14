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
	[dataInfoView setFrameLoadDelegate:self];
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
	[dataSource addColumnOfLength:count withUTF8Strings:name name:@"data"];
	[dataSource addColumnOfLength:count withUTF8Strings:desc name:@"description"];
	[dataSource addColumnOfLength:count withUTF8Strings:pkg name:@"package"];
	[dataSource addColumnOfLength:count withUTF8Strings:url name:@"URL"];
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
	if (row < 0) return;
	SLog(@"DataManager showHelp: (data=%@, package=%@, static-URL=%@)", [dataSource objectAtColumn:@"data" row:row], [dataSource objectAtColumn:@"package" row:row], [dataSource objectAtColumn:@"URL" row:row]);
#if R_VERSION < R_Version(2, 10, 0)
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[dataSource objectAtColumn:@"URL" row:row]];
#else
	NSString *urlText = nil;
	int port = [[RController sharedController] helpServerPort];
	if (port == 0) {
		NSRunInformationalAlertPanel(NLS(@"Cannot start HTML help server."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
		return;
	}
	NSString *topic = [dataSource objectAtColumn:@"data" row:row];
	NSRange r = [topic rangeOfString:@" ("];
	if (r.length > 0 && [topic length] - r.length > 3) // some datasets have the topic in parents
		topic = [topic substringWithRange: NSMakeRange(r.location + 2, [topic length] - r.location - 3)];
	urlText = [NSString stringWithFormat:@"http://127.0.0.1:%d/library/%@/html/%@.html", port, [dataSource objectAtColumn:@"package" row:row], topic];
#endif
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

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table
	if ([aNotification object] != RDataSource) return;

	// Update Info delayed
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showHelp:) 
							object:RDataSource];

	[self performSelector:@selector(showHelp:) withObject:RDataSource afterDelay:0.5];
	
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	[DataManagerWindow makeKeyAndOrderFront:nil];
}

- (IBAction)printDocument:(id)sender
{

	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showHelp:) 
							object:RDataSource];

	NSPrintInfo *printInfo;
	NSPrintOperation *printOp;
	
	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:[[[dataInfoView mainFrame] frameView] documentView] 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
}

@end
