//
//  REngine.h
//  Rgui
//
//  Created by Simon Urbanek on Wed Dec 10 2003.
//  Copyright (c) 2003-4 Simon Urbanek. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#import <Foundation/Foundation.h>
#import "RSEXP.h"
#import "Rcallbacks.h"

/* since R 2.0 parse is mapped to Rf_parse which is deadly ... 
   therefore REngine.h must be included *after* R headers */
#ifdef parse
#undef parse
#endif

#define RENGINE_BEGIN [self begin]
#define RENGINE_END   [self end]

@interface REngine : NSObject {
	/* the object handling all R callbacks - the Rcallback.h for the protocol definition */
    id <REPLHandler> replHandler;
	
	/* set to NO if the engine is initialized but activate was not called yet - that is R was not really initialized yet */
	BOOL active;

	/* set to YES if R REPL is running */
	BOOL loopRunning;
	
	/* last error string */
	NSString* lastError;
	
	/* initial arguments used by activate to initialize R */
	int  argc;
	char **argv;
}

+ (REngine*) mainEngine;
+ (id <REPLHandler>) mainHandler;

- (REngine*) init;
- (REngine*) initWithHandler: (id <REPLHandler>) hand;
- (REngine*) initWithHandler: (id <REPLHandler>) hand arguments: (char**) args;
- (BOOL) activate;

- (BOOL) isLoopRunning;
- (BOOL) isActive;

- (NSString*) lastError;

- (void) begin;
- (void) end;

// eval mode
- (RSEXP*) parse: (NSString*) str;
- (RSEXP*) parse: (NSString*) str withParts: (int) count;
- (RSEXP*) evaluateExpressions: (RSEXP*) expr;
- (RSEXP*) evaluateString: (NSString*) str;
- (RSEXP*) evaluateString: (NSString*) str withParts: (int) count;
- (BOOL)   executeString: (NSString*) str; // void eval

// REPL mode
- (id <REPLHandler>) handler;
- (void) runREPL;

@end
