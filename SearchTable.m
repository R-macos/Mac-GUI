#import "SearchTable.h"
#import "RController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

extern int NumOfMatches;
extern char **hs_topic; 
extern char **hs_pkg;
extern char **hs_desc;
extern char **hs_url;


static id sharedHSController;

@implementation SearchTable

- (id)init
{

    self = [super init];
    if (self) {
		sharedHSController = self;
		// Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		    [topicsDataSource setTarget: self];

    }
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return NumOfMatches;
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
		row: (int)row
{
			if([[tableColumn identifier] isEqualToString:@"topic"])
					return [NSString stringWithCString:hs_topic[row]];
			else if([[tableColumn identifier] isEqualToString:@"package"])
					return [NSString stringWithCString:hs_pkg[row]];
			else if([[tableColumn identifier] isEqualToString:@"description"])
					return [NSString stringWithCString:hs_desc[row]];
			else return nil;
				
}



- (IBAction) showInfo:(id)sender
{
	int row = [sender selectedRow];
	if(row < 0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[NSString stringWithCString:hs_url[row]]];
	[[TopicHelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}


- (id) window
{
	return searchTableWindow;
}

+ (id) getHSController{
	return sharedHSController;
}


- (void) doReloadData
{
	[topicsDataSource reloadData];
}

+ (void) reloadData
{
	[[SearchTable getHSController] doReloadData];
	
}

+ (void) toggleHSBrowser:(NSString *)winTitle
{
			[SearchTable reloadData];
			[[[SearchTable getHSController] window] setTitle:winTitle];
			[[[SearchTable getHSController] window] orderFront:self];
}

@end
