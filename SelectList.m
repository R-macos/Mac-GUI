#import "RGUI.h"
#import "SelectList.h"

static SelectList *sharedController = nil;

@implementation SelectList

BOOL IsSelectList;

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		[listDataSource setTarget: self];
		totalItems = 0;
		listItem = 0;
		result = -1;
		itemStatus = 0;
		running = NO;
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
			return listItem[row];
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
	if (!totalItems || !listItem) return;
	int i=0;
	while (i<totalItems) {
		[listItem[i] release];
		i++;
	}
	free(listItem);
	totalItems=0;
}

- (void) updateListItems: (int) count withNames: (char**) item status: (BOOL*) stat multiple: (BOOL) multiple title: (NSString*) ttl
{
	int i=0;
	title = ttl;
	result = -1;
	itemStatus = stat;
	[listDataSource setAllowsMultipleSelection: multiple];

	if (totalItems) [self resetListItems];
	if (count<1)
		return;	
	
	listItem = (NSString**) malloc(sizeof(NSString*) * count);
	while (i<count) {
		listItem[i] =[[NSString alloc] initWithUTF8String: item[i]];
		i++;
	}
	totalItems = count;
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


- (IBAction)returnSelected:(id)sender
{
	NSIndexSet *rows =  [listDataSource selectedRowIndexes];			
	unsigned current_index = [rows firstIndex];

	if(current_index == NSNotFound)
		return;
	
	if (itemStatus) {
		memset(itemStatus, 0, sizeof(BOOL)*totalItems);
		while (current_index != NSNotFound) {
			itemStatus[current_index] = YES;
			current_index = [rows indexGreaterThanIndex: current_index];
		}
	}

	result = 1;
	
	[[self window] performClose: sender];

}

- (BOOL)windowShouldClose:(id)sender{
	
	if(running){
		[NSApp stopModal];
		running = NO;
	}
	return YES;	
}

- (IBAction)cancelSelection:(id)sender
{
	result = 0;

	[[self window] performClose: sender];
}

- (int) runSelectList
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	int i,k=0;
	[listDataSource deselectAll:self];
	if (itemStatus)
		for(i=0; i<totalItems; i++){
			if(itemStatus[i]){
				k++;
				[listDataSource selectRowIndexes:[NSIndexSet indexSetWithIndex:i] 
							byExtendingSelection:(k!=1)?YES:NO];
			}
		};
			
	[[self window] setTitle:title];
	[self show];
	running = YES;
	[NSApp runModalForWindow:[self window]];
	
	[pool release];
	
	return result;
}

- (void) runFinished
{
	itemStatus = 0;
}

@end
