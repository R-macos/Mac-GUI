#import "RDeviceView.h"
#import "RQuartz.h"
#import "RController.h"

#include <Defn.h>

#include <R.h>
#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <Rdefines.h>
#include <Rinternals.h>

#include <R_ext/Parse.h>

#include <Graphics.h>
#include <Rdevices.h>

extern void RQuartz_DiplayGList(RDeviceView * devView);

#define POOL NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]
@implementation RDeviceView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
		devTextStorage = [[NSTextStorage alloc] initWithString:@"text"];
		devLayoutManager = [[NSLayoutManager alloc] init];
		devTextContainer = [[NSTextContainer alloc] init];
		[devLayoutManager addTextContainer:devTextContainer];
		[devTextStorage addLayoutManager:devLayoutManager];
	}
	return self;
}

- (void) setPDFDrawing: (BOOL)flag
{
	PDFDrawing = flag;
}
- (BOOL) isPDFDrawing
{
	return PDFDrawing;
}

- (void) setDevNum: (int)dnum
{
	deviceNum = dnum;
}

- (int) getDevNum
{
	return deviceNum;
}

- (BOOL)isFlipped { return YES; }


- (void) dealloc
{
	[devLayoutManager release];
	[devTextStorage release];
	[devTextContainer release];
	[super dealloc];
}



static void drawStringInRect(NSRect rect, NSString *str, int fontSize)
{
    NSDictionary *dict = [NSDictionary
                          dictionaryWithObject: [NSFont boldSystemFontOfSize: fontSize]
                                        forKey: NSFontAttributeName];
    NSAttributedString *astr = [[NSAttributedString alloc]
                                initWithString: str
                                    attributes: dict];
    NSSize strSize = [astr size];
    NSPoint pt = NSMakePoint((rect.size.width - strSize.width) / 2,
                             (rect.size.height - strSize.height) / 2);

    // clear the rect
    rect.origin.x = 0;
    rect.origin.y = 0;
    [[NSColor whiteColor] set];
    NSRectFill(rect);

    // draw the string
    [astr drawAtPoint:pt];

    [astr release];
}

/*	FIXME: zoom, minimize don't work. With grid, it waits for event before rewriting, it
	essentialy blocks R
*/	
- (void)viewDidEndLiveResize
{
    [super viewDidEndLiveResize];
	[[RController getRController] handleBusy: YES];
	[self lockFocus];
 	RQuartz_DiplayGList(self);
	[deviceWindow flushWindow];
	[self unlockFocus];
	[[RController getRController] handleBusy: NO];

    // could do something here if needed
}

- (void)drawRect:(NSRect)aRect
{
    NSRect		frame = [self frame];
 
    if ([self inLiveResize])
    {
        NSString *str = [NSString stringWithFormat: @"Resizing to %g x %g",
                                                    frame.size.width, frame.size.height];
        drawStringInRect(frame, str, 20);
        return;
    }
	
	if(PDFDrawing){
		RQuartz_DiplayGList(self);
		PDFDrawing = NO;
	}
}

- (NSTextStorage *)getDevTextStorage
{
	return devTextStorage;
}

- (NSLayoutManager *)getDevLayoutManager
{
	return devLayoutManager;
}

- (NSTextContainer *)getDevTextContainer
{
	return devTextContainer;
}


 @end

