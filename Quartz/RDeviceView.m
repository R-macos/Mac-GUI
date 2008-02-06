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
#import "RDeviceView.h"
#import "RQuartz.h"
#import "../RController.h"

#include <R.h>
#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <Rdefines.h>
#include <Rinternals.h>

#include <R_ext/Parse.h>

#include <Graphics.h>
#include <Rdevices.h>

extern void RQuartz_DiplayGList(RDeviceView * devView);

@implementation RDeviceView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
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

/* override lockFocus behavior by de-miniaturizing the window if necessary */
- (void) lockFocus
{
	if (![self canDraw]) {
		NSWindow *window = [self window];
		if (window && [window isMiniaturized])
			[window deminiaturize:self];
		if (![self canDraw]) {
			SLog(@"RDevieView.lockFocus: cannot draw despite window wakeup attempt (%@), cannot lock", window);
			return;
		}
	}
	[super lockFocus];
}

/*	FIXME: zoom, minimize don't work. With grid, it waits for event before rewriting, it
	essentialy blocks R
*/	
- (void)viewDidEndLiveResize
{
    [super viewDidEndLiveResize];
	[[RController sharedController] handleBusy: YES];
	[self lockFocus];
 	RQuartz_DiplayGList(self);
	[deviceWindow flushWindow];
	[self unlockFocus];
	[[RController sharedController] handleBusy: NO];
}

- (void)drawRect:(NSRect)aRect
{
    NSRect		frame = [self frame];
 
    if ([self inLiveResize])
    {
		[self lockFocus];
        NSString *str = [NSString stringWithFormat: NLS(@"Resizing to %g x %g"),
                                                    frame.size.width, frame.size.height];
        drawStringInRect(frame, str, 20);
		[self unlockFocus];
        return;
    }
	
	if (PDFDrawing) {
		RQuartz_DiplayGList(self);
		PDFDrawing = NO;
	}
}

- (void) saveAsBitmap: (NSString*) fname usingType: (NSBitmapImageFileType) ftype {
	[self lockFocus];
	NSBitmapImageRep* bitmap = [ [NSBitmapImageRep alloc]
			initWithFocusedViewRect: [self bounds] ];
	[self unlockFocus];
	
	NSData* data1 = [bitmap representationUsingType:ftype properties:nil];
	[[NSFileManager defaultManager] createFileAtPath:fname contents:data1 attributes:nil];
	
	[bitmap release];	
}

- (void) saveAsPDF: (NSString*) fname {
	[self setPDFDrawing:YES];
	[self lockFocus];
	NSData *data = [self dataWithPDFInsideRect:[self bounds]];
	[self unlockFocus];
	[self setPDFDrawing:NO];
	
	[data writeToFile:fname atomically:YES];
}

@end
