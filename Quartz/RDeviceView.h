/* RDeviceView */

#import <Cocoa/Cocoa.h>

@interface RDeviceView : NSView
{
	NSWindow	*deviceWindow;
	int         deviceNum;
	IBOutlet id delegate;
	NSTextStorage *devTextStorage;
	NSLayoutManager *devLayoutManager;
	NSTextContainer *devTextContainer;
	BOOL PDFDrawing;  
}

/* PDFDrawing: This flag is used to force replay the displayGList of the graphic device inside the draw: method. 
			   It is used for clipboard PDF pasting and shuld be also used for saving to PDF
*/

- (NSTextStorage *)getDevTextStorage;
- (NSLayoutManager *)getDevLayoutManager;
- (NSTextContainer *)getDevTextContainer;
- (void) setDevNum: (int)dnum;
- (int) getDevNum;
- (void) setPDFDrawing: (BOOL)flag;
- (BOOL) isPDFDrawing;
@end
