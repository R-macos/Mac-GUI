/* SelectList */

#import <Cocoa/Cocoa.h>

@interface SelectList : NSObject
{
	IBOutlet NSTableView *listDataSource;	/* TableView for the list */ 
	id  SelectListWindow;
	
	int totalItems;
	NSString **listItem;
	BOOL *itemStatus;
	
	int result;
	BOOL running;
	NSString *title;
}


+ (SelectList*) sharedController;

- (id) window;
- (void) reloadData;

- (void) show;

- (void) resetListItems; // removes all items data
- (void) updateListItems: (int) count withNames: (char**) item status: (BOOL*) stat multiple: (BOOL) multiple title: (NSString*) ttl;
				   
- (int) count;

- (IBAction)returnSelected:(id)sender;
- (IBAction)cancelSelection:(id)sender;
- (BOOL)windowShouldClose:(id)sender;

- (int) runSelectList; // should be called only after updateListItems was called at least once
- (void) runFinished; // should be called to clean up any external buffer references - next round will be initiated by updateListItems:

@end
