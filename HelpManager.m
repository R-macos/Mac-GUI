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

#import "HelpManager.h"
#import "RController.h"
#import "REngine.h"

static id sharedHMController;

@implementation HelpManager

- (id)init
{
    self = [super init];
    if (self) {
		sharedHMController = self;
	}
	
    return self;
}

- (void)dealloc {
	[super dealloc];
}

- (IBAction)runHelpSearch:(id)sender
{
	if([[sender stringValue] length]==0) 
		return;
	
	if([[ matchRadio selectedCell] tag] == kFuzzyMatch){
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"print(help.search(\"%@\"))", [sender stringValue]]];
			[sender setStringValue:@""];
	} else {
		REngine *re = [REngine mainEngine];	
		NSString *hlp = [NSString stringWithFormat:@"as.character(help(\"%@\", htmlhelp=TRUE))", [sender stringValue]];
		RSEXP *x = [re evaluateString:hlp];
		if(x==nil)
            return;
		NSString *url = [x string];
		if(url != nil)
			[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",url]]]];
		[x release];
	}
}

- (IBAction)showMainHelp:(id)sender
{
	 REngine *re = [REngine mainEngine];	
	 RSEXP *x = [re evaluateString:@"try(getOption(\"main.help.url\"))"];

	 if ((x==nil) | ([x string]==nil)){
		[re executeString:@"try(main.help.url())"];            
		[x release];
		x = [re evaluateString:@"try(getOption(\"main.help.url\"))"];
		if((x == nil) | ([x string]==nil)){
			[x release];	
			return;		
		}
	 }

	NSString *url = [x string];

	if(url != nil)
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	[helpWindow makeKeyAndOrderFront:self];
	[x release];

}

- (IBAction)showRFAQ:(id)sender
{
	 REngine *re = [REngine mainEngine];	
	 RSEXP *x= [re evaluateString:@"file.path(R.home(),\"RMacOSX-FAQ.html\")"];
	 if(x==nil)
		return;
		
	NSString *url = [NSString stringWithFormat:@"file://%@",[x string]];

	if(url != nil)
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	[helpWindow makeKeyAndOrderFront:self];
	[x release];
}

- (IBAction)whatsNew:(id)sender
{
	 REngine *re = [REngine mainEngine];	
	 RSEXP *x= [re evaluateString:@"file.show(file.path(R.home(),\"NEWS.aqua\"))"];
	 if(x==nil)
		return;
	[x release];
}

- (void)showHelpFor:(NSString *)topic
{
	REngine *re = [REngine mainEngine];	
	RSEXP *x= [re evaluateString:[NSString stringWithFormat:@"as.character(help(%@, htmlhelp=TRUE))",topic]];
	if(x==nil)
		return;
	
	NSString *url = [NSString stringWithFormat:@"file://%@",[x string]];
	
	if(url != nil)
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	[helpWindow makeKeyAndOrderFront:self];
	[x release];
}

+ (id) sharedController{
	return sharedHMController;
}


@end
