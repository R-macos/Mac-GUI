//
//  TestPrefPane.m
//  PrefsPane
//
//  Created by Andreas on Sun Feb 01 2004.
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.
//

#import "RController.h"
#import "ColorsPrefPane.h"


@interface ColorsPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation ColorsPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if (self = [super init]) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"colorsPP"] copy];
		[theImage setFlipped:NO];
		[theImage lockFocus];
		[[NSColor blackColor] set];
//		[theIdentifier drawAtPoint:NSZeroPoint withAttributes:nil];
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
		[NSBundle loadNibNamed:@"ColorsPrefPane" owner:self];
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

/* end of std methods implementation */


- (IBAction)changeInputColor:(id)sender {
    [[RController getRController] changeInputColor:sender];
}

- (IBAction)changeOutputColor:(id)sender {
    [[RController getRController] changeOutputColor:sender];
}

- (IBAction)changePromptColor:(id)sender {
    [[RController getRController] changePromptColor:sender];
}

- (IBAction)changeStdoutColor:(id)sender {
    [[RController getRController] changeStdoutColor:sender];
}

- (IBAction)changeStderrColor:(id)sender {
    [[RController getRController] changeStderrColor:sender];
}

- (IBAction)changeBackGColor:(id)sender {
    [[RController getRController] changeBackGColor:sender];
}

- (IBAction) changeAlphaColor:(id)sender {
    [[RController getRController] changeAlphaColor:sender];
}


- (IBAction) setDefaultColors:(id)sender {
    [[RController getRController] setDefaultColors:sender];
}

- (id) inputColorWell
{
	return inputColorWell;
}

- (id) outputColorWell
{
	return outputColorWell;
}


- (id) promptColorWell
{
	return promptColorWell;
}

- (id) backgColorWell
{
	return backgColorWell;
}

- (id) stderrColorWell
{
	return stderrColorWell;
}

- (id) stdoutColorWell
{
	return stdoutColorWell;
}


- (id) alphaStepper
{
	return alphaStepper;
}


@end
