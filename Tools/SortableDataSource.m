//
//  SortableDataSource.m
//
//  Created by Simon Urbanek on 11/3/04.
//

#import "SortableDataSource.h"

@implementation SortableDataSource

- (void) addColumn: (NSArray*) colCont withName: (NSString*) name
{
    [col addObject: colCont];
    [colNames addObject: name];
    if ([col count]==1) {
		int i=0;
		rows=[colCont count];
		sortMap=(int*) malloc(sizeof(int)*rows);
		invSortMap=(int*) malloc(sizeof(int)*rows);
		while (i<rows) { sortMap[i]=invSortMap[i]=i; i++; }
    } else if ([colCont count]!=rows) {
		NSLog(@"SortableDataSource: column %@ has %d rows, but the data source has %d rows! Bad things may happen...", name, rows);
    }
}

- (void) addColumnOfLength: (int) clen withCStrings: (char**) cstr name: (NSString*) name
{
	NSString **ca = (NSString**) malloc(sizeof(NSString*)*clen);
	int i=0;
	while (i<clen) {
		ca[i] = [NSString stringWithCString: cstr[i]];
		i++;
	}
	[self addColumn: [NSArray arrayWithObjects:ca count:clen] withName:name];
	free(ca);
}

- (id) init
{
    self = [super init];
    if (self) {
		col=[[NSMutableArray alloc] init];
		colNames=[[NSMutableArray alloc] init];
		rows=0;
		sortMap=invSortMap=0;
    }
    return self;
}

- (void) dealloc
{
    [self reset];
    [col release];
    [colNames release];
    [super dealloc];
}

- (int*) sortMap
{
    return sortMap;
}

- (int*) inverseSortMap
{
    return invSortMap;
}

- (void) reset
{
    [col removeAllObjects];
    [colNames removeAllObjects];
    rows=0;
    if (sortMap) free(sortMap); sortMap=0;
    if (invSortMap) free(invSortMap); invSortMap=0;
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return rows;
}

- (unsigned) count
{
	return rows;
}

- (id) objectAtColumn: (NSString*) name row: (int) row
{
    if (row<0 || row>=rows || !name)
		return nil;
    else {
		unsigned c = [colNames indexOfObject:name];
		if (c==NSNotFound) return nil;
		else {
			NSArray *cc = (NSArray*) [col objectAtIndex: c];
			return (!cc)?nil:[cc objectAtIndex: sortMap[row]];
		}
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [self objectAtColumn: [tableColumn identifier] row: row];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *) oldDescriptors
{
}

@end
