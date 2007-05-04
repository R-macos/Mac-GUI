/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
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

#import "RGUI.h"
#import "RDocumentController.h"
#import "RController.h"
#import "Preferences.h"
#import "PreferenceKeys.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif

@interface RDocumentController (Private)
int docListLimit = 128; // limit for the number of transitions stored
int docListPos = 0; // active position in the list
NSDocument **docList; // list of activated documents
NSDocument *mainDoc; // dummy document representing the main R window in the list
@end


@implementation RDocumentController

- (id)init {
	self = [super init];
	SLog(@"RDocumentController%@.init", self);
	mainDoc = [[NSDocument alloc] init];
	docList = (NSDocument**) malloc(sizeof(NSDocument*) * docListLimit);
	memset(docList, 0, sizeof(NSDocument*) * docListLimit);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotifications:) name:NSWindowDidBecomeKeyNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillCloseNotifications:) name:NSWindowWillCloseNotification object:nil];
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	free(docList);
	[mainDoc release];
	[super dealloc];
}

- (void)windowWillCloseNotifications:(NSNotification*) aNotification
{
	NSWindow *w = [aNotification object];
	if (w) {
		SLog(@"RDocumentController%@.windowWillCloseNotifications:%@", self, w);
		if (![[[RController sharedController] getRConsoleWindow] isKeyWindow]) {
			[[[RController sharedController] getRConsoleWindow] makeKeyWindow];
			SLog(@" RConsole set to key window");
		}
	}
}

- (void)windowDidBecomeKeyNotifications:(NSNotification*) aNotification
{
	NSWindow *w = [aNotification object];
	if (w) {
		SLog(@"RDocumentController%@.windowDidBecomeKeyNotifications:%@", self, w);
		NSDocument *d = [self documentForWindow:w];
		if (!d && w == [[RController sharedController] window]) d = mainDoc;
		if (d) {
			SLog(@" - document: %@", d);
			if (docList[docListPos] && docList[docListPos]!=d) {
				docListPos++;
				if (docListPos<0 || docListPos>=docListLimit) docListPos=0;			
			}
			docList[docListPos]=d;
		}
	}
}

- (NSWindow*) walkKeyListBack
{
	docListPos--;
	if (docListPos<0) {
		docListPos = docListLimit - 1;
		while (docListPos>=0 && !docList[docListPos]) docListPos--;
		if (docListPos<0) docListPos=0;
	}
	NSDocument *d = docList[docListPos];
	NSWindow *w = nil;
	SLog(@" - walkKeyListBack: doc=%@", d);
	if (!d || d==mainDoc) return [[RController sharedController] window];
	NSArray *a = [d windowControllers];
	if (a && [a count]>0)
		w = [[a objectAtIndex:0] window];
	else
		w = [[RController sharedController] window];
	return w;
}

- (NSWindow*) findLastDocType: (NSString*) aType
{
	SLog(@"RDocumentController%@.findLastDocType: %@", self, aType);
	int i=docListPos;
	while(1) {
		i--;
		if (i<0) {
			i = docListLimit - 1;
			while (i>=0 && !docList[i]) i--;
			if (i<0) i=0;
		}
		if (i==docListPos) break; // we're in a loop
		NSString *dt = [docList[i] fileType];
		if (dt) {
			SLog(@" * %@ -> %@", docList[i], dt);
			if ([dt isEqualToString:aType]) break;
		}
	}
	NSDocument *d = docList[i];
	if (!d || d==mainDoc) return [[RController sharedController] window];
	NSArray *a = [d windowControllers];
	if (a && [a count]>0)
		return [[a objectAtIndex:0] window];
	return [[RController sharedController] window];
}

- (NSWindow*) walkKeyListForward
{
	docListPos++;
	if (docListPos >= docListLimit) docListPos=0;
	NSDocument *d = docList[docListPos];
	NSWindow *w = nil;
	if (!d || d==mainDoc) return [[RController sharedController] window];
	NSArray *a = [d windowControllers];
	if (a && [a count]>0)
		w = [[a objectAtIndex:0] window];
	else
		w = [[RController sharedController] window];
	return w;
}

- (IBAction)newDocument:(id)sender {
	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	if (!useInternalEditor) {
		[self invokeExternalForFile: @""];
		return;
	}
	[super newDocument:sender];
}

- (id) openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument  error:(NSError **)theError {
	if (absoluteURL == nil) {
		SLog(@"RDocumentController.openDocumentWithContentsOfURL with null URL. Nothing to do.");
		return nil;
	}
	NSString *aFile = [[absoluteURL path] stringByExpandingTildeInPath];
	SLog(@"RDocumentController.openDocumentWithContentsOfURL: %@", aFile);
	int res = [[RController sharedController] isImageData: aFile];
	if (res == 0 ) {
		SLog(@" - detected save image, invoking load instead of the editor");
		[[RController sharedController] sendInput: [NSString stringWithFormat:@"load(\"%@\")", aFile]];
		return nil;
	}

	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	if (!useInternalEditor) {
		SLog(@" - external editor is enabled, passing over to invokeExternalForFile");
		[self invokeExternalForFile:aFile];
		return nil;
	}			

	SLog(@" - call super -> openDocumentWithContentsOfURL: %@", aFile);
	NSDocument *doc = nil;
	doc = [super openDocumentWithContentsOfURL:absoluteURL display:displayDocument error:theError];
	if (doc == nil) {				
		/* WARNING: this is a hack for cases where the document type 
		   cannot be determined. Since we're replicating Cocoa functionality this may break
		   with future versions of Cocoa. */
		SLog(@" -  creating manually");
		doc = [self makeDocumentWithContentsOfFile:aFile ofType:defaultDocumentType];
		if (doc) {
			SLog(@" - succeeded by calling makeDocument.. ofType: %@", defaultDocumentType);
			[self addDocument:doc];
			[doc makeWindowControllers];
			if (displayDocument && [self shouldCreateUI]) [doc showWindows];
		} else {
			SLog(@" * failed, returning nil");
		}
	}
	return doc;
}

- (void) invokeExternalForFile:(NSString*)aFile
{
	NSString *externalEditor = [NSString stringWithFormat:@"\"%@\"", [Preferences stringForKey:externalEditorNameKey withDefault: @"TextEdit"]];
	NSString *cmd;
	BOOL editorIsApp = [Preferences flagForKey:appOrCommandKey withDefault: YES];

	if (!aFile) aFile=@"";
	if (editorIsApp) {
		cmd = [@"open -a " stringByAppendingString:externalEditor];
		if (![aFile isEqualToString:@""])
			cmd = [cmd stringByAppendingString: [NSString stringWithFormat:@" \"%@\"", aFile]];
	} else {
		cmd = externalEditor; 
		if (![aFile isEqualToString:@""])
			cmd = [cmd stringByAppendingString: [NSString stringWithString: [NSString stringWithFormat:@" \"%@\"", aFile]]];
	}
	SLog(@" - call external: \"%@\"", cmd);
	system([cmd UTF8String]);	
}

- (void)removeDocument:(NSDocument *)document {
	int i=0, j=0, newPos=0;
	SLog(@"RDocumentController(%@).removeDocument: %@\n", self, document);
	
	// remove all references of the document from the doc list
	while (i<docListLimit) {
		if (i==docListPos)
			newPos=(docList[i]==document)?j-1:j; 
		if (docList[i] != document &&
			(j==0 || docList[j-1] != document)) { docList[j]=docList[i]; j++; };
		i++;
	}
	if (newPos<0) newPos=0;
	while (j<docListLimit) docList[j++]=nil;
	docListPos=newPos;
	
	[super removeDocument:document];
}

@end
