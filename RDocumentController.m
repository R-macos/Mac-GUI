/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *                     RDocumentController written by Rob Goedman
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

#import "RDocumentController.h"
#import "RController.h"
#import "Preferences.h"
#import "PreferenceKeys.h"

#define defaultDocumentType @"Rsource"

@implementation RDocumentController

- (id)init {
	self = [super init];
	return self;
}

- (IBAction)newDocument:(id)sender {
	[self openNamedFile:@"" display:YES];
}

- (IBAction)openDocument:(id)sender {
	NSArray *files = [super fileNamesFromRunningOpenPanel];
	int i = [files count];
	int j;
	for (j=0;j<i;j++) {
		[self openDocumentWithContentsOfFile: [files objectAtIndex:j] display:YES];	
	}
}

- (id)openDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag
{
	int res = [[RController getRController] isImageData: aFile];
	if (res == -1)
		NSLog(@"File format: %@ not recognized by isImageData", aFile);
	else 
		if (res == 0 )
			[[RController getRController] sendInput: [NSString stringWithFormat:@"load(\"%@\")", aFile]];
	else 
		[self openNamedFile: aFile display:flag];
	return 0;
}

/* 
	Below is the path taken by drag & drop on the R icon, by New Document and by Open
	Document. If edit is selected in MiscPrefPane, the file is opened in either the
	internal or external editor (selected in the EditorPrefPane). If source is selected
	in MiscPrefPane, an existing file is sourced into R. A new file opens a new document.
*/


- (id) openNamedFile:(NSString *)aFile display:(BOOL) flag
{
	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	BOOL openInEditor = [Preferences flagForKey:editOrSourceKey withDefault: YES];
	NSString *externalEditor = [Preferences stringForKey:externalEditorNameKey withDefault: @"TextEdit"];
	BOOL editorIsApp = [Preferences flagForKey:appOrCommandKey withDefault: YES];
	NSString *cmd;
	if ([aFile isEqualToString:@""] || openInEditor) {
		if ([aFile isEqualToString:@""] && useInternalEditor)
			return [super openUntitledDocumentOfType:defaultDocumentType display:YES];
		else
			if (useInternalEditor) 
				return [super openDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag];
		if (editorIsApp) {
			cmd = [@"open -a " stringByAppendingString:externalEditor];
			if (![aFile isEqualToString:@""])
				cmd = [cmd stringByAppendingString: [NSString stringWithFormat:@" \"%@\"", aFile]];
		} else {
			cmd = externalEditor; 
			if (![aFile isEqualToString:@""])
				cmd = [cmd stringByAppendingString: [NSString stringWithString: [NSString stringWithFormat:@" \"%@\"", aFile]]];
		}
		system([cmd UTF8String]);		
	} else 
		[[RController getRController] sendInput:[NSString stringWithFormat:@"source(\"%@\")",aFile]];
	return 0;
}

/* 
	Below is the path taken by callbacks from R like edit(object) or edit(file="/Users/...")
    If the internal editor is used, R is kept in modal mode and after editing, the file content
    is returned, e.g. to be assigned as in x = edit(x). If an external editor is selected,
    the editor is opened and R displays the old content and is ready for input. The selection
    of source or edit has no influence.
*/

- (id)openRDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag
{
	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	NSString *externalEditor = [Preferences stringForKey:externalEditorNameKey withDefault: @"SubEthaEdit"];
	BOOL editorIsApp = [Preferences flagForKey:appOrCommandKey withDefault: YES];

	if (useInternalEditor) {
		NSLog(@" ");	// Weirdness - crashes in CFRetain if not here
		return [super openDocumentWithContentsOfFile:aFile display:flag];		
	} else {
		NSString *cmd;
		if (editorIsApp) {
			cmd = [@"open -a " stringByAppendingString:externalEditor];
			if (![aFile isEqualToString:@""])
				cmd = [cmd stringByAppendingString: [NSString stringWithFormat:@" \"%@\"", aFile]];
		} else {
			cmd = externalEditor; 
			if (![aFile isEqualToString:@""])
				cmd = [cmd stringByAppendingString: [NSString stringWithString: [NSString stringWithFormat:@" \"%@\"", aFile]]];
		}
		system([cmd UTF8String]);
		return 0;
	}
}

@end
