//
//  FileCompletion.m
//  RCocoaBundle
//
//  Created by Simon Urbanek on Sun Mar 07 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "FileCompletion.h"


@implementation FileCompletion

+ (NSString*) complete: (NSString*) part {
    int tl = [part length];
    int ls = tl-1, fb;
    NSString *dir;
    BOOL working=NO;
    NSString *fn;
    
    //NSLog(@"attepted file-completion: \"%@\"", part);
    while (ls>0 && [part characterAtIndex:ls]!='/') ls--;
    if (ls<1 && (tl==0 || [part characterAtIndex:ls]!='/'))
        working=YES;
    dir=working?@".":((ls==0)?@"/":[part substringToIndex:ls]);
    fb=ls; if (fb<tl && [part characterAtIndex:fb]=='/') fb++;
    fn=(fb<tl)?[part substringFromIndex:fb]:@"";
    //NSLog(@"directory to look in: \"%@\" for entry beginning with \"%@\"", dir, fn);
    {
        NSArray *a = [[NSFileManager defaultManager] directoryContentsAtPath:dir];
        if (a==nil) return nil;
        { 
            int i=0, firstMatch=-1, matches=0;
            NSString *common=nil;
            while (i<[a count]) {
                NSString *sx = (NSString*) [a objectAtIndex:i];
                if ([sx hasPrefix: fn]) {
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
            if (common!=nil) {
                NSString *fnp=[common autorelease];
                BOOL isDir=NO;
                fnp = ((dir==@".")?fnp:
                       ((dir==@"/")?[@"/" stringByAppendingString:fnp]:
                        [[dir stringByAppendingString:@"/"] stringByAppendingString:fnp]));
                if ([[NSFileManager defaultManager] fileExistsAtPath:fnp isDirectory:&isDir] && isDir)
                    fnp = [fnp stringByAppendingString:@"/"];
                if ([fnp isEqualToString:@"//"])
                    fnp=@"/";
                return fnp;
            }
        }
    }
    return nil;
}

@end
