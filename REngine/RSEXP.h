//
//  RSEXP.h
//  Rgui
//
//  Created by Simon Urbanek on Wed Dec 10 2003.
//  Copyright (c) 2003-4 Simon Urbanek. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#import <Foundation/Foundation.h>
#include <Rinternals.h>

@interface RSEXP : NSObject {
    SEXP xp;
    RSEXP *attr;
}

/** constructors */
- (RSEXP*) initWithSEXP: (SEXP) ct;
- (RSEXP*) initWithString: (NSString*) str;
- (RSEXP*) initWithDoubleArray: (double*) arr length: (int) len;
- (RSEXP*) initWithIntArray: (int*) arr length: (int) len;

/** main methods */
- (int) type;
- (int) length;
- (RSEXP*) attribute;

/** direct access (avoid if possible) */
- (void) protect;
- (void) unprotect;
- (SEXP) directSEXP;

/** non-converting accessor methods */
- (int) integer;
- (double) real;
// the following methods return *references*, not copies, so make sure you copy its contents before R gets control back!
- (double*) doubleArray;
- (int*) intArray;

/** the array may containg NSString* (for STRSXP) or RSEXP* (for VECSXP) - make sure you take that into account; strings are always copies */
- (NSArray*) array;
- (NSString*) string;

- (id) value;
- (RSEXP*) elementAt: (int) index;

/** other/debug */
- (NSString*) typeName;

@end
