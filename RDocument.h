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


#import <Cocoa/Cocoa.h>
#import "Preferences.h"

#define iBackgroundColor 0
#define iInputColor      1
#define iOutputColor     2
#define iPromptColor     3
#define iStderrColor     4
#define iStdoutColor     5
#define iRootColor       6

extern NSColor *shColorNormal;
extern NSColor *shColorString;
extern NSColor *shColorNumber;
extern NSColor *shColorKeyword;
extern NSColor *shColorComment;
extern NSColor *shColorIdentifier;

@interface RDocument : NSDocument <PreferencesDependent>
{
	IBOutlet	NSTextView *textView;
	
	// since contents can be loaded in "-init", when NIB is not loaded yet, we need to store the contents until NIB is loaded.
	NSData *initialContents;
	NSString *initialContentsType;
	
	BOOL useHighlighting; // if set to YES syntax highlighting is used
	BOOL isEditable; // determines whether this document can be edited
	BOOL isREdit; // set to YES by R_Edit to exit modal state on close
	BOOL showMatchingBraces; // if YES mathing braces are highlighted
	
	double braceHighlightInterval; // interval to flash brace highlighting for
	NSDictionary *highlightColorAttr; // attributes set while braces matching
	
	BOOL updating; // this flag is set while syntax coloring is changed to prevent recursive changes
	BOOL execNewlineFlag; // this flag is set to YES when <cmd><Enter> execute is used, becuase the <enter> must be ignored as an event

	NSMutableArray *consoleColors;
	NSArray *defaultConsoleColors;
}

+ (void) setDefaultSyntaxHighlightingColors;

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title;

- (void) setEditable: (BOOL) editable;
- (void) setREditFlag: (BOOL) flag;
- (BOOL) hasREditFlag;

- (void) updateSyntaxHighlightingForRange: (NSRange) range;
- (void) highlightBracesWithShift: (int) shift andWarn: (BOOL) warn;
- (void) resetBackgroundColor: (id)sender; // end of highlighting

- (IBAction)executeSelection:(id)sender;
- (IBAction)sourceCurrentDocument:(id)sender;

- (void) setHighlighting: (BOOL) use;
- (void)updatePreferences;
- (IBAction)printDocument:(id)sender;

@end
