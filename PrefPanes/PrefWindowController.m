#import "../RGUI.h"
#import "PrefWindowController.h"

@implementation PrefWindowController

- (id) init
{
	self = [super initWithAutosaveName:@"PreferencesWindow"];
	return self;
}

- (void) awakeFromNib
{
	quartzPrefPane = [[[QuartzPrefPane alloc] initWithIdentifier:@"Quartz" label:NLSC(@"PrefP-Quartz",@"Quartz preference pane") category:NLSC(@"PrefG-Views",@"Views preference group") ] autorelease];
	[self addPane:quartzPrefPane withIdentifier:[quartzPrefPane identifier]];
	
	miscPrefPane = [[[MiscPrefPane alloc] initWithIdentifier:@"Misc" label:NLSC(@"PrefP-Startup",@"Startup preference pane") category:NLSC(@"PrefG-General",@"General preference group")] autorelease];
	[self addPane:miscPrefPane withIdentifier:[miscPrefPane identifier]];
	
	colorsPrefPane = [[[ColorsPrefPane alloc] initWithIdentifier:@"Colors" label:NLSC(@"PrefP-Colors",@"Colors preference pane") category:NLSC(@"PrefG-Views",@"Views preference group")] autorelease];
	[self addPane:colorsPrefPane withIdentifier:[colorsPrefPane identifier]];
	
	syntaxColorsPrefPane = [[[SyntaxColorsPrefPane alloc] initWithIdentifier:@"Syntax Colors" label:NLSC(@"PrefP-Syntax",@"Syntax colors preference pane") category:NLSC(@"PrefG-Editor",@"Editor preference group")] autorelease];
	[self addPane:syntaxColorsPrefPane withIdentifier:[syntaxColorsPrefPane identifier]];
	
	editorPrefPane = [[[EditorPrefPane alloc] initWithIdentifier:@"Editor" label:NLSC(@"PrefP-Editor",@"Editor preference pane") category:NLSC(@"PrefG-Editor",@"Editor preference group")] autorelease];
	[self addPane:editorPrefPane withIdentifier:[editorPrefPane identifier]];
	
	// set up some configuration options
	[self setUsesConfigurationPane:YES];
	[self setSortByCategory:YES];
	// select prefs pane for display
	[self selectPaneWithIdentifier:@"All"];
}

- (IBAction)showPrefsWindow:(id)sender
{
	[self showWindow:self];
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)sortByAlphabet:(id)sender
{
	[self setSortByCategory:NO];
	[self selectIconViewPane];
}

- (IBAction)sortByCategory:(id)sender
{
	[self setSortByCategory:YES];
	[self selectIconViewPane];
}

- (BOOL)shouldLoadPreferencePane:(NSString *)identifier
{
	//	NSLog(@"shouldLoadPreferencePane: %@", identifier);
	return YES;
}

- (void)willSelectPreferencePane:(NSString *)identifier
{
	//	NSLog(@"willSelectPreferencePane: %@", identifier);
}

- (void)didUnselectPreferencePane:(NSString *)identifier
{
	//	NSLog(@"didUnselectPreferencePane: %@", identifier);
}

- (NSString *)displayNameForCategory:(NSString *)category
{
	return category;
}

@end
