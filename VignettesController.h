/* VignettesController */

#import <Cocoa/Cocoa.h>
#import "RGUI.h"
#import "Tools/SortableDataSource.h"
#import "Tools/PDFImageView.h"

@interface VignettesController : NSObject
{
    IBOutlet NSSearchField *filterField;
    IBOutlet NSButton *openButton;
    IBOutlet NSButton *openSourceButton;
    IBOutlet NSTableView *tableView;
	IBOutlet NSWindow *window;
	IBOutlet NSDrawer *pdfDrawer;
	IBOutlet PDFImageView *pdfView;
	
	SortableDataSource *dataSource;
	
	int* filter;
	int  filterlen;
}

- (IBAction)openVignette:(id)sender;
- (IBAction)openVignetteSource:(id)sender;

- (IBAction)search:(id)sender;

- (void) showVigenttes;

+ (VignettesController*) sharedController;

@end
