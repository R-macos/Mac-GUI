/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *
 *                  
 *  R Copyright notes:
 *                     Copyright (C) 1995-1996   Robert Gentleman and Ross Ihaka
 *                     Copyright (C) 1998-2001   The R Development Core Team
 *                     Copyright (C) 2002-2004   The R Foundation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  A copy of the GNU General Public License is available via WWW at
 *  http://www.gnu.org/copyleft/gpl.html.  You can also obtain it by
 *  writing to the Free Software Foundation, Inc., 59 Temple Place,
 *  Suite 330, Boston, MA  02111-1307  USA.
 */

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

typedef struct pkgInstallerEntry {
	NSString *name;
	NSString *iver;
	NSString *rver;
	BOOL status;
} s_pkgInstallerEntry;

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
	
	int packages;
	s_pkgInstallerEntry *package;
	NSString *repositoryLabel;
}

- (IBAction)installSelected:(id)sender;
- (IBAction)reloadURL:(id)sender;
- (IBAction) reloadPIData:(id)sender;

- (IBAction)setURL:(id)sender;
- (IBAction)setLocation:(id)sender;
- (IBAction)setFormat:(id)sender;

- (id) window;
- (void) reloadData;
- (void) resetPackages;

- (void) show;
- (void) updateInstalledPackages: (int) count withNames: (char**) name installedVersions: (char**) iver repositoryVersions: (char**) rver update: (BOOL*) stat label: (char*) label;

+ (id) sharedController;

@end
