//
//  TestPrefPane.h
//  PrefsPane
//
//  Created by Andreas on Sun Feb 01 2004.
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AMPrefPaneProtocol.h"


@interface MiscPrefPane : NSObject <AMPrefPaneProtocol> {
	IBOutlet NSView *mainView;
	NSString *identifier;
	NSString *label;
	NSString *category;
	NSImage *icon;
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

@end
