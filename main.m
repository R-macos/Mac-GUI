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
 *
 *  Created by Stefano Iacus on 7/26/04.
 *  $Id$
 */

#import <Cocoa/Cocoa.h>
#import "RGUI.h"
#import "REngine/REngine.h"
#import "Preferences.h"
#import "PreferenceKeys.h"
#import "Quartz/QuartzDevice.h"
#import "RController.h"
#import "Rversion.h"

#ifdef DEBUG_RGUI
#import <ExceptionHandling/NSExceptionHandler.h>
#import "Tools/GlobalExHandler.h"
#endif

NSString *Rapp_R_version_short;
NSString *Rapp_R_version;

int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#ifdef DEBUG_RGUI00
	{
		// add an independent exception handler
		[[GlobalExHandler alloc] init];
		[[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask: NSLogAndHandleEveryExceptionMask]; // log+handle all
	}
#endif
	
	Rapp_R_version_short = [[NSString alloc] initWithFormat:@"%d.%d", (R_VERSION >> 16), (R_VERSION >> 8)&255];
	Rapp_R_version = [[NSString alloc] initWithFormat:@"%s.%s", R_MAJOR, R_MINOR];
	
	[NSApplication sharedApplication];
	[NSBundle loadNibNamed:@"MainMenu" owner:NSApp];
	
	 SLog(@" - initalizing R");
	 if (![[REngine mainEngine] activate]) {
		 NSRunAlertPanel(NLS(@"Cannot start R"),[NSString stringWithFormat:NLS(@"Unable to start R: %@"), [[REngine mainEngine] lastError]],NLS(@"OK"),nil,nil);
		 exit(-1);
	 }
	 
	 /* register Quartz symbols */
	 QuartzRegisterSymbols();
	 /* create quartz.save function in tools:quartz */
	 [[REngine mainEngine] executeString:@"try(local({e<-attach(NULL,name=\"tools:RGUI\"); assign(\"quartz.save\",function(file, type=\"png\", device=dev.cur(), ...) invisible(.Call(\"QuartzSaveContents\",device,file,type,list(...))),e); assign(\"avaliable.packages\",function(...) available.packages(...),e)}))"];
	 
	 SLog(@" - set R options");
	 // force html-help, because that's the only format we can handle ATM
	 [[REngine mainEngine] executeString: @"options(htmlhelp=TRUE)"];
	 
	 SLog(@" - set default CRAN mirror");
	 {
		 NSString *url = [Preferences stringForKey:defaultCRANmirrorURLKey withDefault:@""];
		 if (![url isEqualToString:@""])
			 [[REngine mainEngine] executeString:[NSString stringWithFormat:@"try(local({ r <- getOption('repos'); r['CRAN']<-gsub('/$', '', \"%@\"); options(repos = r) }),silent=TRUE)", url]];
	 }
	 
	 SLog(@" - set BioC repositories");
#if (R_VERSION < R_Version(2,3,0))
	 [[REngine mainEngine] executeString:@"if (is.null(getOption('BioC.Repos'))) options('BioC.Repos'=c('http://www.bioconductor.org/packages/bioc/stable','http://www.bioconductor.org/packages/data/annotation/stable','http://www.bioconductor.org/packages/data/experiment/stable'))"];
#else
#if (R_VERSION < R_Version(2,4,0))
	 [[REngine mainEngine] executeString:@"if (is.null(getOption('BioC.Repos'))) options('BioC.Repos'=paste('http://www.bioconductor.org/packages/',c('1.8/bioc','1.8/data/annotation','1.8/data/experiment','1.8/omegahat','1.8/lindsey'),sep=''))"];
#else
#if (R_VERSION < R_Version(2,5,0))
	 [[REngine mainEngine] executeString:@"if (is.null(getOption('BioC.Repos'))) options('BioC.Repos'=paste('http://www.bioconductor.org/packages/',c('1.9/bioc','1.9/data/annotation','1.9/data/experiment','1.9/omegahat'),sep=''))"];
#else
	 [[REngine mainEngine] executeString:@"if (is.null(getOption('BioC.Repos'))) options('BioC.Repos'=paste('http://www.bioconductor.org/packages/',c('2.0/bioc','2.0/data/annotation','2.0/data/experiment','2.0/omegahat'),sep=''))"];
#endif
#endif
#endif
	 SLog(@" - loading secondary NIBs");
	 if (![NSBundle loadNibNamed:@"Vignettes" owner:NSApp]) {
		 SLog(@" * unable to load Vignettes.nib!");
	 }

	 SLog(@"main: finish launching");
	 [NSApp finishLaunching];
 
	 // ready to rock
	 SLog(@"main: entering REPL");
	 [[REngine mainEngine] runREPL];
	 
	 SLog(@"main: returned from REPL");
	 [pool release];
	 
	 SLog(@"main: exiting with status 0");
	 return 0;
}
