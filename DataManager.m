#import "DataManager.h"
#import "RController.h"
#import "REngine.h"

#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

static id sharedController;

@implementation DataManager

- (void)awakeFromNib
{
	[RDataSource setDoubleAction:@selector(loadRData:)];
	[RDataSource setTarget: self];
}

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		datasets = 0;
	}
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

- (void) resetDatasets
{
	if (!datasets) return;
	int i=0;
	while (i<datasets) {
		[dataset[i].name release];
		[dataset[i].desc release];
		[dataset[i].pkg release];
		[dataset[i].url release];
		i++;
	}
	free(dataset);
	datasets=0;
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return datasets;
}

- (void) updateDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url
{
	int i=0;
	
	if (dataset) [self resetDatasets];
	if (count<1) {
		[self show];
		return;
	}
	
	dataset = malloc(sizeof(*dataset)*count);
	while (i<count) {
		dataset[i].name=[[NSString alloc] initWithCString: name[i]];
		dataset[i].desc=[[NSString alloc] initWithCString: desc[i]];
		dataset[i].pkg=[[NSString alloc] initWithCString: pkg[i]];
		dataset[i].url=[[NSString alloc] initWithCString: url[i]];
		i++;
	}
	datasets = count;
	[self show];
}

- (id)tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)tableColumn row: (int)row
{
	if (row>=datasets) return nil;
	if([[tableColumn identifier] isEqualToString:@"data"])
		return dataset[row].name;
	else if([[tableColumn identifier] isEqualToString:@"package"])
		return dataset[row].pkg;
	else if([[tableColumn identifier] isEqualToString:@"description"])
		return dataset[row].desc;
	return nil;
}

- (id) window
{
	return DataManagerWindow;
}

+ (DataManager*) sharedController{
	return sharedController;
}

- (void) reloadData
{
	[RDataSource reloadData];
}

- (IBAction)loadRData:(id)sender
{
	int row = [sender selectedRow];
	if(row>=0)
		[[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"data(%@,package=\"%@\")",dataset[row].name,dataset[row].pkg]];
}

- (IBAction)showHelp:(id)sender
{
	int row = [sender selectedRow];
	if(row<0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",dataset[row].url];
	[[dataInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}

- (int) count
{
	return datasets;
}

- (void) show
{
	[self reloadData];
	[DataManagerWindow makeKeyAndOrderFront:self];
}

@end
