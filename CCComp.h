/*
 *  CCComp.h - Common Cocoa Compatibility
 *  R
 *
 *  Include in all files instead of Cocoa, it provides compatibility work-arounds.
 *
 *  Created by Simon Urbanek on 3/15/11.
 *  Copyright 2011 Simon Urbanek. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import <Availability.h>

/* the following protocols are new in 10.6 (and useful) so for older OS X we have to define them */
#ifndef MAC_OS_X_VERSION_10_6
#define MAC_OS_X_VERSION_10_6 1060
#endif
#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6
@protocol NSTextStorageDelegate <NSObject>
@optional
- (void)textStorageWillProcessEditing:(NSNotification *)notification;   /* Delegate can change the characters or attributes */
- (void)textStorageDidProcessEditing:(NSNotification *)notification;    /* Delegate can change the attributes */
@end
@protocol NSToolbarDelegate <NSObject>
@optional
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;
- (void)toolbarWillAddItem: (NSNotification *)notification;
- (void)toolbarDidRemoveItem: (NSNotification *)notification;
@end
#endif

/* for pre-10.5 compatibility */
#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#define NSINTEGER_DEFINED 1
#endif
