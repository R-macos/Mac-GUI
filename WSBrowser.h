/* WSBrowser */

#import <Cocoa/Cocoa.h>

#define WorkSpaceBrowserToolbarIdentifier      @"WorkSpaceBrowser Toolbar Identifier"

#define RemoveObjectToolbarItemIdentifier @"Remove Objects"
#define EditObjectToolbarItemIdentifier @"Edit Object"
#define RefreshObjectsListToolbarItemIdentifier @"Refresh Objects List"

@interface WSBrowser : NSObject
{
	IBOutlet NSWindow *WSBWindow;
	IBOutlet NSOutlineView *WSBDataSource;
    NSMutableArray *dataStore;
	NSToolbar *toolbar;
}


- (void)initWSData;
- (void) doInitWSData;
- (IBAction) reloadWSBData:(id)sender;
- (void) setupToolbar;
-(NSString *)getObjectName;
-(IBAction) editObject:(id)sender;
-(IBAction) remObject:(id)sender;
- (void) shouldRemoveObj:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

+ (void) initData;
+ (void)toggleWorkspaceBrowser;

@end
