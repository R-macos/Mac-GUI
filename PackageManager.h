/* PackageManager */

#import <Cocoa/Cocoa.h>

@interface PackageManager : NSObject
{
	IBOutlet NSTableView *packageDataSource;	/* TableView for the history */ 
	IBOutlet id PackageInfoView;
	id  PackageManagerWindow;
}

- (id) window;
- (IBAction) showInfo:(id)sender;
- (IBAction) reloadPMData:(id)sender;
- (void) doReloadData;


+ (void) togglePackageManager;
+ (void) reloadData;

@end
