/* HelpManager */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

#define kExactMatch 0
#define kFuzzyMatch 1

@interface HelpManager : NSObject
{
    IBOutlet NSButton *faqButton;
    IBOutlet WebView *HelpView;
    IBOutlet NSButton *mainButton;
    IBOutlet NSMatrix *matchRadio;
    IBOutlet NSSearchField *searchField;
	IBOutlet NSWindow *helpWindow;
}
- (IBAction)runHelpSearch:(id)sender;
- (IBAction)showMainHelp:(id)sender;
- (IBAction)showRFAQ:(id)sender;
- (IBAction)whatsNew:(id)sender;
- (void)showHelpFor:(NSString *)topic;

+ (id) getHMController;

@end
