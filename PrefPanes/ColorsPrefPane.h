//
//  QuartzPrefPane.h
//  PrefsPane
//
//  Created by Andreas on Sun Feb 01 2004.
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AMPrefPaneProtocol.h"


@interface ColorsPrefPane : NSObject <AMPrefPaneProtocol> {
	IBOutlet NSView *mainView;
	NSString *identifier;
	NSString *label;
	NSString *category;
	NSImage *icon;

	id inputColorWell;
    id outputColorWell;
    id promptColorWell;
    id backgColorWell;
    id stderrColorWell;
    id stdoutColorWell;
	
	id defaultColorsButton;
	id alphaStepper;
	
}

- (id)initWithIdentifier:(NSString *)identifier label:(NSString *)label category:(NSString *)category;

// AMPrefPaneProtocol
- (NSString *)identifier;
- (NSView *)mainView;
- (NSString *)label;
- (NSImage *)icon;
- (NSString *)category;

// AMPrefPaneInformalProtocol
- (void)willSelect;
- (void)didSelect;
	//	Deselecting the preference pane
- (int)shouldUnselect;
	// should be NSPreferencePaneUnselectReply
- (void)willUnselect;
- (void)didUnselect;



- (IBAction) changeInputColor:(id)sender;
- (IBAction) changeOutputColor:(id)sender;
- (IBAction) changePromptColor:(id)sender;
- (IBAction) changeStdoutColor:(id)sender;
- (IBAction) changeStderrColor:(id)sender;
- (IBAction) changeBackGColor:(id)sender;
- (IBAction) changeAlphaColor:(id)sender;
- (IBAction) setDefaultColors:(id)sender;

- (id) inputColorWell;
- (id) outputColorWell;
- (id) promptColorWell;
- (id) backgColorWell;
- (id) stderrColorWell;
- (id) stdoutColorWell;
- (id) alphaStepper;

@end
