//
//  CodeCompletion.m
//  RCocoaBundle
//
//  Created by Simon Urbanek on Sun Mar 07 2004.
//  Copyright (c) 2004 Simon Urbanek. All rights reserved.
//

#import "CodeCompletion.h"
#import "REngine.h"

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

@end
