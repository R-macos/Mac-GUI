//
//  RProgressIndicator.m
//  R
//
//  Created by Bibiko on 03.02.12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "RProgressIndicator.h"


@implementation RProgressIndicator


// draw a gradient background behind the fints to
// make the spinner visible even for dark background colors
- (void)drawRect:(NSRect)dirtyRect 
{ 

	// Get the spinner's background color drawed by its superview's window
	NSColor *backGround = [[[self superview] window] backgroundColor];

	// just in case bail if nothing set
	if(!backGround) return;

	// Do nothing for white background
	if(backGround == [NSColor whiteColor]) return;

	NSColor *startColor, *endColor;
	if(_isRunning) {
		startColor = [NSColor whiteColor];
		// special case for pure black backround
		if(([[backGround colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] whiteComponent] == 0.0))
			endColor = backGround;
		else 
			endColor = [NSColor clearColor];
	} else {
		startColor = [NSColor clearColor];
		endColor = startColor;
	}

	NSRect bounds = [self bounds];

	// create the gradient
	NSGradient* aGradient = [[[NSGradient alloc] initWithStartingColor:startColor
			endingColor:endColor] autorelease];

	// draw a radial gradient inside circle
	NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:bounds];
	[aGradient drawInBezierPath:circle relativeCenterPosition:NSMakePoint(0,0)];

	// draw a pure filled by the background color circle in the middle
	// of the spinner (looks better)
	[backGround set];
	circle = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(bounds, 4.8, 4.8)];
	[circle fill];

}

- (void)startAnimation:(id)sender
{
	_isRunning = YES;
	[super startAnimation:sender];
}

- (void)stopAnimation:(id)sender
{
	_isRunning = NO;
	[super stopAnimation:sender];
}

@end
