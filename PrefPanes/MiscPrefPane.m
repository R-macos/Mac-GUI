//
//  MiscPrefPane.m
//  PrefsPane
//
//  Created by Andreas on Sun Feb 01 2004.
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.
//

#import "MiscPrefPane.h"


@interface MiscPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation MiscPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if (self = [super init]) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"miscPP"] copy];
		[theImage setFlipped:NO];
		[theImage lockFocus];
		[[NSColor blackColor] set];
	//	[theIdentifier drawAtPoint:NSZeroPoint withAttributes:nil];
		[theImage unlockFocus];
		[theImage recache];
		[self setIcon:theImage];
	}
	return self;
}


- (NSString *)identifier
{
    return identifier;
}

- (void)setIdentifier:(NSString *)newIdentifier
{
    id old = nil;

    if (newIdentifier != identifier) {
        old = identifier;
        identifier = [newIdentifier copy];
        [old release];
    }
}

- (NSString *)label
{
    return label;
}

- (void)setLabel:(NSString *)newLabel
{
    id old = nil;

    if (newLabel != label) {
        old = label;
        label = [newLabel copy];
        [old release];
    }
}

- (NSString *)category
{
    return category;
}

- (void)setCategory:(NSString *)newCategory
{
    id old = nil;

    if (newCategory != category) {
        old = category;
        category = [newCategory copy];
        [old release];
    }
}

- (NSImage *)icon
{
    return icon;
}

- (void)setIcon:(NSImage *)newIcon
{
    id old = nil;

    if (newIcon != icon) {
        old = icon;
        icon = [newIcon retain];
        [old release];
    }
}


// AMPrefPaneProtocol
- (NSView *)mainView
{
	if (!mainView) {
		[NSBundle loadNibNamed:@"MiscPrefPane" owner:self];
	}
	return mainView;
}


// AMPrefPaneInformalProtocol

- (void)willSelect
{}

- (void)didSelect
{}

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

- (void)willUnselect
{}

- (void)didUnselect
{}


@end
