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
 *
 *  Created by Simon Urbanek on 1/11/05.
 */

#import <Cocoa/Cocoa.h>
#import "Preferences.h"
#import "RDocument.h"
//#import "RRulerView.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

@class RRulerView;

extern NSColor *shColorNormal;
extern NSColor *shColorString;
extern NSColor *shColorNumber;
extern NSColor *shColorKeyword;
extern NSColor *shColorComment;
extern NSColor *shColorIdentifier;

@interface RDocumentWinCtrl : NSWindowController <PreferencesDependent>
{
	IBOutlet NSScrollView *scrollView;
    IBOutlet NSTextView *textView;
	
	IBOutlet NSView *searchToolbarView;
	IBOutlet NSSearchField *searchToolbarField;
	
	IBOutlet NSView *fnListView;
	IBOutlet NSPopUpButton *fnListBox;
	
	IBOutlet NSDrawer *helpDrawer;
	IBOutlet WebView *helpWebView;
	
	IBOutlet NSPanel *goToLineSheet;
	IBOutlet NSTextField *goToLineField;
	
    RRulerView *theRulerView;

	RDocument *document;
	
	BOOL useHighlighting; // if set to YES syntax highlighting is used
	BOOL showMatchingBraces; // if YES mathing braces are highlighted
	BOOL deleteBackward;
	
	int hsType; // help search type
	
	double braceHighlightInterval; // interval to flash brace highlighting for
	NSDictionary *highlightColorAttr; // attributes set while braces matching
	
	BOOL updating; // this flag is set while syntax coloring is changed to prevent recursive changes
	BOOL execNewlineFlag; // this flag is set to YES when <cmd><Enter> execute is used, becuase the <enter> must be ignored as an event
	
	id editorToolbar; // toolbar proxy object
	
	NSString *helpTempFile; // path to temporary file used for help
}

- (void) replaceContentsWithString: (NSString*) strContents;
- (void) replaceContentsWithRtf: (NSData*) rtfContents;

- (void) updateSyntaxHighlightingForRange: (NSRange) range;
- (void) highlightBracesWithShift: (int) shift andWarn: (BOOL) warn;
- (void) resetBackgroundColor: (id)sender; // end of highlighting

- (IBAction)executeSelection:(id)sender;
- (IBAction)sourceCurrentDocument:(id)sender;
- (IBAction)printDocument:(id)sender;
- (IBAction)goToLine:(id)sender;
- (IBAction)goToLineCloseSheet:(id)sender;

- (IBAction)setHelpSearchType:(id)sender;
- (IBAction)goHelpSearch:(id)sender;

- (void) setEditable: (BOOL) editable;

- (void) setHighlighting: (BOOL) use;
- (void) updatePreferences;

- (NSData*) contentsAsRtf;
- (NSString*) contentsAsString;

- (NSTextView *) textView;
- (NSView*) searchToolbarView;
- (NSView*) fnListView;

- (void) functionRescan; // re-scans the functions it the document and updates function list/pop-up
- (void) functionGo: (id) sender; // invoked by function pop-up, the tag of the sender specifies the position to go to
- (void) functionReset; // reset all functions (will go away soon, user functionRescan instead)

@end
