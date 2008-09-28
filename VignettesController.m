#import "VignettesController.h"

#import "REngine/REngine.h"
#import "REngine/RSEXP.h"

/* for pre-10.5 compatibility */
#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#define NSINTEGER_DEFINED 1
#endif

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
		NSString *cmd = [NSString stringWithFormat:@"open \"%@/%@/doc/%@.pdf\"",
			[dataSource objectAtColumn:@"path" row:sr],
			[dataSource objectAtColumn:@"package" row:sr],
			[dataSource objectAtColumn:@"vignette" row:sr]];
		SLog(@"VignettesController.openVignette executing: %@", cmd);
		system([cmd UTF8String]);
	}
}

- (IBAction)openVignetteSource:(id)sender
{
	int sr = [tableView selectedRow];
	if (sr>=0) {
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"edit(vignette(\"%@\", package=\"%@\"))",
			[dataSource objectAtColumn:@"vignette" row:sr],
			[dataSource objectAtColumn:@"package" row:sr]
			]];
	}
}

- (void) runFilter: (NSString*) filterString
{
	SLog(@"VignettesController.reRunFilter (search string is %@)",filterString?filterString:@"<none>");
	
	NSIndexSet *preIx = [tableView selectedRowIndexes];
	NSMutableIndexSet *postIx = [[NSMutableIndexSet alloc] init];
	NSMutableIndexSet *absSelIx = [[NSMutableIndexSet alloc] init];
	NSUInteger i=0;
	
	if ([preIx count]>0) { // save selection in absolute index positions
		i = [preIx firstIndex];
		do {
			if (!filter || i<filterlen)
				[absSelIx addIndex:filter?filter[i]:i];
			i = [preIx indexGreaterThanIndex:i];
		} while (i != NSNotFound);
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
	needReload = NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int sr = [tableView selectedRow];
	[openButton setEnabled: (sr!=-1)];
	[openSourceButton setEnabled: (sr!=-1)];
	if (sr!=-1) {
		NSString *pdfFile = [NSString stringWithFormat:@"%@/%@/doc/%@.pdf",
			[dataSource objectAtColumn:@"path" row:sr],
			[dataSource objectAtColumn:@"package" row:sr],
			[dataSource objectAtColumn:@"vignette" row:sr]];
		SLog(@"VignettesController.tableViewSelectionDidChange: previewing %@", pdfFile);
		if ([[NSFileManager defaultManager] fileExistsAtPath:pdfFile]) {
			[pdfView loadFromPath: pdfFile];
			[pdfDrawer open];
		} else {
			[pdfDrawer close];
			[openButton setEnabled:NO];
		}
	} else [pdfDrawer close];
}

- (void) showVigenttes
{
	if (needReload)
		[self reload];
	[window makeKeyAndOrderFront:self];
}

- (void) awakeFromNib
{
	SLog(@"VignettesController.awakeFromNib");
	filter=0;
	filterlen=0;
	dataSource=[[SortableDataSource alloc] init];
	[tableView setDataSource: dataSource];
	[tableView setDoubleAction:@selector(openVignette:)];
	[tableView setTarget:self];
	// deferred loading of vignettes
	//[self reload];
	needReload = YES;
	[openButton setEnabled: ([tableView selectedRow]!=-1)];
	[openSourceButton setEnabled: ([tableView selectedRow]!=-1)];
	vignettesSharedController = self;
}

@end
