#import "SelectList.h"

static SelectList *sharedController = nil;

@implementation SelectList

extern int *itemStatus;
extern int 	selectListDone;

BOOL IsSelectList;

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

- (id) tableView
{
	return listDataSource;
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

- (void) updateListItems: (int) count withNames: (char**) item status: (BOOL*) stat multiple: (BOOL) multiple;
{
	int i=0;
	[listDataSource setAllowsMultipleSelection: multiple];

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


- (IBAction)returnSelected:(id)sender
{
	int i;
	
	NSIndexSet *rows =  [listDataSource selectedRowIndexes];			
	unsigned current_index = [rows firstIndex];
	if(current_index == NSNotFound)
		return;
		
	for(i=0; i<totalItems; i++)
		itemStatus[i] = 0;
	while (current_index != NSNotFound) {
		itemStatus[current_index] = 1;
		current_index = [rows indexGreaterThanIndex: current_index];
	}

	selectListDone = 1;
	
	[[self window] performClose: sender];

}

- (BOOL)windowShouldClose:(id)sender{
	
	if(IsSelectList){
		[NSApp stopModal];
		IsSelectList = NO;
	}
	return YES;	
}

- (IBAction)cancelSelection:(id)sender
{
	selectListDone = 0;

	[[self window] performClose: sender];
}

+ (void)startSelectList: (NSString *)title;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	int i,k=0;
	for(i=0; i<[[[SelectList sharedController] tableView] numberOfRows]; i++){
		if(itemStatus[i]==1){
			k++;
			[[[SelectList sharedController] tableView] selectRowIndexes:[NSIndexSet indexSetWithIndex:i] 
												byExtendingSelection:(BOOL)(k!=1)];
		}
	}
	

	[[[SelectList sharedController] window] setTitle:title];
	[[[SelectList sharedController] window] orderFront:self];
	[NSApp runModalForWindow:[[SelectList sharedController] window]];
	
	[pool release];
}


@end
