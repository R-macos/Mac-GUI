/* SelectList */

#import <Cocoa/Cocoa.h>

typedef struct itemListEntry {
	NSString *name;
	BOOL status;
} s_itemListEntry;

@interface SelectList : NSObject
{
	IBOutlet NSTableView *listDataSource;	/* TableView for the list */ 
	id  SelectListWindow;
	
	int totalItems;
	s_itemListEntry *listItem;
}


+ (SelectList*) sharedController;

- (id) window;
- (void) reloadData;

- (void) show;

- (void) resetListItems; // removes all items data
- (void) updateListItems: (int) count withNames: (char**) item status: (BOOL*) stat;

- (int) count;

@end
