/* PackageManager */

#import <Cocoa/Cocoa.h>

// structure holding all available data about a package
typedef struct pkgManagerEntry {
	NSString *name;
	NSString *desc;
	NSString *url;
	BOOL status;
} s_pkgManagerEntry;

@interface PackageManager : NSObject
{
	IBOutlet NSTableView *packageDataSource;	/* TableView for the history */ 
	IBOutlet id PackageInfoView;
	id  PackageManagerWindow;
	
	int packages;
	s_pkgManagerEntry *package;
}

+ (PackageManager*) sharedController;

- (id) window;
- (IBAction) showInfo:(id)sender;
- (IBAction) reloadPMData:(id)sender;
- (void) reloadData;

- (void) show;

- (void) resetPackages; // removes all package data
- (void) updatePackages: (int) count withNames: (char**) name descriptions: (char**) desc URLs: (char**) url status: (BOOL*) stat;
- (int) count;

@end
