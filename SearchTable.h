/* SearchTable */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

@interface SearchTable : NSObject
{
	IBOutlet NSTableView *topicsDataSource;	/* TableView for the history */ 
	IBOutlet id TopicHelpView;
	id  searchTableWindow;
}

- (id) window;
- (IBAction) showInfo:(id)sender;
- (void) doReloadData;

+ (void) reloadData;
+ (void) toggleHSBrowser: (NSString *)winTitle;


@end
