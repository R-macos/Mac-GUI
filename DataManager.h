/* DataManager */

#import <Cocoa/Cocoa.h>

@interface DataManager : NSObject
{
    IBOutlet NSTableView *RDataSource;
	IBOutlet id dataInfoView;
	id  DataManagerWindow;
	
}

- (id) window;
- (IBAction)loadRData:(id)sender;
- (IBAction)showHelp:(id)sender;

+ (void) toggleDataManager;
+ (void) reloadData;
+ (id) getDMController;
@end

