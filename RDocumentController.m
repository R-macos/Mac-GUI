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
