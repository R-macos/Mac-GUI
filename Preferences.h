/* Preferences */

#import <Cocoa/Cocoa.h>

@interface Preferences : NSObject
{
}
- (IBAction)load:(id)sender;
- (IBAction)save:(id)sender;

+ (void) sync;

+ (void) setKey: (NSString*) key withString: (NSString*) value;
+ (void) setKey: (NSString*) key withInteger: (int) value;

+ (NSString *) stringForKey: (NSString*) key;
+ (int) integerForKey: (NSString*) key;

+ (Preferences*) sharedPreferences;

@end
