//
//  EditorPrefPane.h
//  R
//
//  Created by rob goedman on 11/1/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AMPrefPaneProtocol.h"


@interface EditorPrefPane : NSObject <AMPrefPaneProtocol> {
	NSString *identifier;
	NSString *label;
	NSString *category;
	NSImage *icon;
	
	IBOutlet NSView *mainView;
	IBOutlet NSMatrix *internalOrExternal;
	IBOutlet NSBox *builtInPrefs;
	IBOutlet NSBox *externalSettings;
	IBOutlet NSButton *showSyntaxColoring;
	IBOutlet NSButton *showBraceHighlighting;
	IBOutlet NSTextField *highlightInterval;
	IBOutlet NSButton *showLineNumbers;
	IBOutlet NSTextField *externalEditorName;
	IBOutlet NSMatrix *appOrCommand;
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

	// Other methods

- (IBAction) changeInternalOrExternal:(id)sender;
- (NSMatrix *) internalOrExternal;
- (id) builtInPrefs;
- (id) externalSettings;
- (IBAction) changeShowSyntaxColoring:(id)sender;
- (id) showSyntaxColoring;
- (IBAction) changeShowBraceHighlighting:(id)sender;
- (id) showBraceHighlighting;
- (IBAction) changeHighlightInterval:(id)sender;
- (id) highlightInterval;
- (IBAction) changeShowLineNumbers:(id)sender;
- (id) showLineNumbers;
- (IBAction) changeExternalEditorName:(id)sender;
- (id) externalEditorName;
- (IBAction) changeAppOrCommand:(id)sender;
- (NSMatrix *) appOrCommand;

@end
