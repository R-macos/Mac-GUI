#import "Preferences.h"

Preferences *globalPrefs=nil;

@implementation Preferences

- (IBAction)load:(id)sender
{
}

- (IBAction)save:(id)sender
{
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

- (void) awakeFromNib
{
	if (!globalPrefs) globalPrefs=self;
	[self load:self];
}

//--- global methods ---

+ (void) setKey: (NSString*) key withString: (NSString*) value
{
	CFPreferencesSetAppValue((CFStringRef)key, (CFStringRef)value, kCFPreferencesCurrentApplication);
}

+ (NSString *) stringForKey: (NSString*) key
{
	CFStringRef cs = CFPreferencesCopyAppValue((CFStringRef)key, kCFPreferencesCurrentApplication);
	if (cs)
		return [((NSString*)cs) autorelease];
	return nil;
}

+ (void) setKey: (NSString*) key withInteger: (int) value
{
	CFNumberRef ti = CFNumberCreate(NULL, kCFNumberIntType, &value); 
	CFPreferencesSetAppValue((CFStringRef)key, ti, kCFPreferencesCurrentApplication);
	CFRelease(ti);
}

// returns -1 if the preference doesn't exist
+ (int) integerForKey: (NSString*) key
{
	CFNumberRef ti = CFPreferencesCopyAppValue((CFStringRef)key, kCFPreferencesCurrentApplication);
	if (!ti) return -1;
	{
		int i = -1;
		CFNumberGetValue(ti, kCFNumberIntType, &i);
		CFRelease(ti);
		return i;
	}
}

+ (void) sync
{
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);	
}

// especially during initialization it's not guaranteed that this won't be nil
+ (Preferences*) sharedPreferences
{
	return globalPrefs;
}

@end
