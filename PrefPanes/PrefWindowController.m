#import "PrefWindowController.h"

@implementation PrefWindowController

- (id) init
{
	self = [super initWithAutosaveName:@"PreferencesWindow"];
	return self;
}

- (void) awakeFromNib
{
	quartzPrefPane = [[[QuartzPrefPane alloc] initWithIdentifier:@"Quartz" label:@"Quartz" category:@"Graphics"] autorelease];
	[self addPane:quartzPrefPane withIdentifier:[quartzPrefPane identifier]];
	
	miscPrefPane = [[[MiscPrefPane alloc] initWithIdentifier:@"Misc" label:@"Misc" category:@"General"] autorelease];
	[self addPane:miscPrefPane withIdentifier:[miscPrefPane identifier]];
	
	colorsPrefPane = [[[ColorsPrefPane alloc] initWithIdentifier:@"Colors" label:@"Colors" category:@"Console"] autorelease];
	[self addPane:colorsPrefPane withIdentifier:[colorsPrefPane identifier]];
	
	editorPrefPane = [[[EditorPrefPane alloc] initWithIdentifier:@"Editor" label:@"Editor" category:@"Editor"] autorelease];
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
