/* REditor */

#import <Cocoa/Cocoa.h>

#define DataEditorToolbarIdentifier      @"DataEditor Toolbar Identifier"
#define AddColToolbarItemIdentifier      @"Add Column"
#define RemoveColsToolbarItemIdentifier  @"Remove Columns"
#define AddRowToolbarItemIdentifier      @"Add Row"
#define RemoveRowsToolbarItemIdentifier  @"Remove Rows"

@interface REditor : NSObject
{
    IBOutlet NSTableView *editorSource;
    IBOutlet NSWindow *dataWindow;
	NSToolbar *toolbar;
}

- (id) window;
- (void)setDatas:(BOOL)removeAll;
- (void) setupToolbar;
	
-(IBAction) addCol:(id)sender;
-(IBAction) remCols:(id)sender;
-(IBAction) addRow:(id)sender;
-(IBAction) remRows:(id)sender;
	
+ (id) getDEController;
+ (void)startDataEntry;

@end
