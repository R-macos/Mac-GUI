/* DataManager */

#import <Cocoa/Cocoa.h>

typedef struct dataManagerEntry {
	NSString *name;
	NSString *desc;
	NSString *pkg;
	NSString *url;
} s_dataManagerEntry;

@interface DataManager : NSObject
{
    IBOutlet NSTableView *RDataSource;
	IBOutlet id dataInfoView;
	NSWindow *DataManagerWindow;
	
	int datasets;
	s_dataManagerEntry *dataset;
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

