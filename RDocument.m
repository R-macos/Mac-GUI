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


#import "RDocument.h"
#import "RDocumentWinCtrl.h"
#import "RController.h"
#import "Preferences.h"

@implementation RDocument

- (id)init
{
    self = [super init];
    if (self) {
		initialContents=nil;
		initialContentsType=nil;
		isEditable=YES;
		isREdit=NO;
    }
    return self;
}

- (void)dealloc {
	if (initialContents) [initialContents release];
	if (initialContentsType) [initialContentsType release];
	[super dealloc];
}

- (void) makeWindowControllers {
	// create RDocumentWinCtr which is a window controller - it loads the corresponding NIB and sets up the window
	RDocumentWinCtrl *cc = [[RDocumentWinCtrl alloc] initWithWindowNibName:@"RDocument"];
	[self addWindowController:cc];
}

- (void) loadInitialContents
{
	if (!initialContents) return;
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while (wc = (RDocumentWinCtrl*)[e nextObject]) { 
		if ([initialContentsType isEqual:@"rtf"])
			[wc replaceContentsWithRtf: initialContents];
		else
			[wc replaceContentsWithString: [NSString stringWithCString:[initialContents bytes] length:[initialContents length]]];
	}
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	
	// Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while (wc = (RDocumentWinCtrl*)[e nextObject]) { 
		if([aType isEqual:@"rtf"])
			return [wc contentsAsRtf];
		else
			return (NSData*) [wc contentsAsString];
	}
	return nil;
}

/* This method is implemented to allow image data file to be loaded into R using open
or drag and drop. In case of a successfull loading of image file, we don't want to
create the UI for the document.
*/
- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType{
	if( [[RController getRController] isImageData:fileName] == 0){
		[[RController getRController] sendInput: [NSString stringWithFormat:@"load(\"%@\")",fileName]];
		[[NSDocumentController sharedDocumentController]  setShouldCreateUI:NO];
		return(YES);
	} else {
		[[NSDocumentController sharedDocumentController]  setShouldCreateUI:YES];
		return( [super readFromFile: fileName ofType: docType] );
	}
}

- (BOOL) loadDataRepresentation: (NSData *)data ofType:(NSString *)aType {
	if (initialContents) {
		[initialContents release];
		initialContents=nil;
	}
	
	initialContentsType = [[NSString alloc] initWithString:aType];
	initialContents = [[NSData alloc] initWithData: data];

	[self loadInitialContents];

	return YES;	
}

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title{
	NSEnumerator *e = [[document windowControllers] objectEnumerator];
	NSWindowController *wc = nil;
	
	while (wc = [e nextObject]) {
		NSWindow *dw = [wc window];
		[dw setTitle: title];
	}
}

- (void) setEditable: (BOOL) editable
{
	isEditable=editable;
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while (wc = (RDocumentWinCtrl*)[e nextObject])
		[wc setEditable: editable];
}

- (BOOL) editable
{
	return isEditable;
}

- (void) setREditFlag: (BOOL) flag
{
	isREdit=flag;
}

- (BOOL) hasREditFlag
{
	return isREdit;
}

@end

