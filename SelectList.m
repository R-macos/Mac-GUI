#import "SelectList.h"

static SelectList *sharedController = nil;

@implementation SelectList


- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		[listDataSource setTarget: self];
		totalItems = 0;
		listItem = 0;
    }
	
    return self;
}

+ (SelectList*) sharedController
{
	return sharedController;
}

- (void)dealloc {
	[self resetListItems];
	[super dealloc];
}
/* These two routines are needed to update the SelectList TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return totalItems;
}

- (id)tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)tableColumn row: (int)row
{
	if (row<totalItems) {
		if([[tableColumn identifier] isEqualToString:@"item"])
			return listItem[row].name;
	}
	return nil; 
}


- (id) window
{
	return SelectListWindow;
}

- (void) reloadData
{
	[listDataSource reloadData];
}

- (void) resetListItems
{
	if (!totalItems) return;
	int i=0;
	while (i<totalItems) {
		[listItem[i].name release];
		i++;
	}
	free(listItem);
	totalItems=0;
}

- (void) updateListItems: (int) count withNames: (char**) item status: (BOOL*) stat;
{
	int i=0;
	
	if (totalItems) [self resetListItems];
	if (count<1) {
		[self show];
		return;
	}
	
	
	listItem = malloc(sizeof(*listItem)*count);
	while (i<count) {
		listItem[i].name =[[NSString alloc] initWithCString: item[i]];
		i++;
	}
	totalItems = count;
	[self show];
}

- (int) count
{
	return totalItems;
}

- (void) show
{
	[listDataSource reloadData];
	[[self window] makeKeyAndOrderFront:self];
}

@end
