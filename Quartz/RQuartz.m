//
//  RQuartz.m
//  Quartz graphics device
//
//  Created by stefano iacus on Sat Aug 14 2004.
//

#import "RQuartz.h"
#import "RController.h"
#import "RDeviceView.h"
#import "REngine.h"

#include <Defn.h>
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

- (BOOL)windowShouldClose:(id)sender{
	KillDevice(GetDevice([deviceView getDevNum]));
	return YES;
}



- (id)init
{
    self = [super init];
    return self;
}

- (void) dealloc {
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
}



- (void)deminiaturize:(id)sender
{
	//NSLog(@"dem:%d",sender);
}


+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title{

		NSEnumerator *e = [[document windowControllers] objectEnumerator];
		NSWindowController *wc = nil;
		
		while (wc = [e nextObject]) {
			NSWindow *window = [wc window];
			[window setTitle: title];
		}
}

/* This method is only invoked from the GUI to activate the device 
with CMD+SHIFT+A and essentially called in RController -> activateQuartzDevice
*/
- (void)activateDev{
	selectDevice([deviceView getDevNum]);
}


/* this function return the "kind" of document, not just the type which is "pdf
for quartz. This method is called by RController -> activateQuartz
*/
- (NSString *)whoAmI{
	return @"quartz";
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
	[printInfo setHorizontalPagination: NSAutoPagination];
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

- (IBAction)saveDocument:(id)sender
{
	int answer;
	NSSavePanel *sp;
	sp = [NSSavePanel savePanel];
	[sp setRequiredFileType:@"pdf"];
	[sp setTitle:@"Save Content of Quartz Device to PDF file"];
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
		NSRect r = [deviceView bounds];
		RSEXP *x = [[REngine mainEngine] evaluateString:
			[NSString stringWithFormat:@"dev.copy(device=pdf,file=\"%@\",width=%f,height=%f,version=\"1.4\")",
				[sp filename], r.size.width/72, r.size.height/72]
			];
		if(x)
			[[REngine mainEngine] executeString:@"dev.off()"];

	}
	
}

- (IBAction)copy:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes: [NSArray arrayWithObjects:NSTIFFPboardType, NSPDFPboardType, nil ] owner:self];

	QUARTZ_WORK_BEGIN;
	[deviceView lockFocus];
	NSBitmapImageRep* bitmap = [ [NSBitmapImageRep alloc]
			initWithFocusedViewRect: [deviceView bounds] ];
	[deviceView unlockFocus];

	NSData* data1 = [bitmap TIFFRepresentation];
	[pb setData: data1 forType:NSTIFFPboardType];
	[bitmap release];

	[deviceView setPDFDrawing:YES];
	[deviceView lockFocus];
	[deviceView writePDFInsideRect:[deviceView bounds] toPasteboard:pb];
	[deviceView unlockFocus];
	[deviceView setPDFDrawing:NO];

	QUARTZ_WORK_END;
}

@end

