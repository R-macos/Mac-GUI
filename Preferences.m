/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *
 *                  
 *  R Copyright notes:
 *                     Copyright (C) 1995-1996   Robert Gentleman and Ross Ihaka
 *                     Copyright (C) 1998-2001   The R Development Core Team
 *                     Copyright (C) 2002-2004   The R Foundation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  A copy of the GNU General Public License is available via WWW at
 *  http://www.gnu.org/copyleft/gpl.html.  You can also obtain it by
 *  writing to the Free Software Foundation, Inc., 59 Temple Place,
 *  Suite 330, Boston, MA  02111-1307  USA.
 */

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
