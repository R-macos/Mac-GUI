/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
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

#import "CodeCompletion.h"
#import "../REngine/REngine.h"

@implementation CodeCompletion

+ (NSString*) complete: (NSString*) part {
    REngine *re = [REngine mainEngine];
    // first get the length of the search path so we can go environment by environment
    RSEXP *x = [re evaluateString:@"length(search())"];
    int pos=1, maxpos;
    if (x==nil) return nil;
    if ((maxpos = [x integer])==0) return nil;    

    // ok, we got the search path length; search in each environment and if something matches, get it, otherwise go to the next one
    while (pos<=maxpos) {
        // use ls to get the names of the objects in the specific environment
        NSString *ls=[NSString stringWithFormat:@"ls(pos=%d, all.names=TRUE, pattern=\"^%@.*\")", pos, part];
        RSEXP *x = [re evaluateString:ls];
        //NSLog(@"attepmting to find %@ via %@", part, ls);
        if (x==nil)
            return nil;
        NSArray *a = [x array];
        if (a == nil) {
            [x release];
            return nil;
        }
        
        { // the following code works also if pattern is not specified; with pattern present we could make it even easier, but currently we use it just to narrow the search (e.g. "." could still be matched by something else ...)
            int i=0, firstMatch=-1, matches=0;
            NSString *common=nil;
            while (i<[a count]) {
                NSString *sx = (NSString*) [a objectAtIndex:i];
                if ([sx hasPrefix: part]) {
                    if (matches==0) {
                        firstMatch=i;
                        common=[[NSString alloc] initWithString: sx];
                    } else {
                        NSString *cpref=[[NSString alloc] initWithString:[common commonPrefixWithString:sx options:0]];
                        [common release];
                        common=cpref;
                    }
                    matches++;
                }
                i++;
            }
            if (common!=nil) { // attempt to get class of the object - it will fail if that's just a partial object, but who cares..
                x = [re evaluateString:[NSString stringWithFormat:@"try(class(%@),silent=TRUE)",common]];
                if (x!=nil && [x string]!=nil && [[x string] isEqualToString:@"function"])
                    return [[common autorelease] stringByAppendingString:@"("];
                else
                    return [common autorelease];
            }
        }
        pos++;
    }
    return nil;
}

+ (NSArray*) completeAll: (NSString*) part cutPrefix: (int) prefix {
    REngine *re = [REngine mainEngine];
    // first get the length of the search path so we can go environment by environment
    RSEXP *x = [re evaluateString:@"length(search())"];
    int pos=1, maxpos, matches=0;
	NSMutableArray *ca = nil;
	NSString *common=nil;

    if (x==nil) return nil;
    if ((maxpos = [x integer])==0) return nil;    
	
	ca = [[NSMutableArray alloc] initWithCapacity: 8];
	
    // ok, we got the search path length; search in each environment and if something matches, get it, otherwise go to the next one
    while (pos<=maxpos) {
        // use ls to get the names of the objects in the specific environment
        NSString *ls=[NSString stringWithFormat:@"ls(pos=%d, all.names=TRUE, pattern=\"^%@.*\")", pos, part];
        RSEXP *x = [re evaluateString:ls];
        //NSLog(@"attepmting to find %@ via %@", part, ls);
        if (x==nil)
            return nil;
        NSArray *a = [x array];
		
        if (a == nil) {
            [x release];
            return nil;
        }
        
        { // the following code works also if pattern is not specified; with pattern present we could make it even easier, but currently we use it just to narrow the search (e.g. "." could still be matched by something else ...)
            int i=0, firstMatch=-1;
            while (i<[a count]) {
                NSString *sx = (NSString*) [a objectAtIndex:i];
                if ([sx hasPrefix: part]) {
                    if (matches==0) {
                        firstMatch=i;
                        common=[[NSString alloc] initWithString: sx];
                    } else {
                        NSString *cpref=[[NSString alloc] initWithString:[common commonPrefixWithString:sx options:0]];
                        [common release];
                        common=cpref;
                    }
					[ca addObject: [sx substringFromIndex:prefix]];
                    matches++;
                }
                i++;
            }
        }
        pos++;
    }
	if (common) { 
		if (matches==1) {
			// attempt to get class of the object - it will fail if that's just a partial object, but who cares..
			x = [re evaluateString:[NSString stringWithFormat:@"try(class(%@),silent=TRUE)",common]];
			[ca release];
			if (x!=nil && [x string]!=nil && [[x string] isEqualToString:@"function"]) {
				return [NSArray arrayWithObject: [[[common autorelease] stringByAppendingString:@"("] substringFromIndex:prefix]];
			} else {
				return [NSArray arrayWithObject: [[common autorelease] substringFromIndex:prefix]];
			}
		} else {
			[common release];
			return ca;
		}
	}
	[ca release];
    return nil;
}

@end
