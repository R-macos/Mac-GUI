#import "DataManager.h"
#import "RController.h"
#import "REngine.h"

#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

static id sharedDMController;
extern int		NumOfDSets;

extern char **d_name;
extern char **d_pkg;
extern char **d_desc;
extern char **d_url;

@implementation DataManager

- (void)awakeFromNib
{
			[RDataSource setDoubleAction:@selector(loadRData:)];
		    [RDataSource setTarget: sharedDMController];
}

- (id)init
{

    self = [super init];
    if (self) {
		sharedDMController = self;
		// Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
 

	}
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return NumOfDSets;
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
		row: (int)row
{
			if([[tableColumn identifier] isEqualToString:@"data"])
					return [NSString stringWithCString:d_name[row]];
			else if([[tableColumn identifier] isEqualToString:@"package"])
					return [NSString stringWithCString:d_pkg[row]];
			else if([[tableColumn identifier] isEqualToString:@"description"])
					return [NSString stringWithCString:d_desc[row]];
			else return nil;
				
}



- (id) window
{
	return DataManagerWindow;
}

+ (id) getDMController{
	return sharedDMController;
}


- (void) doReloadData
{
	[RDataSource reloadData];
}

+ (void) reloadData
{
	[[DataManager getDMController] doReloadData];
	
}


- (IBAction)loadRData:(id)sender
{
	int row = [sender selectedRow];
	if(row>=0)
//		[[RController getRController] sendInput:[NSString stringWithFormat:@"data(%s,package=\"%s\")",d_name[row],d_pkg[row]]];
	[[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"data(%s,package=\"%s\")",d_name[row],d_pkg[row]]];

}

- (IBAction)showHelp:(id)sender
{
	int row = [sender selectedRow];
	if(row<0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[NSString stringWithCString:d_url[row]]];
	[[dataInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}

+ (void)toggleDataManager
{
			[DataManager reloadData];
			[[[DataManager getDMController] window] orderFront:self];
}

@end
