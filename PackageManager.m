#import "PackageManager.h"
#import "RController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>
#import "REngine.h"

extern  int NumOfAllPkgs;
extern char **p_name;
extern char **p_desc;
extern char **p_url;
extern BOOL *p_stat;


static id sharedPMController;

@implementation PackageManager

- (id)init
{

    self = [super init];
    if (self) {
		sharedPMController = self;
		// Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		    [packageDataSource setTarget: self];

    }
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return NumOfAllPkgs;
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
		row: (int)row
{
			if([[tableColumn identifier] isEqualToString:@"status"])
					return [NSNumber numberWithBool: p_stat[row]];
			else if([[tableColumn identifier] isEqualToString:@"package"])
					return [NSString stringWithCString:p_name[row]];
			else if([[tableColumn identifier] isEqualToString:@"description"])
					return [NSString stringWithCString:p_desc[row]];
			else return nil;
				
}



- (void)tableView:(NSTableView *)tableView
	setObjectValue:(id)object
	forTableColumn:(NSTableColumn *)tableColumn
	row:(int)row
{
	if([[tableColumn identifier] isEqualToString:@"status"]){
		if ([object boolValue] == NO) {
//			[[RController getRController] sendInput:[NSString stringWithFormat:@"detach(\"package:%s\")",p_name[row]]];
			if ([[REngine mainEngine] executeString:[NSString stringWithFormat:@"detach(\"package:%s\")",p_name[row]]])
				p_stat[row] = 0;
		} else {
//			[[RController getRController] sendInput:[NSString stringWithFormat:@"library(%s)",p_name[row]]];
			if ([[REngine mainEngine] executeString:[NSString stringWithFormat:@"library(%s)",p_name[row]]])
				p_stat[row] = 1;
		}
	} 

}


- (IBAction) showInfo:(id)sender
{
	int row = [sender selectedRow];
	if(row < 0) return;
	NSString *urlText = [NSString stringWithFormat:@"file://%@",[NSString stringWithCString:p_url[row]]];
	[[PackageInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}


- (id) window
{
	return PackageManagerWindow;
}

+ (id) getPMController{
	return sharedPMController;
}

- (IBAction) reloadPMData:(id)sender
{
//	[[RController getRController] sendInput:@"package.manager()"];
	[[REngine mainEngine] executeString:@"package.manager()"];
	[packageDataSource reloadData];
}

- (void) doReloadData
{
	[packageDataSource reloadData];
}

+ (void) reloadData
{
	[[PackageManager getPMController] doReloadData];
	
}

+ (void)togglePackageManager
{
			[PackageManager reloadData];
			[[[PackageManager getPMController] window] orderFront:self];
}

@end
