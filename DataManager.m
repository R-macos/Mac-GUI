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
	[RDataSource setDataSource: dataSource];
}

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		dataSource = [[SortableDataSource alloc] init];
	}
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

- (void) resetDatasets
{
	[dataSource reset];
}

- (void) updateDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url
{
	[dataSource reset];
	[dataSource addColumnOfLength:count withCStrings:name name:@"data"];
	[dataSource addColumnOfLength:count withCStrings:desc name:@"description"];
	[dataSource addColumnOfLength:count withCStrings:pkg name:@"package"];
	[dataSource addColumnOfLength:count withCStrings:url name:@"URL"];
	[self show];
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
		[[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"data(%@,package=\"%@\")",
			[dataSource objectAtColumn:@"data" row:row], [dataSource objectAtColumn:@"package" row:row]]];
}

- (IBAction)showHelp:(id)sender
{
	int row = [sender selectedRow];
	if(row<0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[dataSource objectAtColumn:@"URL" row:row]];
	[[dataInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}

- (int) count
{
	return [dataSource count];
}

- (void) show
{
	[self reloadData];
	[DataManagerWindow makeKeyAndOrderFront:self];
}

@end
