//
//  RDocument.h
//  
//
//  Created by stefano iacus on Sat Aug 14 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//


#import <Cocoa/Cocoa.h>

#import "RDeviceView.h"

@interface RQuartz : NSDocument
{
	IBOutlet	RDeviceView *deviceView;
	IBOutlet	NSWindow *deviceWindow;
}


- (RDeviceView *)getDeviceView;
- (NSWindow *)getDeviceWindow;
- (IBAction) activateQuartzDevice: (id) sender;

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title;
- (NSString *)whoAmI;	


@end
