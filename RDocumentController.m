#import "RController.h"
#import "RDocumentController.h"

@implementation RDocumentController

- (id)init {
	self = [super init];
	return self;
}

- (IBAction)newDocument:(id)sender {
	NSString *editor;
	NSString *cmd;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *theData=[defaults dataForKey:internalOrExternalKey];
	if(theData != nil){
		if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
			editor = nil;			
		} else {
			theData=[defaults dataForKey:externalEditorNameKey];
			if(theData != nil) {
				editor = (NSString *)[NSUnarchiver unarchiveObjectWithData:theData];
			} else {
				editor = nil;
			}	
		}
	} else 
		editor = nil;
	if (editor == nil)
		[super newDocument:(id)sender];
	else {
		theData=[defaults dataForKey:appOrCommandKey];
		if(theData != nil){
			if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
				cmd = [@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]];
			} else {
				cmd = editor;
			}
		} else 
			cmd = [@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]];
		system([cmd cString]);
	}
}

- (IBAction)openDocument:(id)sender {
	NSString *editor;
	NSString *cmd;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *theData=[defaults dataForKey:internalOrExternalKey];
	if(theData != nil){
		if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
			editor = nil;			
		} else {
			theData=[defaults dataForKey:externalEditorNameKey];
			if(theData != nil) {
				editor = (NSString *)[NSUnarchiver unarchiveObjectWithData:theData];
			} else {
				editor = nil;
			}	
		}
	} else 
		editor = nil;
	if (editor == nil)
		[super openDocument:(id)sender];
	else {
		NSArray *files = [super fileNamesFromRunningOpenPanel];
		int i = [files count];
		int j;
		for (j=0;j<i;j++) {
			theData=[defaults dataForKey:appOrCommandKey];
			if(theData != nil){
				if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
					cmd = [[@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]] stringByAppendingString: [NSString stringWithString: [files objectAtIndex:j]]];
				} else {
					cmd = [[editor stringByAppendingString:@" -c "]stringByAppendingString: [NSString stringWithString: [files objectAtIndex:j]]];
				}
			} else 
				cmd = [[@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]] stringByAppendingString: [NSString stringWithString: [files objectAtIndex:j]]];
			system([cmd cString]);
		}
	}
}

- (id)openDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag {
//	NSLog(@"openDocumentWith: %@:", aFile);
	int res = [[RController getRController] isImageData: (char *)[aFile cString]];
	if (res == -1)
		NSLog(@"Can't open file %@", aFile);
	else if (res == 0 ) {
		[[RController getRController] sendInput: [NSString stringWithFormat:@"load(\"%@\")", aFile]];
	} else {
		NSString *editor;
		NSString *cmd;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSData *theData=[defaults dataForKey:editOrSourceKey];
		if(theData != nil && ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"NO"])){
//			NSLog(@"Source the file!");
			[[RController getRController] sendInput:[NSString stringWithFormat:@"source(\"%@\")",aFile]];
		} else {
			if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
				theData=[defaults dataForKey:internalOrExternalKey];
				if(theData != nil){
					if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
						editor = nil;			
					} else {
						theData=[defaults dataForKey:externalEditorNameKey];
						if(theData != nil) {
							editor = (NSString *)[NSUnarchiver unarchiveObjectWithData:theData];
						} else {
							editor = nil;
						}	
					}
				} else 
					editor = nil;
				if (editor == nil)
					return [super openDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag];
				else {
					theData=[defaults dataForKey:appOrCommandKey];
					if(theData != nil){
						if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
							cmd = [[@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]] stringByAppendingString: aFile];
						} else {
							cmd = [[editor stringByAppendingString:@" -c "]stringByAppendingString: [NSString stringWithString: aFile]];
						}
					} else 
						cmd = [[@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]] stringByAppendingString: aFile];
					system([cmd cString]);
				}
			}		
		}	
	}
	return 0;
}

- (id)openRDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag {
//	NSLog(@"openRDocumentWith: %@", aFile);
	NSString *editor;
	NSString *cmd;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *theData=[defaults dataForKey:internalOrExternalKey];
	if(theData != nil){
		if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
			editor = nil;			
		} else {
			theData=[defaults dataForKey:externalEditorNameKey];
			if(theData != nil) {
				editor = (NSString *)[NSUnarchiver unarchiveObjectWithData:theData];
			} else {
				editor = nil;
			}	
		}
	} else 
		editor = nil;
	if (editor == nil)
		return [super openDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag];
	else {
		theData=[defaults dataForKey:appOrCommandKey];
		if(theData != nil){
			if ([(NSString *)[NSUnarchiver unarchiveObjectWithData:theData] isEqualToString: @"YES"]) {
				cmd = [[@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]] stringByAppendingString: aFile];
			} else {
				cmd = [[editor stringByAppendingString:@" -c "]stringByAppendingString: [NSString stringWithString: aFile]];
			}
		} else 
			cmd = [[@"open -a " stringByAppendingString:[editor stringByAppendingString:@".app "]] stringByAppendingString: aFile];
		system([cmd cString]);
		return 0;
	}
}

@end
