#import "VignettesController.h"

#import "REngine/REngine.h"
#import "REngine/RSEXP.h"


@implementation VignettesController

static VignettesController *vignettesSharedController = nil;

+ (VignettesController*) sharedController
{
	return vignettesSharedController;
}

- (IBAction)openVignette:(id)sender
{
	int sr = [tableView selectedRow];
	if (sr>=0) {
		system([[NSString stringWithFormat:@"open %@/%@/doc/%@.pdf",
			[dataSource objectAtColumn:@"path" row:sr],
			[dataSource objectAtColumn:@"package" row:sr],
			[dataSource objectAtColumn:@"vignette" row:sr]]
			UTF8String]);
	}
}

- (void) runFilter: (NSString*) filterString
{
	SLog(@"VignettesController.reRunFilter (search string is %@)",filterString?filterString:@"<none>");
	
	NSIndexSet *preIx = [tableView selectedRowIndexes];
	NSMutableIndexSet *postIx = [[NSMutableIndexSet alloc] init];
	NSMutableIndexSet *absSelIx = [[NSMutableIndexSet alloc] init];
	int i=0;
	
	if ([preIx count]>0) { // save selection in absolute index positions
		i = [preIx firstIndex];
		do {
			if (!filter || i<filterlen)
				[absSelIx addIndex:filter?filter[i]:i];
			i = [preIx indexGreaterThanIndex:i];
		} while (i!=NSNotFound);
		i=0;
	}
	
	if (filter) {
		filterlen=0;
		if (filter) free(filter);
		filter=0;
	}
	
	if (filterString && [filterString length]>0) {
		filterlen=0;
		while (i<[dataSource count]) {
			if ([(NSString*)[dataSource objectAtColumn:@"vignette" index:i] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound ||
				[(NSString*)[dataSource objectAtColumn:@"description" index:i] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound ||
				[(NSString*)[dataSource objectAtColumn:@"package" index:i] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound
				) filterlen++;
			i++;
		}
		SLog(@" - found %d matches", filterlen);
		filter=(int*)malloc(sizeof(int)*(filterlen+1));
		i=0; filterlen=0;
		while (i<[dataSource count]) {
			if ([(NSString*)[dataSource objectAtColumn:@"vignette" index:i] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound ||
				[(NSString*)[dataSource objectAtColumn:@"description" index:i] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound ||
				[(NSString*)[dataSource objectAtColumn:@"package" index:i] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound
				) {
				if ([absSelIx containsIndex:i])
					[postIx addIndex:filterlen];
				filter[filterlen++]=i;
			}
			i++;
		}
	} else [postIx addIndexes:absSelIx];
	
	if (filter)
		[dataSource setFilter:filter length:filterlen];
	else
		[dataSource resetFilter];
	
	[tableView reloadData];
	[tableView selectRowIndexes:postIx byExtendingSelection:NO];
	[absSelIx release];
	[postIx release];
}

- (IBAction)search:(id)sender
{
	if (dataSource)
		[self runFilter: [filterField stringValue]];
}

- (void) reload
{
	SLog(@"VignettesController.reload");
	[dataSource reset];
	RSEXP *x = [[REngine mainEngine] evaluateString:@"vignette()$results"];
	SLog(@" result = %@", x);
	if (x) {
		RSEXP *dim = [x attr: @"dim"];
		if (dim) {
			if ([dim length]!=2) {
				SLog(@"VignettesController.reload: result is not 2-dimnsional");
			} else {
				int *dimi = [dim intArray];
				if (dimi[1]<4) {
					SLog(@"VignettesController.reload: not enough columns");
				} else {
					int tl = [x length];
					NSString **a = [x strings];
					
//					SLog(@"tl=%d, a=%x", tl, a);
					if (a) {
						NSArray *aPkg = [[NSArray alloc] initWithObjects:a count:dimi[0]];
						NSArray *aPath= [[NSArray alloc] initWithObjects:a+dimi[0] count:dimi[0]];
						NSArray *aFile= [[NSArray alloc] initWithObjects:a+dimi[0]*2 count:dimi[0]];
						NSArray *aDesc= [[NSArray alloc] initWithObjects:a+dimi[0]*3 count:dimi[0]];
						
						[dataSource addColumn:aPkg withName:@"package"];
						[dataSource addColumn:aFile withName:@"vignette"];
						[dataSource addColumn:aDesc withName:@"description"];
						[dataSource addColumn:aPath withName:@"path"];
						
						[tableView reloadData];

						int i=0;
						while (i<tl) [a[i++] release];
						free(a);						
					}
				}
			}
			[dim release];				
		}
		[x release];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int sr = [tableView selectedRow];
	[openButton setEnabled: (sr!=-1)];
	if (sr!=-1) {
		[pdfView loadFromPath: [NSString stringWithFormat:@"%@/%@/doc/%@.pdf",
			[dataSource objectAtColumn:@"path" row:sr],
			[dataSource objectAtColumn:@"package" row:sr],
			[dataSource objectAtColumn:@"vignette" row:sr]]
			];
		[pdfDrawer open];
	} else [pdfDrawer close];
}

- (void) showVigenttes
{
	[window makeKeyAndOrderFront:self];
}

- (void) awakeFromNib
{
	SLog(@"VignettesController.awakeFromNib");
	filter=0;
	filterlen=0;
	dataSource=[[SortableDataSource alloc] init];
	[tableView setDataSource: dataSource];
	[self reload];
	[openButton setEnabled: ([tableView selectedRow]!=-1)];
	vignettesSharedController = self;
}

@end
