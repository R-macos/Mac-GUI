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

#import "PackageManager.h"
#import "RController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>
#import "REngine/REngine.h"

static PackageManager *sharedController = nil;

@implementation PackageManager

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		[packageDataSource setTarget: self];
		packages = 0;
		package = 0;
    }
	
    return self;
}

+ (PackageManager*) sharedController
{
	return sharedController;
}

- (void)dealloc {
	[self resetPackages];
	[super dealloc];
}

#pragma mark -
#pragma mark TableView delegates

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return packages;
}

- (id)tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)tableColumn row: (int)row
{
	if (row<packages) {
		if([[tableColumn identifier] isEqualToString:@"status"])
			return [NSNumber numberWithBool: package[row].status];
		else if([[tableColumn identifier] isEqualToString:@"package"])
			return package[row].name;
		else if([[tableColumn identifier] isEqualToString:@"description"])
			return package[row].desc;
	}
	return nil;
}

- (void)tableView:(NSTableView *)tableView
	setObjectValue:(id)object
	forTableColumn:(NSTableColumn *)tableColumn
	row:(int)row
{
	if (row>=packages) return;
	if([[tableColumn identifier] isEqualToString:@"status"]){
		if ([object boolValue] == NO) {
			if ([[REngine mainEngine] executeString:[NSString stringWithFormat:@"detach(\"package:%@\")",package[row].name]])
				package[row].status = NO;
		} else {
			if ([[REngine mainEngine] executeString:[NSString stringWithFormat:@"library(%@)",package[row].name]])
				package[row].status = YES;
		}
	} 
}

#pragma mark -
#pragma mark TableView notifications

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table
	if ([aNotification object] != packageDataSource) return;

	// Update Info delayed
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showInfo:) 
							object:packageDataSource];

	[self performSelector:@selector(showInfo:) withObject:packageDataSource afterDelay:0.5];
	
}

#pragma mark -

- (IBAction) showInfo:(id)sender
{
	int row = [sender selectedRow];
	if (row < 0) return;
#if R_VERSION < R_Version(2, 10, 0)
	NSString *urlText = [NSString stringWithFormat:@"file://%@",package[row].url];
#else
	NSString *urlText = nil;
	int port = [[RController sharedController] helpServerPort];
	if (port == 0) {
		NSRunInformationalAlertPanel(NLS(@"Cannot start HTML help server."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
		return;
	}
	urlText = [NSString stringWithFormat:@"http://127.0.0.1:%d/library/%@/html/00Index.html", port, package[row].name];
#endif
	SLog(@"PackageManager.showInfo: URL=%@", urlText);
	[[PackageInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}

- (id) window
{
	return PackageManagerWindow;
}

- (IBAction) reloadPMData:(id)sender
{
	[[REngine mainEngine] executeString:@"package.manager()"];
	[packageDataSource reloadData];
}

- (void) resetPackages
{
	if (!packages) return;
	int i=0;
	while (i<packages) {
		[package[i].name release];
		[package[i].desc release];
		[package[i].url release];
		i++;
	}
	free(package);
	packages=0;
}

- (void) updatePackages: (int) count withNames: (char**) name descriptions: (char**) desc URLs: (char**) url status: (BOOL*) stat;
{
	int i=0;
	
	if (packages) [self resetPackages];
	if (count<1) {
		[self show];
		return;
	}
	
	package = malloc(sizeof(*package)*count);
	while (i<count) {
		package[i].name=[[NSString alloc] initWithUTF8String: name[i]];
		package[i].desc=[[NSString alloc] initWithUTF8String: desc[i]];
		package[i].url=[[NSString alloc] initWithUTF8String: url[i]];
		package[i].status=stat[i];
		i++;
	}
	packages = count;
	[self show];
}

- (int) count
{
	return packages;
}

- (void) show
{
	[packageDataSource reloadData];
	[[self window] makeKeyAndOrderFront:self];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	[backButton setEnabled:[sender canGoBack]];
	[forwardButton setEnabled:[sender canGoForward]];
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	[PackageManagerWindow makeKeyAndOrderFront:nil];
}

- (IBAction)printDocument:(id)sender
{

	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showInfo:) 
							object:packageDataSource];

	NSPrintInfo *printInfo;
	NSPrintOperation *printOp;
	
	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:[[[PackageInfoView mainFrame] frameView] documentView] 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
}

@end
