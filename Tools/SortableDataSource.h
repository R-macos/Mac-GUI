//
//  SortableDataSource.h
//
//  Created by Simon Urbanek on 11/3/04.
//

#import <Cocoa/Cocoa.h>

@interface SortableDataSource : NSObject {
    NSMutableArray *col;
    NSMutableArray *colNames;
    int rows;
    int *sortMap, *invSortMap;
}

- (void) addColumn: (NSArray*) colCont withName: (NSString*) name;
- (void) addColumnOfLength: (int) clen withCStrings: (char**) cstr name: (NSString*) name;
- (void) reset;
- (unsigned) count;
- (id) objectAtColumn: (NSString*) name row: (int) row;

- (int)  numberOfRowsInTableView:(NSTableView *)tableView;
- (id)   tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
- (void) tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
	// #if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
- (void) tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *) oldDescriptors;

@end
