//
//  History.h
//  RCocoaBundle
//
//  Created by Simon Urbanek on Sat Mar 06 2004.
//  Copyright (c) 2004 R Development Core Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface History : NSObject {
    NSMutableArray* hist;
    NSString* dirtyEntry;
    int pos;
}


- (void) commit: (NSString*) entry;
- (NSString*) next;
- (NSString*) prev;
- (NSString*) current;
- (BOOL) isDirty;
- (void) updateDirty: (NSString*) entry;
- (void) resetAll;
- (void) setHist: (NSArray *) entries;
- (NSArray*) entries;

- (void) encodeWithCoder:(NSCoder *)coder;
- (id) initWithCoder:(NSCoder *)coder;

@end
