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

#import "../RGUI.h"
#import "RQuartz.h"
#import "../RController.h"
#import "../RDocumentController.h"
#import "RDeviceView.h"
#import "../REngine/REngine.h"

#include <Graphics.h>
#include <Rdevices.h>

// we'll need to clarify if any special action is necessary ...
// the point is that we're not actually using R, so it makes no sense to inform the R handler
#define QUARTZ_WORK_BEGIN
#define QUARTZ_WORK_END

@implementation RQuartz

- (RDeviceView *)getDeviceView{
	return deviceView;
}

- (NSWindow *)getDeviceWindow{
	return deviceWindow;
}

- (NSTextView *)textView {
	return nil;
}

- (void)close {
	SLog(@"RQuartz.close <%@>", self);
	NSArray *a = [self windowControllers];
	if (a && [a count]>0) {
		NSWindow *w = [(NSWindowController*)[a objectAtIndex:0] window];
		SLog(@" - window: %@", w);
		// --- something is broken - winctrl close doesn't work - I have no idea why - this is a horrible hack to cover up
		//if (w) [NSApp removeWindowsItem: w];
		//[[(RDocumentController*)[NSDocumentController sharedDocumentController] walkKeyListBack] makeKeyAndOrderFront:self];
		// --- end of hack
	}
	[super close];
}


- (BOOL)windowShouldClose:(id)sender{
	KillDevice(GetDevice([deviceView getDevNum]));
	return YES;
}

- (id)init
{
    self = [super init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:deviceWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidDeminiaturize:) name:NSWindowDidDeminiaturizeNotification object:deviceWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidUnhide:) name:NSApplicationDidUnhideNotification object:deviceWindow];
    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (NSString *)windowNibName
{
	return @"RQuartz";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	[deviceWindow setInitialFirstResponder: deviceView]; 
	[deviceWindow setDelegate:self];
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame {
//	NSLog(@"windowWillUseStandardFrame called");
	return defaultFrame;
}

- (void)windowWillClose:(NSNotification *)aNotification {
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
}


- (void)windowDidResize:(NSNotification *)aNotification {
//	NSLog(@"windowDidResize called %@", aNotification);
//	NSLog(@"window %@", deviceWindow);
	if ([aNotification object] == deviceWindow) {
		[deviceView setPDFDrawing:YES];
		[deviceView drawRect:[deviceView frame]];		
	}
}

- (void)windowDidDeminiaturize:(NSNotification *)aNotification {
//	NSLog(@"windowDidDeminiaturize called");
	if ([aNotification object] == deviceWindow) {
		[deviceView setPDFDrawing:YES];
		[deviceView drawRect:[deviceView frame]];		
	}
}

- (void)applicationDidUnhide:(NSNotification *)aNotification {
	//	NSLog(@"applicationDidUnhide called");
	[deviceView setPDFDrawing:YES];
	[deviceView drawRect:[deviceView frame]];		
}

- (void)deminiaturize:(id)sender
{
//	NSLog(@"dem:%d",sender);
}


+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title{

		NSEnumerator *e = [[document windowControllers] objectEnumerator];
		NSWindowController *wc = nil;
		if (!title || [title length]<1) title=NLS(@"New Quartz Device");
		while (wc = [e nextObject]) {
			NSWindow *window = [wc window];
			[window setTitle: title];
		}
}

/* This method is only invoked from the GUI to activate the device with CMD+SHIFT+A */
- (IBAction) activateQuartzDevice: (id) sender {
	selectDevice([deviceView getDevNum]);
}


- (BOOL) knowsPageRange: (NSRangePointer) range
{
    range->location = 1;
    range->length = 1;
	
    return YES;
}

- (NSRect ) rectForPage: (int) pageNumber
{
    NSPrintInfo *info = [NSPrintInfo sharedPrintInfo];
    return [info imageablePageBounds];
}

- (IBAction)printDocument:(id)sender
{
	NSPrintInfo *printInfo;
	NSPrintInfo *sharedInfo;
	NSPrintOperation *printOp;
	NSMutableDictionary *printInfoDict;
	NSMutableDictionary *sharedDict;
	
	sharedInfo = [NSPrintInfo sharedPrintInfo];
	sharedDict = [sharedInfo dictionary];
	printInfoDict = [NSMutableDictionary dictionaryWithDictionary:
		sharedDict];

	printInfo = [[NSPrintInfo alloc] initWithDictionary: printInfoDict];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	QUARTZ_WORK_BEGIN;
	[deviceView setPDFDrawing:YES];
	printOp = [NSPrintOperation printOperationWithView:deviceView 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
	[deviceView setPDFDrawing:NO];
	QUARTZ_WORK_END;
}

- (IBAction)saveDocumentAs:(id)sender
{
	[self saveDocument:sender];
}

- (IBAction)saveDocument:(id)sender
{
	int answer;
	NSSavePanel *sp;
	sp = [NSSavePanel savePanel];
	[sp setRequiredFileType:@"pdf"]; // this is not really the type - it's the extension
	[sp setTitle:NLS(@"Save Content of Quartz Device to PDF file")];
	answer = [sp runModal];
	if(answer == NSOKButton) {
		/*  The following code should create a PDF file form the draw: method of deviceView
		unfortunately, lost of things are writting on the pdf file, even those pertaining
		to the sae panel, plus a flieed image of the same picture.
		
		[RController RGUI_RBusy:1];
		[deviceView setPDFDrawing:YES];
		NSData *data = [deviceView dataWithPDFInsideRect:[deviceView bounds]];
		[RController RGUI_RBusy:0];
		[data writeToFile:[sp filename] atomically:NO];		
		[deviceView setPDFDrawing:NO];
		*/		
		RSEXP *x = [[REngine mainEngine] evaluateString:
			[NSString stringWithFormat:@"dev.copy(device=pdf,file=\"%@\",width=par()$din[1],height=par()$din[2],version=\"1.4\")",
				[sp filename]]
			];
		if(x)
			[[REngine mainEngine] executeString:@"dev.off()"];

	}
//	[[[RController sharedController] getRConsoleWindow] makeKeyWindow];
}

- (void) setDeviceName: (NSString*) name
{
	deviceName = name;
}

- (NSString*) deviceName
{
	return deviceName;
}

- (IBAction)copy:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	// we use PDF as the primary type; owner should be nil, because we could get released (see NSPB docs for details)
	[pb declareTypes: [NSArray arrayWithObjects: NSPDFPboardType, NSTIFFPboardType, nil ] owner:nil];

	QUARTZ_WORK_BEGIN;

	[deviceView setPDFDrawing:YES];
	[deviceView lockFocus];
	[deviceView writePDFInsideRect:[deviceView bounds] toPasteboard:pb];
	[deviceView unlockFocus];
	[deviceView setPDFDrawing:NO];

	[deviceView lockFocus];
	NSBitmapImageRep* bitmap = [ [NSBitmapImageRep alloc]
			initWithFocusedViewRect: [deviceView bounds] ];
	[deviceView unlockFocus];
	
	NSData* data1 = [bitmap TIFFRepresentation];
	[pb setData: data1 forType:NSTIFFPboardType];
	[bitmap release];
	
	QUARTZ_WORK_END;
}

@end

