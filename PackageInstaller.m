#import "PackageInstaller.h"
#import "RController.h"
#import "RCallbacks.h"
#import "REngine.h"
#import "Authorization.h"

#include <unistd.h>

static id sharedController;

char *location[2] = {"/Library/Frameworks/R.framework/Resources/library/",
	"~/Library/R/library"};

@implementation PackageInstaller


- (IBAction)installSelected:(id)sender
{
	
	char tmp[301];
	if(pkgInst == kOtherLocation){
		NSOpenPanel *op;
		int answer;
		
		op = [NSOpenPanel openPanel];
		[op setCanChooseDirectories:YES];
		[op setCanChooseFiles:NO];
		[op setTitle:@"Select Installation Directory"];
		
		answer = [op runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@""]];
		[op setCanChooseDirectories:NO];
		[op setCanChooseFiles:YES];
		if(answer == NSOKButton) {
			if([op directory] != nil)
				CFStringGetCString((CFStringRef)[op directory], tmp, 300,  kCFStringEncodingMacRoman); 
		} else return;
		
		
	} else
		strcpy(tmp, location[pkgInst]);
	
	{
		char *c;
		FILE *f;
		NSString * s = [NSString stringWithCString:tmp];
		
		s = [s stringByExpandingTildeInPath];
		[s getCString:tmp maxLength:300];
		c = tmp+strlen(tmp);
		
		strcat(tmp, "/.aqua.test");
		f=fopen(tmp, "w");
		if (f) {
			fclose(f);
			unlink(tmp);
		} else {
			if (requestRootAuthorization(0)) {
				NSRunAlertPanel(@"Package Installer",@"The package has not been installed.",@"OK",nil,nil);	
				return;
			} else
				[[RController getRController] setRootFlag:YES];
		}
		*c=0;
	}
	
	if( (pkgUrl == kLocalBin) || (pkgUrl == kLocalSrc) || (pkgUrl == kLocalDir) ){
		
		switch(pkgUrl){
			case kLocalBin:
				[[RController getRController] installFromBinary:self];
				break;
				
			case kLocalSrc:
				[[RController getRController] installFromSource:self];
				break;
				
			case kLocalDir:
				[[RController getRController] installFromDir:self];
				break;
				
			default:
				break;
		}
		
	} else {
		NSIndexSet *rows =  [pkgDataSource selectedRowIndexes];			
		unsigned current_index = [rows firstIndex];
		if(current_index == NSNotFound)
			return;
		
		NSMutableString *packagesToInstall = nil;
		
		packagesToInstall = [[NSMutableString alloc] initWithString: @"c("];
		
		while (current_index != NSNotFound) {
			[packagesToInstall appendFormat:@"\"%@\"",package[current_index].name];
			current_index = [rows indexGreaterThanIndex: current_index];
			if(current_index != NSNotFound)
				[packagesToInstall appendString:@","];
		}
		
		[packagesToInstall appendString:@")"];
		
		switch(pkgUrl){
			
			case kCRANBin:
				[[REngine mainEngine] executeString: 
					[NSString stringWithFormat:@"install.binaries(%@,lib=\"%s\",CRAN=getOption(\"CRAN\"))",
						packagesToInstall,tmp]					
					];
				
				break;
				
			case kCRANSrc:
				[[REngine mainEngine] executeString: 
					[NSString stringWithFormat:@"install.packages(%@,lib=\"%s\",CRAN=getOption(\"CRAN\"))",
						packagesToInstall,tmp]];
				
				break;
				
			case kBIOCBin:
				[[REngine mainEngine] executeString: 
					[NSString stringWithFormat:@"install.binaries(%@,lib=\"%s\",CRAN=getOption(\"BIOC\"))",
						packagesToInstall,tmp]];
				break;
				
			case kBIOCSrc:
				[[REngine mainEngine] executeString: 
					[NSString stringWithFormat:@"install.packages(%@,lib=\"%s\",CRAN=getOption(\"BIOC\"))",
						packagesToInstall,tmp]];
				break;
				
			case kOTHER:
				if(pkgFormat == kSource)
					[[REngine mainEngine] executeString: 
						[NSString stringWithFormat:@"install.packages(%@,lib=\"%s\",contriburl=\"%@\")",
							packagesToInstall,tmp,[urlTextField stringValue]]];
			else
				[[REngine mainEngine] executeString: 
					[NSString stringWithFormat:@"install.binaries(%@,lib=\"%s\",contriburl=\"%@\")",
						packagesToInstall,tmp,[urlTextField stringValue]]];
			break;

			default:
				break;
		}

		[packagesToInstall release];
	}
}


- (IBAction)reloadURL:(id)sender
{
	//	NSLog(@"pkgUrl=%d, pkgInst=%d, pkgFormat:%d",pkgUrl, pkgInst, pkgFormat);
	
	[pkgDataSource deselectAll:self];
	[pkgDataSource setHidden:YES];
	
	switch(pkgUrl){
		
		case kCRANBin:
			[[REngine mainEngine] executeString: 
				@"browse.pkgs(\"CRAN\",\"binary\")"];
			break;
			
		case kCRANSrc:
			[[REngine mainEngine] executeString: 
				@"browse.pkgs(\"CRAN\",\"source\")"];
			break;
			
		case kBIOCBin:
			[[REngine mainEngine] executeString: 
				@"browse.pkgs(\"BIOC\",\"binary\")"];
			break;
			
		case kBIOCSrc:
			[[REngine mainEngine] executeString: 
				@"browse.pkgs(\"BIOC\",\"source\")"];
			break;
			
		case kOTHER:
			if( [[urlTextField stringValue] isEqual:@""]){
				NSBeginAlertSheet(@"Package installer",@"Ok",nil,nil,[self window],self,NULL,NULL,NULL,@"Please, specify a valid url first.");
				return;
			}
			
			[[REngine mainEngine] executeString: 
				[NSString stringWithFormat:@"browse.pkgs(contriburl=\"%@\")",[urlTextField stringValue]]];
			break;
			
		default:
			break;
			
	}
}

- (IBAction)setURL:(id)sender
{
	pkgUrl = [[ sender selectedCell] tag];
	[pkgDataSource setHidden:YES];
	
	switch(pkgUrl){
		
		
		case kCRANBin:
		case kBIOCBin:
			pkgFormat = kBinary;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setEnabled:NO];
			[getListButton setEnabled:YES];
			break;
			
		case kCRANSrc:
		case kBIOCSrc:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setEnabled:NO];
			[getListButton setEnabled:YES];
			break;
			
		case kOTHER:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:YES];
			[urlTextField setEnabled:YES];
			[getListButton setEnabled:YES];
			break;
			
		case kLocalBin:
			pkgFormat = kBinary;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[getListButton setEnabled:NO];
			break;
			
		case kLocalSrc:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[getListButton setEnabled:NO];
			break;
			
		case kLocalDir:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[getListButton setEnabled:NO];
			break;
			
		default:
			break;
	}
}

- (IBAction)setLocation:(id)sender
{
	pkgInst = [[ sender selectedCell] tag];
}

- (IBAction)setFormat:(id)sender
{
	pkgFormat = [[ sender selectedCell] state];
}

- (void)awakeFromNib
{
	[formatCheckBox setEnabled:NO];
	[urlTextField setEnabled:NO];
	pkgInst = kUserLevel;
	pkgUrl = kCRANBin;
	pkgFormat = kBinary;
	[formatCheckBox setState:pkgFormat];
	[repositoryButton setTag:pkgUrl];
	[locationMatrix setTag:pkgInst];
}

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		[pkgDataSource setTarget: self];
		packages = 0;
    }
	
    return self;
}

- (void)dealloc {
	[self resetPackages];
	[super dealloc];
}

- (void) resetPackages
{
	if (!packages) return;
	int i=0;
	while (i<packages) {
		[package[i].name release];
		[package[i].iver release];
		[package[i].rver release];
		i++;
	}
	free(package);
	packages=0;
}

- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return packages;
}

- (id)tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)tableColumn row: (int)row
{
	if (row>=packages) return nil;
	if([[tableColumn identifier] isEqualToString:@"package"])
		return package[row].name;
	else if([[tableColumn identifier] isEqualToString:@"instVer"])
		return package[row].iver;
	else if([[tableColumn identifier] isEqualToString:@"repVer"])
		return package[row].rver;
	return nil;				
}

- (id) window
{
	return pkgWindow;
}

+ (id) sharedController {
	return sharedController;
}

- (IBAction) reloadPIData:(id)sender
{
	//	[[RController getRController] sendInput:@"package.manager()"];
	[pkgDataSource reloadData];
}

- (void) reloadData
{
	[pkgDataSource setHidden:NO];
	[pkgDataSource reloadData];
}

- (void) show
{
	[self reloadData];
	[[self window] makeKeyAndOrderFront:self];
}

- (void) updateInstalledPackages: (int) count withNames: (char**) name installedVersions: (char**) iver repositoryVersions: (char**) rver update: (BOOL*) stat label: (char*) label
{
	int i=0;
	
	if (packages) [self resetPackages];
	if (count<1) {
		[self show];
		return;
	}

	if (label) repositoryLabel = [NSString stringWithCString: label];
	
	package = malloc(sizeof(*package)*count);
	while (i<count) {
		package[i].name=[[NSString alloc] initWithCString: name[i]];
		package[i].iver=[[NSString alloc] initWithCString: iver[i]];
		package[i].rver=[[NSString alloc] initWithCString: rver[i]];
		package[i].status=stat[i];
		i++;
	}
	packages=count;
	
	[self show];
}

@end
