/* DataManager */

#import <Cocoa/Cocoa.h>
#import "SortableDataSource.h"

@interface DataManager : NSObject
{
    IBOutlet NSTableView *RDataSource;
	IBOutlet id dataInfoView;
	NSWindow *DataManagerWindow;
		
	SortableDataSource *dataSource;
}

- (id) window;
- (IBAction)loadRData:(id)sender;
- (IBAction)showHelp:(id)sender;
- (void) show;

- (void) resetDatasets;
- (void) updateDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url;
- (int) count;

+ (DataManager*) sharedController;
@end

