/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004  The R Foundation
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

+ (NSArray*) completeAll: (NSString*) part cutPrefix: (int) prefix {
    int tl = [part length];
    int ls = tl-1, fb;
    NSString *dir;
    BOOL working=NO;
    NSString *fn;
	NSMutableArray *ca = [[NSMutableArray alloc] initWithCapacity: 8];
    
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
					[ca addObject: [sx substringFromIndex:prefix]];
                    matches++;
                }
                i++;
            }
			return ca; 
			/*
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
            } */
        }
    }
    return nil;
}

@end
