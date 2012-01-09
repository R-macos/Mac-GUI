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
#import "RChooseEncodingPopupAccessory.h"
#import "REngine.h"
#import "HelpManager.h"

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
	encodingPopUp = nil;
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	// dispatch didSaveSelector: in order to remain input focus to current document
	[super runModalSavePanelForSaveOperation:saveOperation delegate:self didSaveSelector:@selector(didSaveSelector) contextInfo:contextInfo];
}

// customize Save panel by adding "encoding" view for R documents
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{

	if(initialContentsType == nil || (initialContentsType && [initialContentsType isEqualToString:ftRSource])) {
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"R"]];
		if (myWinCtrl)
			[savePanel setAccessoryView:[[[NSDocumentController sharedDocumentController] class] encodingAccessory:(NSStringEncoding)documentEncoding 
																							   includeDefaultEntry:NO 
																									 encodingPopUp:&encodingPopUp]];
		if(encodingPopUp) [encodingPopUp setEnabled:YES];
		[savePanel setAllowsOtherFileTypes:YES];
	}
	else if(initialContentsType && [initialContentsType hasSuffix:@".rtf"]) {
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"rtf"]];
		[savePanel setAllowsOtherFileTypes:NO];
		[savePanel setAccessoryView:nil];
	}

	[savePanel setCanSelectHiddenExtension:YES];

	return YES;

}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)docType {

	SLog(@"RDocument.writeToFile: %@ ofType: %@ ", fileName, docType);

	if([[fileName lowercaseString] hasSuffix:@".rtf"]) {
		SLog(@" - docType was changed to rtf due to file extension");
		if(initialContentsType) [initialContentsType release], initialContentsType = nil;
		initialContentsType = [[NSString stringWithString:@"public.rtf"] retain];
	}

	SLog(@" - used docType %@", (initialContentsType)?:ftRSource);

	return [super writeToFile:fileName ofType:(initialContentsType)?:ftRSource];

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
		if ([initialContentsType hasSuffix:@".rtf"]) {
			SLog(@" - new RTF contents (%d bytes) for window controller %@", [initialContents length], wc);
			[wc replaceContentsWithRtf: initialContents];
		} else {
			const unsigned char *ic = [initialContents bytes];
			NSString *cs;
			SLog(@" - try to auto-detect file encoding");
			documentEncoding = NSUTF8StringEncoding;
			if ([initialContents length] > 1 
					&& ((ic[0] == 0xff && ic[1] == 0xfe) || (ic[0] == 0xfe && ic[1] == 0xff))) // Unicode BOM
				documentEncoding = NSUnicodeStringEncoding;

			cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
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
				if(![initialContentsType isEqualToString:ftRSource] && ![initialContentsType isEqualToString:ftRdDoc]) {
					SLog(@" - set plain text mode");
					[wc setPlain:YES];
				}
				[wc replaceContentsWithString:cs];
			}
			[cs release];
		}
	}

	// release initialContents to clean heap esp. for large files
	if(initialContents) [initialContents release], initialContents=nil;

}
- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{

	SLog(@"RDocument:revertToContentsOfURL %@ of type %@", absoluteURL, typeName);

	if([typeName hasSuffix:@".rtf"]) {
		NSData *cs = [[NSData alloc] initWithContentsOfURL:absoluteURL];
		if(cs) {
			[myWinCtrl replaceContentsWithRtf:cs];
			[cs release];

			// Remain focus
			[[myWinCtrl window] makeKeyWindow];
			// Clear edited status
			[self updateChangeCount:NSChangeCleared];
			return YES;
		}
	} else {
		NSString *cs = [[NSString alloc] initWithContentsOfURL:absoluteURL encoding:documentEncoding error:nil];
		if(cs) {
			[myWinCtrl replaceContentsWithString:cs];
			[cs release];

			// Remain focus
			[[myWinCtrl window] makeKeyWindow];
			// Clear edited status
			[self updateChangeCount:NSChangeCleared];
			return YES;
		}
	}

	SLog(@" - couldn't revert document");

	NSBeginAlertSheet(NLS(@"Reverting Document"), NLS(@"OK"), nil, nil,
		[myWinCtrl window], self,
		@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
		NLS(@"Couldn't revert to saved document"));

	outError = nil;

	return YES;

}


- (void) reinterpretInEncoding: (NSStringEncoding) encoding
{
	SLog(@"RDocument:reinterpretInEncoding - new encoding: %ld", encoding);

	NSString *sc = [myWinCtrl contentsAsString];

	NSData *data = [sc dataUsingEncoding:documentEncoding allowLossyConversion:YES];
	if(!data) {
		NSBeginAlertSheet(NLS(@"Convertion Error"), NLS(@"OK"), nil, nil,
			[myWinCtrl window], self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
			[NSString stringWithFormat:@"%@ %@", NLS(@"Couldn't reinterpret the text by using the encoding"), 
				[NSString localizedNameOfStringEncoding:encoding]]);
		SLog(@"- can't get data");
		return;
	}

	NSString *ns = [[NSString alloc] initWithData:data encoding:encoding];
	if (!ns) {
		[ns release];
		NSBeginAlertSheet(NLS(@"Convertion Error"), NLS(@"OK"), nil, nil,
			[myWinCtrl window], self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
			[NSString stringWithFormat:@"%@ %@", NLS(@"Couldn't reinterpret the text by using the encoding"), 
				[NSString localizedNameOfStringEncoding:encoding]]);
		SLog(@" - can't create string");
		return;
	}

	// Check for any non-valid (surrogate issues esp. if UTF16 is chosen)
	if ([ns UTF8String] == NULL) {
		[ns release];
		NSBeginAlertSheet(NLS(@"Convertion Error"), NLS(@"OK"), nil, nil,
			[myWinCtrl window], self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
			[NSString stringWithFormat:@"%@ %@", NLS(@"Couldn't reinterpret the text by using the encoding"), 
				[NSString localizedNameOfStringEncoding:encoding]]);
		SLog(@" - string contains invalid bytes for chosen encoding");
		return;
	}

	documentEncoding = encoding;
	[myWinCtrl setFileEncoding:documentEncoding];

	// replace text in such a way that the user can perform undo:
	[[myWinCtrl textView] selectAll:nil];
	[[myWinCtrl textView] insertText:ns];

	[ns release];

}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	if(encodingPopUp) {
		[[NSUserDefaults standardUserDefaults] setInteger:[[[encodingPopUp selectedItem] representedObject] unsignedIntegerValue] forKey:lastUsedFileEncoding];
		documentEncoding = (NSStringEncoding)[[[encodingPopUp selectedItem] representedObject] unsignedIntegerValue];
	}

	encodingPopUp = nil;

	// Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject])) { 
		if([aType hasSuffix:@".rtf"])
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

- (BOOL) loadDataRepresentation: (NSData *)data ofType:(NSString *)aType{

	if (initialContents) [initialContents release], initialContents=nil;
	if (initialContentsType) [initialContentsType release], initialContentsType = nil;

	initialContentsType = [[NSString alloc] initWithString:aType];

	initialContents = [data retain];

	SLog(@"RDocument.loadDataRepresentation loading %d bytes of data and docType %@", [data length], initialContentsType);

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

- (NSString *)displayName
{
	if(isREdit) return NLS(@"Object Editor");
	return [super displayName];
}

- (BOOL) isRTF
{
	return (([self fileName] && [[[self fileName] lowercaseString] hasSuffix:@".rtf"]) || ([self fileType] && [[self fileType] hasSuffix:@".rtf"]));
}

- (BOOL) convertRd2HTML
{

	REngine *re = [REngine mainEngine];

	NSString *tempName = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%.0f.", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
	NSString *RhomeCSS = @"R.css";
	RSEXP *xx = [re evaluateString:@"R.home()"];
	if(xx) {
		NSString *Rhome = [xx string];
		if(Rhome) {
			RhomeCSS = [NSString stringWithFormat:@"file://%@/doc/html/R.css", Rhome];
		}
		[xx release];
	}
	

	NSError *error;
	NSString *inputFile = [NSString stringWithFormat: @"%@%@", tempName, @"rd"];
	NSString *htmlOutputFile = [NSString stringWithFormat: @"%@%@", tempName, @"html"];
	NSString *errorOutputFile = [NSString stringWithFormat: @"%@%@", tempName, @"txt"];

	NSURL *htmlOutputFileURL = [NSURL URLWithString:htmlOutputFile];

	[[[myWinCtrl textView] string] writeToFile:inputFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

	NSString *convCmd = [NSString stringWithFormat:@"system(\"R CMD Rdconv -t html '%@' 2> '%@' | perl -pe 's!R.css!%@!'> '%@'\", intern=TRUE, wait=TRUE)", inputFile, errorOutputFile, RhomeCSS, htmlOutputFile];

	if (![re beginProtected]) {
		SLog(@"RDocument.convertRd2HTML bailed because protected REngine entry failed [***]");
		return NO;
	}
	xx = [re evaluateString:convCmd];
	[re endProtected];
	if(xx) {
		[xx release];
		NSString *errMessage = [[NSString alloc] initWithContentsOfFile:errorOutputFile encoding:NSUTF8StringEncoding error:nil];
		if(errMessage && [errMessage length]) {

			errMessage = [errMessage stringByReplacingOccurrencesOfString:inputFile withString:@"Rd file"];

			NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Rd convertion warnings") 
					defaultButton:NLS(@"OK") 
					alternateButton:nil 
					otherButton:nil 
					informativeTextWithFormat:errMessage];

			[alert setAlertStyle:NSWarningAlertStyle];
			[alert runModal];

		}

		[[HelpManager sharedController] showHelpFileForURL:htmlOutputFileURL];

		if (![re beginProtected]) {
			SLog(@"RDocument.convertRd2HTML bailed because protected REngine entry failed for removing temporary files[***]");
			return NO;
		}
		// After 200 secs all temporary files will be deleted even if R was quitted meanwhile
		[re executeString:[NSString stringWithFormat:@"system(\"sleep 200 && rm -f '%@' && rm -f '%@' && rm -f '%@'\", wait=FALSE)", inputFile, htmlOutputFile, errorOutputFile]];
		[re endProtected];

		return YES;
	}

	return NO;

}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString*)contextInfo
{
	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	// Set the input focus to the last doc after closing a sheet
	[[(RDocumentController*)[NSDocumentController sharedDocumentController] findLastWindowForDocType:ftRSource] makeKeyAndOrderFront:nil];

}

@end

