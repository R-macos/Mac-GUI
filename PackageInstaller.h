/* PackageInstaller */


#define kSystemLevel	0
#define kUserLevel		1
#define kOtherLocation  2

#define kCRANBin	0
#define kCRANSrc	1
#define kBIOCBin	2
#define kBIOCSrc	3
#define kOTHER		4
#define kLocalBin   5
#define kLocalSrc   6
#define kLocalDir   7

#define kBinary		1
#define kSource		0

#import <Cocoa/Cocoa.h>

@interface PackageInstaller : NSObject
{
    IBOutlet NSTableView *pkgDataSource;
    IBOutlet id pkgWindow;
	IBOutlet NSButton *getListButton;
    IBOutlet NSPopUpButton *repositoryButton;
	IBOutlet NSButton *formatCheckBox;
    IBOutlet NSMatrix *locationMatrix;
    IBOutlet NSTextField *urlTextField;
	int pkgUrl;
	int pkgInst;
	int pkgFormat;
}

- (IBAction)installSelected:(id)sender;
- (IBAction)reloadURL:(id)sender;
- (IBAction) reloadPIData:(id)sender;

- (IBAction)setURL:(id)sender;
- (IBAction)setLocation:(id)sender;
- (IBAction)setFormat:(id)sender;

- (id) window;
- (void) doReloadData;

+ (id) getPIController;
+ (void) reloadData;
+ (void)togglePackageInstaller;

@end
