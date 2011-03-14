/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
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


#import "RGUI.h"
#import "RDocument.h"
#import "RDocumentController.h"
#import "RDocumentWinCtrl.h"
#import "RController.h"
#import "Preferences.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif

@implementation RDocument

- (id)init
{
    self = [super init];
    if (self) {
		SLog(@"RDocument(%@) init", self);
	    documentEncoding = NSUTF8StringEncoding;
		initialContents=nil;
		initialContentsType=nil;
		isEditable=YES;
		isREdit=NO;
		myWinCtrl=nil;
    }
    return self;
}

- (void)close {
	SLog(@"RDocument.close <%@> (wctrl=%@)", self, myWinCtrl);
	if (initialContents) [initialContents release], initialContents=nil;
	if (initialContentsType) [initialContentsType release], initialContentsType=nil;
	if (myWinCtrl) {
		SLog(@" - window: %@", [myWinCtrl window]);
		[self removeWindowController:myWinCtrl];
		[myWinCtrl close];
		// --- something is broken - winctrl close doesn't work - I have no idea why - this is a horrible hack to cover up
		//NSWindow *w = [myWinCtrl window];
		//if (w) [NSApp removeWindowsItem: w];
		//[[(RDocumentController*)[NSDocumentController sharedDocumentController] walkKeyListBack] makeKeyAndOrderFront:self];
		// --- end of hack
		[myWinCtrl release];
		myWinCtrl=nil;
	}
	
	[super close];
}

- (void)dealloc {
	if (myWinCtrl) [self close];
	[super dealloc];
}

// FIXME: I don't like this - we should use common text storage instead; conceptually textView is NOT the storage part
- (NSTextView *)textView {
	return [myWinCtrl textView];
}

- (void) makeWindowControllers {
	SLog(@"RDocument.makeWindowControllers: creating RDocumentWinCtrl");
	if (myWinCtrl) {
		SLog(@"*** RDocument.makeWindowControllers: my assumption is that I have only one win controller, but I already have %@! I'll autorelease the first one but won't detach it - don't blame me if this crashes...", myWinCtrl);
		[myWinCtrl autorelease];
	}
	// create RDocumentWinCtrl which is a window controller - it loads the corresponding NIB and sets up the window
	myWinCtrl = [[RDocumentWinCtrl alloc] initWithWindowNibName:@"RDocument"];
	[self addWindowController:myWinCtrl];
	
}

- (NSString*)windowNibName
{
	return @"RDocument";
}

- (int) fileEncoding
{
	return (int) documentEncoding;
}

- (void) setFileEncoding: (int) encoding
{
	SLog(@" - setFileEncoding: %d", encoding);
	documentEncoding = (NSStringEncoding) encoding;
}

- (void)didSaveSelector
{
	// Remain focus on current document after closing SaveAs panel
	[[myWinCtrl window] makeKeyWindow];
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	// dispatch didSaveSelector: in order to remain input focus to current document
	[super runModalSavePanelForSaveOperation:saveOperation delegate:self didSaveSelector:@selector(didSaveSelector) contextInfo:contextInfo];
}

// customize Save panel by adding "encoding" view
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	if (myWinCtrl)
		[savePanel setAccessoryView:[myWinCtrl saveOpenAccView]];
	return YES;
}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)docType {
	SLog(@"RDocument.writeToFile: %@ ofType: %@", fileName, docType);
	return [super writeToFile:fileName ofType:docType];
}

- (void) loadInitialContents
{

	if (!initialContents) {
		SLog(@"RDocument.loadInitialContents: empty contents, skipping");
		return;
	}
	
	SLog(@"RDocument.loadInitialContents: loading");
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject])) { 
		if ([initialContentsType isEqual:@"rtf"]) {
			SLog(@" - new RTF contents (%d bytes) for window controller %@", [initialContents length], wc);
			[wc replaceContentsWithRtf: initialContents];
		} else {
			const unsigned char *ic = [initialContents bytes];
			documentEncoding = NSUTF8StringEncoding;
			if ([initialContents length] > 1 
					&& ((ic[0] == 0xff && ic[1] == 0xfe) || (ic[0] == 0xfe && ic[1] == 0xff))) // Unicode BOM
				documentEncoding = NSUnicodeStringEncoding;

			NSString *cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
			if(!cs && [self fileURL]) {
				SLog(@" - failed to load as %d encoding, try to autodetect via initWithContentsOfURL:documentEncoding:error:", documentEncoding);
				cs = [[NSString alloc] initWithContentsOfURL:[self fileURL] usedEncoding:&documentEncoding error:nil];
			}
			if (!cs) { // fall back to Latin1 since it's widely used
				SLog(@" - failed to load as %d encoding, falling back to Latin1", documentEncoding);
				documentEncoding = NSISOLatin1StringEncoding;
				cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
			}
			if (!cs) { // fall back to MacRoman - old default
				SLog(@" - failed to load as %d encoding, falling back to MacRoman", documentEncoding);
				documentEncoding = NSMacOSRomanStringEncoding;
				cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
			}
			if (cs) {
				SLog(@" - new string contents (%d chars) for window controller %@", [cs length], wc);
				// Important! otherwise the save box won't know
				[wc setFileEncoding:documentEncoding];
				[wc replaceContentsWithString:cs];
			}
			[cs release];
		}
	}

	// release initialContents to clean heap esp. for large files
	if(initialContents) [initialContents release], initialContents=nil;

}

- (void) reinterpretInEncoding: (NSStringEncoding) encoding
{
	NSString *sc = [myWinCtrl contentsAsString];
	NSData *data = [sc dataUsingEncoding:documentEncoding];
	NSString *ns = [[NSString alloc] initWithData:data encoding:encoding];
	if (!ns) {
		[ns release];
		// TODO: alert: invalid in that encoding
		return;
	}
	documentEncoding = encoding;
	[myWinCtrl setFileEncoding:documentEncoding];
	[myWinCtrl replaceContentsWithString:ns];
	[ns release];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	
	// Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject])) { 
		if([aType isEqual:@"rtf"])
			return [wc contentsAsRtf];
		else
			return [[wc contentsAsString] dataUsingEncoding: documentEncoding];
	}
	return nil;
}

/* This method is implemented to allow image data file to be loaded into R using open
or drag and drop. In case of a successfull loading of image file, we don't want to
create the UI for the document.
*/
- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType{
	if( [docType isEqual:@"R Data File"] || [[RController sharedController] isImageData:fileName] == 0){
		[[RController sharedController] sendInput: [NSString stringWithFormat:@"load(\"%@\")",fileName]];
		// [[NSDocumentController sharedDocumentController]  setShouldCreateUI:NO];
		return(YES);
	} else {
		// [[NSDocumentController sharedDocumentController] setShouldCreateUI:YES];
		return( [super readFromFile: fileName ofType: docType] );
	}
}

- (BOOL) loadDataRepresentation: (NSData *)data ofType:(NSString *)aType {

	if (initialContents) [initialContents release], initialContents=nil;
	if (initialContentsType) [initialContentsType release], initialContentsType = nil;

	initialContentsType = [[NSString alloc] initWithString:aType];

	initialContents = [data retain];

	SLog(@"RDocument.loadDataRepresentation loading %d bytes of data", [data length]);

	return YES;
}

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title{
	NSEnumerator *e = [[document windowControllers] objectEnumerator];
	NSWindowController *wc = nil;
	
	while ((wc = [e nextObject])) {
		NSWindow *dw = [wc window];
		[dw setTitle: title];
	}
}

- (void) setEditable: (BOOL) editable
{
	isEditable=editable;
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject]))
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

