//
//  main.m
//  R
//
//  Created by stefano iacus on Mon Jul 26 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//


#import <Cocoa/Cocoa.h>

#ifdef DEBUG_RGUI
#import <ExceptionHandling/NSExceptionHandler.h>
#endif

int main(int argc, const char *argv[])
{
#ifdef DEBUG_RGUI
	[[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask: NSLogAndHandleEveryExceptionMask]; // log+handle all but "other"
#endif
	return(NSApplicationMain(argc, argv));
}
