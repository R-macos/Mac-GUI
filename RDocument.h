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
	NSData *dataFromFile;
	IBOutlet	NSTextView *textView;
	
	BOOL updating; // this flag is set while syntax coloring is changed to prevent recursive changes
	BOOL execNewlineFlag; // this flag is set to YES when <cmd><Enter> execute is used, becuase the <enter> must be ignored as an event
}

+ (void) setDefaultSyntaxHighlightingColors;

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title;
- (NSString *)whoAmI;

- (void)updateSyntaxHighlightingForRange: (NSRange) range;

- (IBAction)executeSelection:(id)sender;

@end
