//
//  RDocument.h
//  
//
//  Created by stefano iacus on Sat Aug 14 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//


#import <Cocoa/Cocoa.h>

extern NSColor *shColorNormal;
extern NSColor *shColorString;
extern NSColor *shColorNumber;
extern NSColor *shColorKeyword;
extern NSColor *shColorComment;
extern NSColor *shColorIdentifier;

@interface RDocument : NSDocument
{
	IBOutlet	NSTextView *textView;
	
	// since contents can be loaded in "-init", when NIB is not loaded yet, we need to store the contents until NIB is loaded.
	NSData *initialContents;
	NSString *initialContentsType;
	
	BOOL useHighlighting; // if set to YES syntax highlighting is used
	BOOL isEditable; // determines whether this document can be edited
	BOOL isREdit; // set to YES by R_Edit to exit modal state on close
	
	BOOL updating; // this flag is set while syntax coloring is changed to prevent recursive changes
	BOOL execNewlineFlag; // this flag is set to YES when <cmd><Enter> execute is used, becuase the <enter> must be ignored as an event
}

+ (void) setDefaultSyntaxHighlightingColors;

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title;

- (void) setHighlighting: (BOOL) use;
- (void) setEditable: (BOOL) editable;
- (void) setREditFlag: (BOOL) flag;
- (BOOL) hasREditFlag;

- (void)updateSyntaxHighlightingForRange: (NSRange) range;

- (IBAction)executeSelection:(id)sender;
- (IBAction)sourceCurrentDocument:(id)sender;

@end
