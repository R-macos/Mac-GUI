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

/* QuartzDevice.m */

#import "../RGUI.h"
#import "../REngine/RSEXP.h"
#import "../REngine/REngine.h"

/* we need this to register QuartzSaveContents */
#include "privateR.h"
#include <Rdynpriv.h>

#include <Rversion.h>
#include <R.h>
#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <Rdefines.h>
#include <Rinternals.h>

#include <R_ext/Parse.h>

#import "../RController.h"
#import "RQuartz.h"
#import "RDeviceView.h"
#import "QuartzDevice.h"
#import "Preferences.h"

#include <Graphics.h>
#include <Rdevices.h>

/* since 2.1.0 devQuartz is no longer in libR, so we need to duplicate it here */
#if (R_VERSION >= R_Version(2,1,0))
extern char*  RGUI_Quartz_TranslateFontFamily(char* family, int face, char *devfamily);
#define Quartz_TranslateFontFamily RGUI_Quartz_TranslateFontFamily
#else
extern  char* Quartz_TranslateFontFamily(char* family, int face, char *devfamily); /* from src/unix/devQuartz.c */
#endif
	 
NSRect ClipArea;



   /***************************************************************************/
   /* Each driver can have its own device-specic graphical                    */
   /* parameters and resources.  these should be wrapped                      */
   /* in a structure (like the x11Desc structure below)                       */
   /* and attached to the overall device description via                      */
   /* the dd->deviceSpecific pointer                                          */
   /* NOTE that there are generic graphical parameters                        */
   /* which must be set by the device driver, but are                         */
   /* common to all device types (see Graphics.h)                             */
   /* so go in the GPar structure rather than this device-                    */
   /* specific structure                                                      */
   /***************************************************************************/

typedef struct {
    int cex;
    int windowWidth;
    int windowHeight;
    Boolean resize;
    int Text_Font;          /* 0 is system font and 4 is monaco */
    int fontface;           /* Typeface */
    int fontsize;           /* Size in points */
    int usefixed;
    int color;		        /* color */
	int bg;					/* bg color */
    int fill;	        	/* fill color */
    WindowPtr window;
    int	lineType;
    int lineWidth;
    Boolean Antialias;		/* Use Antialiasing */
    Boolean Autorefresh;
    char	*family;
    CGContextRef context;     /* This is the context used by Quartz for OnScreen drawings */
    CGContextRef auxcontext;  /* Additional context used for: cliboard, printer, file     */
    double	xscale;
    double	yscale;
	int		DevNum;
    int		where;
	int		QuartzPos;		 /* Window Pos: TopRight=1, BottomRight, BottomLeft, TopLeft=4 */
	RQuartz *QuartzDoc;
	NSPoint topLeftPoint;
	RDeviceView *DevView;
	NSWindow *DevWindow;
	NSTextStorage *DevTextStorage;
	NSLayoutManager *DevLayoutManager;
	NSTextContainer *DevTextContainer;	
}
QuartzDesc;

// Quartz - private autorelease pool
// Note: this is experimental and currently unsafe, because Quartz can
//       be called asynchronously from withing the event processing
#ifdef QPOOL
NSAutoreleasePool *quartzPool = nil;
#endif

Rboolean innerQuartzDevice(NewDevDesc *dd,char *display,
						   double width,double height,
						   double pointsize,char *family,
						   Rboolean antialias,
						   Rboolean autorefresh,int quartzpos,
						   int bg);

void getQuartzParameters(double *width, double *height, double *ps, char *family, 
						 Rboolean *antialias, Rboolean *autorefresh, int *quartzpos);


static Rboolean	RQuartz_Open(NewDevDesc *, QuartzDesc *, char *,double, double, int);
static void 	RQuartz_Close(NewDevDesc *dd);
static void 	RQuartz_Activate(NewDevDesc *dd);
static void 	RQuartz_Deactivate(NewDevDesc *dd);
static void 	RQuartz_Size(double *left, double *right,
		     	 double *bottom, double *top, NewDevDesc *dd);
static void 	RQuartz_NewPage(R_GE_gcontext *gc, NewDevDesc *dd);
static void 	RQuartz_Clip(double x0, double x1, double y0, double y1,
			    NewDevDesc *dd);
static double 	RQuartz_StrWidth(char *str, 
				R_GE_gcontext *gc,
				NewDevDesc *dd);
static void 	RQuartz_Text(double x, double y, char *str,
			    double rot, double hadj, 
			    R_GE_gcontext *gc,
			    NewDevDesc *dd);
static void 	RQuartz_Rect(double x0, double y0, double x1, double y1,
			    R_GE_gcontext *gc,
			    NewDevDesc *dd);
static void 	RQuartz_Circle(double x, double y, double r, 
			      R_GE_gcontext *gc,
			      NewDevDesc *dd);
static void 	RQuartz_Line(double x1, double y1, double x2, double y2,
			    R_GE_gcontext *gc,
			    NewDevDesc *dd);
static void 	RQuartz_Polyline(int n, double *x, double *y, 
				R_GE_gcontext *gc,
				NewDevDesc *dd);
static void 	RQuartz_Polygon(int n, double *x, double *y, 
			       R_GE_gcontext *gc,
			       NewDevDesc *dd);
static Rboolean RQuartz_Locator(double *x, double *y, NewDevDesc *dd);
static void 	RQuartz_Mode(int mode, NewDevDesc *dd);
static void 	RQuartz_Hold(NewDevDesc *dd);
static void 	RQuartz_MetricInfo(int c,
				  R_GE_gcontext *gc,
				  double* ascent, double* descent, 
				  double* width,
				  NewDevDesc *dd);


static void RQuartz_SetFill(int fill, double gamma,  NewDevDesc *dd);
static void RQuartz_SetStroke(int color, double gamma,  NewDevDesc *dd);
static void RQuartz_SetLineProperties(R_GE_gcontext *gc,  NSBezierPath *path, NewDevDesc *dd);
static void RQuartz_SetLineDash(int lty, double lwd,   NSBezierPath *path, NewDevDesc *dd);
static void RQuartz_SetLineWidth(double lwd,   NSBezierPath *path);
static void RQuartz_SetLineEnd(R_GE_lineend lend,   NSBezierPath *path);
static void RQuartz_SetLineJoin(R_GE_linejoin ljoin,    NSBezierPath *path);
static void RQuartz_SetLineMitre(double lmitre,   NSBezierPath *path);
NSFont *RQuartz_Font(R_GE_gcontext *gc,  NewDevDesc *dd);
NSPoint computeTopLeftCornerForDevNum(int devnum, int quartzpos, int width, int height);
			   
Rboolean innerQuartzDevice(NewDevDesc*dd,char*display,
						   double width,double height,
						   double pointsize,char*family,
						   Rboolean antialias,
						   Rboolean autorefresh,int quartzpos,
						   int bg)
{ 
//	NSLog(@"innerQuartzDevice called");
	BOOL flag=[Preferences flagForKey:useQuartzPrefPaneSettingsKey withDefault: NO];
	if (flag) {
		NSString *valw = [Preferences stringForKey:quartzPrefPaneWidthKey withDefault: @"4.5"];
		NSString *valh = [Preferences stringForKey:quartzPrefPaneHeightKey withDefault: @"4.5"];
		width = [valw doubleValue];
		height = [valh doubleValue];
	}
//	NSLog(@"quartzpos value: %d", quartzpos);
	quartzpos = [[Preferences stringForKey:quartzPrefPaneLocationIntKey withDefault:@"3"] intValue];
//	NSLog(@"Pref quartzpos value: %d", quartzpos);
    QuartzDesc *xd;
    int ps;

    if (!(xd = (QuartzDesc *)malloc(sizeof(QuartzDesc))))
		return 0;

    xd->QuartzPos = quartzpos; /* by default it is Top-Right */

    if(!RQuartz_Open(dd, xd, display, width, height, bg))
     return(FALSE);

  
    ps = pointsize;
    if (ps < 6 || ps > 24) ps = 10;
    ps = 2 * (ps / 2);
    dd->startps = ps;
    dd->startfont = 1;
    dd->startlty = LTY_SOLID;
    dd->startgamma = 1;

    dd->newDevStruct = 1;

    dd->open       = RQuartz_Open;
    dd->close      = RQuartz_Close;
    dd->activate   = RQuartz_Activate;
    dd->deactivate = RQuartz_Deactivate;
    dd->size       = RQuartz_Size;
    dd->newPage    = RQuartz_NewPage;
    dd->clip       = RQuartz_Clip;
    dd->strWidth   = RQuartz_StrWidth;
    dd->text       = RQuartz_Text;
    dd->rect       = RQuartz_Rect;
    dd->circle     = RQuartz_Circle;
    dd->line       = RQuartz_Line;
    dd->polyline   = RQuartz_Polyline;
    dd->polygon    = RQuartz_Polygon;
    dd->locator    = RQuartz_Locator;
    dd->mode       = RQuartz_Mode;
    dd->hold       = RQuartz_Hold;

    dd->metricInfo = RQuartz_MetricInfo;

    dd->left        = 0;
    dd->right       =  xd->windowWidth;
    dd->bottom      =  xd->windowHeight;
    dd->top         = 0;

    dd->xCharOffset = 0.4900;
    dd->yCharOffset = 0.3333;
    dd->yLineBias = 0.1;

    dd->cra[0] = ps / 2;
    dd->cra[1] = ps;

    dd->ipr[0] = 1.0 / 72;
    dd->ipr[1] = 1.0 / 72;

    dd->canResizePlot = TRUE;
    dd->canChangeFont = TRUE;
    dd->canRotateText = TRUE;
    dd->canResizeText = TRUE;
    dd->canClip       = TRUE;
    dd->canHAdj = 0;
    dd->canChangeGamma = FALSE;


    /* It is used to set the font that you will be used on the postscript and
       drawing.
    */

    /* There is the place for you to set the default value of the MAC Devices */
    xd->cex = 1.0;
    xd->resize = true;
    xd->Text_Font = 4; /* initial is monaco */
    xd->fontface = 0;  /* initial is plain text */
    xd->fontsize = 12; /* initial is 12 size */
    xd->Antialias = antialias; /* by default Antialias if on */
    xd->Autorefresh = autorefresh; /* by default it is on */

    if(family){
     xd->family = malloc(sizeof(family)+1);
     strcpy(xd->family,family);
    }
    else
     xd->family = NULL;

    xd->where  = kOnScreen;
    //err = SetCGContext(xd);

/* This scale factor is needed in MetricInfo */
    xd->xscale = width/72.0;
    xd->yscale = height/72.0;

    dd->deviceSpecific = (void *) xd;
    dd->displayListOn = TRUE;

	xd->DevView = [xd->QuartzDoc getDeviceView];
	xd->DevWindow = [xd->QuartzDoc getDeviceWindow];
	[xd->DevView setDevNum: xd->DevNum];
	[xd->DevView setPDFDrawing: FALSE];
	xd->topLeftPoint = NSMakePoint(0, 0);
    return 1;

}
						   
void getQuartzParameters(double *width, double *height, double *ps, char *family, 
						 Rboolean *antialias, Rboolean *autorefresh, int *quartzpos)
{
}

void RQuartz_DiplayGList(RDeviceView * devView);
void RQuartz_DiplayGList(RDeviceView * devView)
{
	NewDevDesc *dd;
	int devnum = [devView getDevNum];
	if( (dd = ((GEDevDesc*) GetDevice(devnum))->dev) ){
		QuartzDesc *xd = (QuartzDesc *) dd-> deviceSpecific;
			NSSize size = [devView bounds].size; 
			if( (xd->windowWidth != size.width) || (xd->windowHeight != size.height) || ([devView isPDFDrawing])){
				xd->resize = true;
                     dd->size(&(dd->left), &(dd->right), &(dd->bottom), &(dd->top), dd);
					 xd->resize = false;
                     GEplayDisplayList((GEDevDesc*) GetDevice(devnum));  
			}
	}  
}

static Rboolean	RQuartz_Open(NewDevDesc *dd, QuartzDesc *xd, char *dsp,
		    double wid, double hgt, int bg)
{
#ifdef QPOOL
	if (!quartzPool) quartzPool = [[NSAutoreleasePool alloc] init];
#endif
	NSString *title = [NSString stringWithUTF8String:dsp];
	RQuartz         *newDocument;

    xd->windowWidth = wid*72;
    xd->windowHeight = hgt*72;
    xd->window = NULL;
    xd->context = NULL;
    xd->auxcontext = NULL;
	
	xd->bg = dd->startfill = bg; /* 0xffffffff; transparent */
    dd->startcol = R_RGB(0, 0, 0);
    /* Create a new window with the specified size */

	newDocument = [[NSDocumentController sharedDocumentController] 
						openUntitledDocumentOfType:quartzDocType display:NO];
	if(newDocument == nil)
     {
         NSLog(@"Could not create new quartz device document");
		 return 0;
     }

	[newDocument setDeviceName: title];
	if (!title || [title length]<1) title=@"Quartz";		
	[RQuartz changeDocumentTitle: newDocument Title:title];
	xd->topLeftPoint = computeTopLeftCornerForDevNum(0, xd->QuartzPos, xd->windowWidth, xd->windowHeight);
//	NSLog(@"topLeftPoint: %f %f", xd->topLeftPoint.x, xd->topLeftPoint.y);
	[[newDocument getDeviceWindow] setFrameOrigin:
		NSMakePoint(xd->topLeftPoint.x, xd->topLeftPoint.y - xd->windowHeight)];
//	NSRect wrect;
//	wrect = [[newDocument getDeviceWindow] frame];
//	NSLog(@"frame: %f %f", wrect.origin.x, wrect.origin.y);
	[[newDocument getDeviceWindow] setContentSize:NSMakeSize(xd->windowWidth, xd->windowHeight) ];
	[[newDocument getDeviceWindow] orderFrontRegardless];
	
	xd->QuartzDoc = [newDocument retain];
    xd->color = xd->fill = R_TRANWHITE;
    xd->resize = false;
    xd->lineType = 0;
    xd->lineWidth = 1;
    return TRUE;
}


static void 	RQuartz_Close(NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc *) dd->deviceSpecific;

	if(xd->QuartzDoc) {
		[xd->QuartzDoc close];
		[xd->QuartzDoc release];
		// xd->QuartzDoc = nil;
	}

	if(xd->family)
		free(xd->family);
#ifdef QPOOL
	if (quartzPool) { [quartzPool release]; quartzPool = [[NSAutoreleasePool alloc] init]; }
#endif
	free(xd);
}

static void 	RQuartz_Activate(NewDevDesc *dd)
{
//	NSLog(@"RQuartz_Activate called");
	int devnum = devNumber((DevDesc *)dd);
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	xd->DevNum = devnum;
	[xd->DevView setDevNum: devnum];
//	NSLog(@"Devnum: %d", devnum);
	NSRect rect = [xd->DevWindow frame];
	NSScreen *screen = [NSScreen mainScreen];
	NSDictionary *screenDict = [screen deviceDescription];
	NSSize resolution = [[screenDict objectForKey:NSDeviceResolution] sizeValue];
//	NSSize screenSize = [[screenDict objectForKey:NSDeviceSize] sizeValue];
//	NSLog(@"Resolution: %f %f", resolution.width, resolution.height);
//	NSLog(@"Screen size: %f %f", screenSize.width, screenSize.height);
	float width = [[Preferences stringForKey:quartzPrefPaneWidthKey withDefault:@"4.5"] floatValue];
	float height = [[Preferences stringForKey:quartzPrefPaneHeightKey withDefault:@"4.5"] floatValue];
	float fwidth = width * resolution.width;
	float fheight = height * resolution.height + 22.0;
	
/*	
	Not great. Would have preferred to set window position in RQuartz_Open but cannot as devnum
	is not known at that point in time. Here I move the window to the right location the 1st time
	around and if it has not been moved or resized. xd->topLeftPoint contains the tLP coordinates
	as computed by computeTopLeftCornerForDevNum(devnum-1) and rect the actuals.
	Note also that after resizing, updatePreferences is called in RQuartz.m.
	Unfortunately the needed call to setContentSize in RQuartz_Open generates the initial flicker
	on opening a new window. Have not found a way around that (e.g. setFrame:display does not work).
*/
	
	if (xd->topLeftPoint.x < 5.0 ||
		fwidth==rect.size.width && fheight==rect.size.height &&
		xd->topLeftPoint.x == rect.origin.x && xd->topLeftPoint.y == rect.origin.y + fheight) {
		xd->topLeftPoint = computeTopLeftCornerForDevNum(devnum-1, xd->QuartzPos, xd->windowWidth, xd->windowHeight);
		[xd->DevWindow setFrameTopLeftPoint:xd->topLeftPoint];	
	}
	{
		NSString * dt = [xd->QuartzDoc deviceName];
		if (!dt || [dt length]<1) dt = [NSString stringWithFormat:@"Quartz (%d)", devnum+1];
		dt = [NSString stringWithFormat:NLS(@"%@ - Active"), dt];
		[RQuartz changeDocumentTitle: xd->QuartzDoc Title:dt];
	}

}

static void 	RQuartz_Deactivate(NewDevDesc *dd)
{
	int 		devnum = devNumber((DevDesc *)dd);
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	{
		NSString * dt = [xd->QuartzDoc deviceName];
		if (!dt || [dt length]<1) dt = [NSString stringWithFormat:@"Quartz (%d)", devnum+1];
		dt = [NSString stringWithFormat:NLS(@"%@ - Inactive"), dt];
		[RQuartz changeDocumentTitle: xd->QuartzDoc Title:dt];
	}		
}

static void 	RQuartz_Size(double *left, double *right,
		     	 double *bottom, double *top, NewDevDesc *dd)
{
    QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
    NSSize size = [xd->DevView bounds].size;
	
	*top = 0.0;
	*left = 0.0;
    *right = size.width;
    *bottom = size.height;

    if(xd->resize){
		xd->windowWidth = size.width;
		xd->windowHeight = size.height;
		xd->resize = false;
	}
    return;

}
static void 	RQuartz_NewPage(R_GE_gcontext *gc, NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;

	if ([xd->DevWindow isMiniaturized])
		[xd->DevWindow deminiaturize:nil];

#ifdef QPOOL
	if (quartzPool) { [quartzPool release]; quartzPool = [[NSAutoreleasePool alloc] init]; }
#endif
	
	[xd->DevView lockFocus];
	ClipArea = [xd->DevView bounds];
	NSRectClip(ClipArea);
	
    if(R_OPAQUE(gc->fill))
		RQuartz_SetFill(gc->fill, gc->gamma, dd);
	else
		[[NSColor windowBackgroundColor] set];
	NSRectFill( ClipArea );
	
		[xd->DevView unlockFocus];

}

/*	This function only sets the clipping area (CliapArea) to clip
	next time drawing occurs
*/	
static void 	RQuartz_Clip(double x0, double x1, double y0, double y1,
			    NewDevDesc *dd)
{
	float x, y, width, height;

    if (x0 < x1) {
		x = x0;
		width = (float)(x1 -x0);
    }
    else {
		x = x1;
		width = (float)(x0 -x1);
    }

    if (y0 < y1) {
		y = y0;
		height = (float)(y1 -y0);
    }
    else {
		y = y1;
		height = (float)(y0-y1);
    }

	ClipArea = NSMakeRect(x,y,width,height);
}

static double 	RQuartz_StrWidth(char *str, 
				R_GE_gcontext *gc,
				NewDevDesc *dd)
{
	NSString *text;
	
	if(gc->fontface==5  || strcmp(gc->fontfamily,"symbol")==0)
	    text = [[NSString alloc] initWithBytes:str length:strlen(str) encoding:NSSymbolStringEncoding];
	else 
		text = [[NSString stringWithUTF8String:str] retain];
	
	if (!text) return 0.0;
	
	NSDictionary* attr = [NSDictionary dictionaryWithObjectsAndKeys:
		RQuartz_Font(gc, dd), NSFontAttributeName,
		NULL];
		
	NSSize bbox = [text sizeWithAttributes:attr];
	
	[text release];
	
	return bbox.width;
}

static void 	RQuartz_Text(double x, double y, char *str,
			    double rot, double hadj, 
			    R_GE_gcontext *gc,
			    NewDevDesc *dd)
{
	NSString *text = nil;
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;

	if(gc->fontface==5  || strcmp(gc->fontfamily,"symbol")==0)
	    text = [[NSString alloc] initWithBytes:str length:strlen(str) encoding:NSSymbolStringEncoding];
	else 
		text = [[NSString alloc] initWithUTF8String:str];
	
	if (!text) return; /* if for some reason the decoding didn't work, just get out, nothing to see */
	
	NSColor* clr       = [NSColor colorWithCalibratedRed:(float)R_RED(gc->col)/255.0
												   green:(float)R_GREEN(gc->col)/255.0
													blue:(float)R_BLUE(gc->col)/255.0
												   alpha:(float)R_ALPHA(gc->col)/255.0];
	
	NSFont *font = RQuartz_Font(gc,  dd);
	NSDictionary* attr = [NSDictionary dictionaryWithObjectsAndKeys:
		font, NSFontAttributeName,
		clr, NSForegroundColorAttributeName,
		nil];

	[xd->DevView lockFocus];
	NSRectClip(ClipArea);
	//NSSize bbox = [text sizeWithAttributes:attr];
		
	NSAffineTransform *tns = [NSAffineTransform transform];	
	[tns translateXBy:x yBy:y];
	[tns rotateByDegrees:-rot];
	// in theory it should be sufficient to shift by the ascender, but obviously R is providing the wrong coordinates ...
	[tns translateXBy:0 yBy:-[font ascender]+[font descender]];	
	//[tns translateXBy:0 yBy:-bbox.height];
	[tns concat];

	[text drawAtPoint:NSMakePoint(0,0) withAttributes:attr];
	[text release];
	
	[xd->DevView unlockFocus];
}

static void 	RQuartz_Rect(double x0, double y0, double x1, double y1,
			    R_GE_gcontext *gc,
			    NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;

	NSBezierPath *rPath = [[NSBezierPath alloc] init];
	[rPath appendBezierPathWithRect:NSMakeRect(round(x0),round(y0),round(x1)-round(x0),round(y1)-round(y0))];
	
		[xd->DevView lockFocus];
	NSRectClip(ClipArea);
	
	RQuartz_SetStroke( gc->col, gc->gamma,  dd);
	RQuartz_SetFill( gc->fill, gc->gamma, dd);
	RQuartz_SetLineProperties(gc, rPath, dd);
	[rPath fill];
	[rPath stroke];
	[rPath release];

		[xd->DevView unlockFocus];

}
static void 	RQuartz_Circle(double x, double y, double r, 
			      R_GE_gcontext *gc,
			      NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
    
	NSBezierPath *rPath = [[NSBezierPath alloc] init];
	[rPath appendBezierPathWithOvalInRect:NSMakeRect(x-r, y-r, 2*r, 2*r)];
	
		[xd->DevView lockFocus];
	NSRectClip(ClipArea);
	
	RQuartz_SetStroke( gc->col, gc->gamma,  dd);
	RQuartz_SetFill( gc->fill, gc->gamma, dd);
	RQuartz_SetLineProperties(gc, rPath, dd);
	[rPath fill];
	[rPath stroke];
	[rPath release];
		[xd->DevView unlockFocus];

}

static void 	RQuartz_Line(double x1, double y1, double x2, double y2,
			    R_GE_gcontext *gc,
			    NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
		
	NSBezierPath *rPath = [[NSBezierPath alloc] init];
	[rPath moveToPoint:NSMakePoint(x1,y1)];
	[rPath lineToPoint:NSMakePoint(x2,y2)];
	
		[xd->DevView lockFocus];
			
	NSRectClip(ClipArea);
	
	RQuartz_SetStroke( gc->col, gc->gamma,  dd);
	RQuartz_SetFill( gc->fill, gc->gamma, dd);
	RQuartz_SetLineProperties(gc,  rPath, dd);
	[rPath stroke];
	[rPath release];
	
		[xd->DevView unlockFocus];
}

static void 	RQuartz_Polyline(int n, double *x, double *y, 
				R_GE_gcontext *gc,
				NewDevDesc *dd)
{
    int	i;
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;

	NSBezierPath *rPath = [[NSBezierPath alloc] init];
	[rPath moveToPoint:NSMakePoint(x[0],y[0])];
    
    for (i = 1; i < n; i++) 
		[rPath lineToPoint:NSMakePoint(x[i],y[i])];
	
	
		[xd->DevView lockFocus];
	NSRectClip(ClipArea);
	
	RQuartz_SetStroke( gc->col, gc->gamma,  dd);
	RQuartz_SetFill( gc->fill, gc->gamma, dd);
	RQuartz_SetLineProperties(gc,  rPath, dd);
	[rPath stroke];
	[rPath release];
	
		[xd->DevView unlockFocus];

}
				
static void 	RQuartz_Polygon(int n, double *x, double *y, 
			       R_GE_gcontext *gc,
			       NewDevDesc *dd)
{
    int	i;
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;

	NSBezierPath *rPath = [[NSBezierPath alloc] init];
	[rPath moveToPoint:NSMakePoint(x[0],y[0])];
    
    for (i = 1; i < n; i++) 
		[rPath lineToPoint:NSMakePoint(x[i],y[i])];
	[rPath lineToPoint:NSMakePoint(x[0],y[0])];
	[rPath closePath];
	
		[xd->DevView lockFocus];
	NSRectClip(ClipArea);
	
	RQuartz_SetStroke( gc->col, gc->gamma,  dd);
	RQuartz_SetFill( gc->fill, gc->gamma, dd);
	RQuartz_SetLineProperties(gc,  rPath, dd);
	[rPath fill];
	[rPath stroke];
	[rPath release];
	
		[xd->DevView unlockFocus];

}
				   
static void 	RQuartz_Mode(int mode, NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	if(mode==0)
		[xd->DevWindow flushWindow];
}				

static void RQuartz_SetFill(int fill, double gamma,  NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	xd->fill = fill;
	[[NSColor colorWithCalibratedRed:(float)R_RED(fill)/255.0
		 green:(float)R_GREEN(fill)/255.0
		 blue:(float)R_BLUE(fill)/255.0
		 alpha:(float)R_ALPHA(fill)/255.0] setFill];
}

static void RQuartz_SetStroke(int color, double gamma,  NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	xd->color = color;
	[[NSColor colorWithCalibratedRed:(float)R_RED(color)/255.0
		 green:(float)R_GREEN(color)/255.0
		 blue:(float)R_BLUE(color)/255.0
		 alpha:(float)R_ALPHA(color)/255.0] setStroke];
}

static void RQuartz_SetLineProperties(R_GE_gcontext *gc,  NSBezierPath *path, NewDevDesc *dd)
{
    RQuartz_SetLineWidth(gc->lwd, path);
    RQuartz_SetLineDash(gc->lty, gc->lwd, path, dd);
    RQuartz_SetLineEnd(gc->lend,  path);
    RQuartz_SetLineJoin(gc->ljoin,  path);
    RQuartz_SetLineMitre(gc->lmitre,  path);
}



static void RQuartz_SetLineDash(int newlty, double lwd, NSBezierPath *path, NewDevDesc *dd)
{
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
    float dashlist[8];
    int i, ndash = 0;
    
    lwd *= 0.75;  /* kludge from postscript/pdf */
    for(i = 0; i < 8 && newlty & 15 ; i++) {
	dashlist[ndash++] = (lwd >= 1 ? lwd: 1) * (newlty & 15);
	newlty = newlty >> 4;
    }
    xd->lineType = newlty;

	[path setLineDash: dashlist count:ndash phase:0.0];
}

static void RQuartz_SetLineWidth(double lwd,  NSBezierPath *path)
{
	[path setLineWidth: lwd]; 
}

static void RQuartz_SetLineEnd(R_GE_lineend lend, NSBezierPath *path)
{
    NSLineCapStyle linecap=nil;
    switch (lend) {
		case GE_ROUND_CAP:
			linecap = NSRoundLineCapStyle;
			break;
		case GE_BUTT_CAP:
			linecap = NSButtLineCapStyle;
			break;
		case GE_SQUARE_CAP:
			linecap = NSSquareLineCapStyle;
			break;
		default:
			NSLog(@"RQuartz_SetLineEnd: Invalid line end");
			break; 
    }
    if (linecap)
		[path setLineCapStyle:linecap];
}

   
static void RQuartz_SetLineJoin(R_GE_linejoin ljoin, NSBezierPath *path)
{
    NSLineJoinStyle linejoin=nil;
    switch (ljoin) {
		case GE_ROUND_JOIN:
			linejoin = NSRoundLineJoinStyle;
			break;
		case GE_MITRE_JOIN:
			linejoin = NSMiterLineJoinStyle;
			break;
		case GE_BEVEL_JOIN:
			linejoin = NSBevelLineJoinStyle;
			break;
		default:
			NSLog(@"RQuartz_SetLineJoin: Invalid line join");
			break;  
    }
	if (linejoin)
		[path setLineJoinStyle: linejoin];
}

static void RQuartz_SetLineMitre(double lmitre, NSBezierPath *path)
{
    if (lmitre < 1)
        NSLog(@"RQuartz_SetLineMitre:Invalid line mitre");
	else
		[path setMiterLimit: lmitre];
}



NSFont *RQuartz_Font(R_GE_gcontext *gc,  NewDevDesc *dd)
{
	NSFontManager   *fm       = [NSFontManager sharedFontManager];

    QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
    int size = gc->cex*gc->ps + 0.5;
 	char *fontFamily=0;
	NSFontTraitMask  traits   = 0;
	NSString *currFont = @"Helvetica";
	 
	
	if((gc->fontface == 5) || (strcmp(gc->fontfamily,"symbol")==0))
		currFont = @"Symbol";
	else {	
		fontFamily = Quartz_TranslateFontFamily(gc->fontfamily, gc->fontface, xd->family);
		
		if (fontFamily)
			currFont=[NSString stringWithUTF8String:fontFamily];
	}
	if (!currFont) currFont = @"Helvetica";
	
	if( ![currFont isEqual: @"Symbol"] )
		traits=
			((gc->fontface==2||gc->fontface==4)?NSBoldFontMask:0)|
			((gc->fontface==3||gc->fontface==4)?NSItalicFontMask:0);

	NSRange range = NSMakeRange(0, [currFont length]);
	range = [currFont rangeOfString: @"-" options: 0 range: range];
	if (range.location != NSNotFound )
		currFont = [currFont substringWithRange:NSMakeRange(0, range.location)];
	
	NSFont* font = [fm fontWithFamily:currFont traits:traits weight:5 size:size];

	return font;
}

static void 	RQuartz_Hold(NewDevDesc *dd){}

/* FIXME:	the metric info is not correct, in particular,
			it is somewhat bigger than it should be.
 */
static void 	RQuartz_MetricInfo(int c,
				  R_GE_gcontext *gc,
				  double* ascent, double* descent, 
				  double* width,
				  NewDevDesc *dd)
{
	//QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	NSFont* font= RQuartz_Font(gc,dd);
	unichar uc = (unichar)c;
	char str[2];

	str[1] = '\0';	
	str[0] = (char)c;

	*ascent = [font ascender];
	*descent = [font descender];
	*width = [font maximumAdvancement].width;
	if (c) {
		NSDictionary* attr = [NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName,
			nil];
		
		NSString *text = nil;
		
		if(gc->fontface==5 || strcmp(gc->fontfamily,"symbol")==0)
			text = [[NSString alloc] initWithBytes:str length:1 encoding:NSSymbolStringEncoding];
		else
			text = [[NSString stringWithCharacters:&uc length:1] retain];
	
		*width = [text sizeWithAttributes: attr].width;
		
		[text release];
	}
    
	//fprintf(stderr,"c=%c,ascent=%f, descent=%f,width=%f,width2=%f,width3=%f\n",c,*ascent , *descent, *width, *width+rect2.origin.x,NSWidth(rect));

//	NSLog(@"x=%f,y=%f,width=%f,height=%f",rect.origin.x, rect.origin.y,rect.size.width,rect.size.height);
//	NSLog(@"x=%f,y=%f,width=%f,height=%f",rect2.origin.x, rect2.origin.y,rect2.size.width,rect2.size.height);
	
}

/* Adapted from original code by: Byron Ellys, StatPaperBundle, DeviceController: locatorForX, cocoaLocator
*/

static Rboolean RQuartz_Locator(double *x,double *y,NewDevDesc*dd){
	QuartzDesc *xd = (QuartzDesc*)dd->deviceSpecific;
	[xd->DevWindow makeKeyAndOrderFront:xd->DevWindow];
	int useBeep = asLogical(GetOption(install("locatorBell"), 
						      R_NilValue));

	for(;;) {
		NSEvent*event = [xd->DevWindow nextEventMatchingMask:NSEventMaskFromType(NSLeftMouseDown)|NSEventMaskFromType(NSKeyDown)];
		NSPoint p;
		if([event window] == xd->DevWindow) {
			switch([event type]) {
				case NSLeftMouseDown:
					p = [xd->DevView convertPoint:[event locationInWindow] fromView:nil];
		//			NSLog(@"Location: %.2f,%.2f",p.x,p.y);
					*x = p.x; *y = p.y;
					if(useBeep)
						NSBeep();
					return 1;
				break;	
				case NSKeyDown:
					return 0;
				break;	
				default:
					// don't bark - it may be other button thus the action may be ok
					//NSLog(@"Unknown event from locator");
					return 0;
				break;	
			}
		}
	}
}

NSPoint computeTopLeftCornerForDevNum(int devnum, int quartzpos, int width, int height) {
	NSPoint topLeftCorner;
	NSScreen *screen = [NSScreen mainScreen];
	NSDictionary *screenDict = [screen deviceDescription];
	NSSize resolution = [[screenDict objectForKey:NSDeviceResolution] sizeValue];
	NSSize screenSize = [[screenDict objectForKey:NSDeviceSize] sizeValue];
//	NSLog(@"Resolution: %f %f", resolution.width, resolution.height);
//	NSLog(@"Screen size: %f %f", screenSize.width, screenSize.height);
//	int quartzpos = [[Preferences stringForKey:quartzPrefPaneLocationIntKey withDefault:@"3"] intValue];
//	int width = [[Preferences stringForKey:quartzPrefPaneWidthKey withDefault:@"4.5"] intValue];
//	int height = [[Preferences stringForKey:quartzPrefPaneHeightKey withDefault:@"4.5"] intValue];
	float x, y;
	switch(quartzpos){
		case 0:									// Top right
			x = screenSize.width - (width + resolution.width);
			y = screenSize.height - 0.5 * resolution.height;
			break;
			
		case 1:									// Bottom right
			x = screenSize.width - (width + resolution.width);
			y = height + resolution.height;
			break;
			
		case 2:									// Bottom left
			x = 0.5 * resolution.width; 
			y = height + resolution.height;
			break;	
			
		case 3:									// Top left
			x = 0.5 * resolution.width;
			y = screenSize.height - 0.5 * resolution.height;
			break;	
			
		case 4:									// Centered
			x = screenSize.width/2 - width/2; 
			y = screenSize.height/2 + height/2;
			break;	
			
		default:
			x = 0.5 * resolution.width; 
			y = screenSize.height - 0.5 * resolution.height;
			break; 
	}
	topLeftCorner.x = x + devnum * 21;
	topLeftCorner.y = y - devnum * 23;
//	NSLog(@"Screen at: %f %f with devnum=%d, pos=%d, width=%d and height=%d", topLeftCorner.x, topLeftCorner.y, devnum, quartzpos, width, height);
	return topLeftCorner;
}

/* my own hack */

SEXP QuartzSaveContents(SEXP nr, SEXP fn, SEXP type, SEXP formatOptions) {
	int dev = asInteger(nr)-1;
    int ds = NumDevices();
	const char *fts;
	BOOL bitmap = YES;
	NSBitmapImageFileType ftype = NSPNGFileType;
	
	if (!isString(fn) || LENGTH(fn)<1) error("Filename must be a string.");
	if (!isString(type) || LENGTH(type)<1) error("Filename must be a string.");
	fts =  CHAR(STRING_ELT(type,0));
    if (dev<0 || dev>=ds) error("Device nr out of range.");
	if (!strcmp(fts,"png")) ftype=NSPNGFileType;
	else if (!strcmp(fts,"tif") || !strcmp(fts,"tiff")) ftype=NSTIFFFileType;
	else if (!strcmp(fts,"jpg") || !strcmp(fts,"jpeg")) ftype=NSJPEGFileType;
	else if (!strcmp(fts,"gif")) ftype=NSGIFFileType;
	else if (!strcmp(fts,"bmp")) ftype=NSBMPFileType;
	else if (!strcmp(fts,"pdf")) bitmap=NO;
	else error("Invalid file type. Supported types are: png, tiff, jpeg, gif, bmp and pdf.");
	
    {
        GEDevDesc *gd=(GEDevDesc*)GetDevice(dev);
        if (!gd) error("Can't get device descriptor.");
		else {
			NewDevDesc *dd=gd->dev;
			if (!dd) error("Can't get device data descriptor.");
			else {
				QuartzDesc *xd = (QuartzDesc *) dd-> deviceSpecific;
				NSString *sFn = [NSString stringWithUTF8String:CHAR(STRING_ELT(fn, 0))];
				if (!sFn) error("Invalid file name.");
				sFn = [sFn stringByExpandingTildeInPath];
				if (bitmap)
					[xd->DevView saveAsBitmap: sFn usingType:ftype];
				else
					[xd->DevView saveAsPDF: sFn];
			}
		}
	}
	return R_NilValue;
}

static R_CallMethodDef quartzCallMethods[]  = {
  {"QuartzSaveContents", (DL_FUNC) &QuartzSaveContents, 4},
  {NULL, NULL, 0}
};

#if (R_VERSION < R_Version(2,6,0))
/*-- now, this is ugly, we use internals of Rdynload to squeeze our functions into base load table --*/
static void R_addCallRoutine(DllInfo *info, const R_CallMethodDef * const croutine,
                 Rf_DotCallSymbol *sym)
{
    sym->name = strdup(croutine->name);
    sym->fun = croutine->fun;
    sym->numArgs = croutine->numArgs > -1 ? croutine->numArgs : -1;
}

static void registerCall(DllInfo *info, const R_CallMethodDef * const callRoutines) {
	int oldnum = info->numCallSymbols;
	int num, i;
	for(num=0; callRoutines[num].name != NULL; num++) {;}
	info->CallSymbols =	(Rf_DotCallSymbol*)realloc(info->CallSymbols, (num+oldnum)*sizeof(Rf_DotCallSymbol));
	info->numCallSymbols = num+oldnum;
	for(i = 0; i < num; i++)
		R_addCallRoutine(info, callRoutines+i, info->CallSymbols + i + oldnum);
}

void QuartzRegisterSymbols() {
	/* we add those to the base as we have no specific entry (yet?) */
	registerCall(R_getDllInfo("base"), quartzCallMethods);
}

#else
/* since R 2.6.0 we have an API for this */
void QuartzRegisterSymbols() {
	R_registerRoutines(R_getEmbeddingDllInfo(), 0, quartzCallMethods, 0, 0);
}
#endif
