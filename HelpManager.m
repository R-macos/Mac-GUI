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

#import "RGUI.h"
#import "HelpManager.h"
#import "RController.h"
#import "REngine/REngine.h"

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
	
	NSString *searchString;
	NSCharacterSet *charSet;
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
	searchString = [[sender stringValue] stringByTrimmingCharactersInSet:charSet];
	SLog(@"runHelpSearch: <%@>", searchString);
	
	//		[self sendInput:[NSString stringWithFormat:@"help(\"%@\")", searchString]];
	if(searchType == kFuzzyMatch){
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"print(help.search(\"%@\"))", searchString]];
			[sender setStringValue:@""];
	} else {
		[self showHelpFor: searchString];
	}
}

- (void)showHelpUsingFile: (NSString *)file topic: (NSString*) topic
{
	if (!file) return;
	if (!topic) topic=@"<unknown>";
	NSString *url = [NSString stringWithFormat:@"file://%@",file];
	SLog(@"HelpManager.showHelpUsingFile:\"%@\", topic=%@, URL=%@", file, topic, url);
	if(url != nil)
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	[helpWindow makeKeyAndOrderFront:self];
}

- (void)showHelpFor:(NSString *)topic
{
	NSString *searchString;
	NSCharacterSet *charSet;
	if (!topic) return; /* should we issue an error? This happens only if the encoding is wrong */
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
	searchString = [topic stringByTrimmingCharactersInSet:charSet];
//	NSLog(@"showHelpFor: <%@>", searchString);
	
	REngine *re = [REngine mainEngine];	
	RSEXP *x= [re evaluateString:[NSString stringWithFormat:@"as.character(help(\"%@\", htmlhelp=TRUE))",searchString]];
	if ((x==nil) || ([x string]==NULL)) {
		NSString *topicString = [[[NSString alloc] initWithString: @"Topic: "] stringByAppendingString:searchString];
		int res = NSRunInformationalAlertPanel(NLS(@"Can't find help for topic, would you like to expand the search?"), topicString, NLS(@"No"), NLS(@"Yes"), nil);
		if (!res)
			[[REngine mainEngine] executeString:[NSString stringWithFormat:@"print(help.search(\"%@\"))", searchString]];
		return;
	}
	NSString *url = [NSString stringWithFormat:@"file://%@",[x string]];
	if(url != nil)
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	
	[helpWindow makeKeyAndOrderFront:self];
	[x release];
}

- (NSWindow*) window
{
	return helpWindow;
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
	NSString *url = [[NSBundle mainBundle] resourcePath];
	if (!url) {
		REngine *re = [REngine mainEngine];	
		RSEXP *x= [re evaluateString:@"file.path(R.home(),\"RMacOSX-FAQ.html\")"];
		if(x==nil)
			return;
		url = [x string];
		[x release];
		if (url) url = [NSString stringWithFormat:@"file://%@", url];
	} else
		url = [NSString stringWithFormat:@"file://%@/RMacOSX-FAQ.html", url];

	if(url != nil) {
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
		[helpWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction)whatsNew:(id)sender
{
	REngine *re = [REngine mainEngine];	
	/* syntax-highlighting kills us, so we use TextEdit for now */
	[re executeString:@"system(paste('open -a /Applications/TextEdit.app',file.path(R.home(),'NEWS')))"];
	{
		NSBundle* myBundle = [NSBundle mainBundle];
		if (myBundle)
			system([[NSString stringWithFormat:@"open -a /Applications/TextEdit.app \"%@/NEWS\"", [myBundle resourcePath]] UTF8String]);
	}
	/*
	 RSEXP *x= [re evaluateString:@"file.show(file.path(R.home(),\"NEWS\"))"];
	 if(x==nil)
		return;
	[x release]; */
	
}

+ (id) sharedController{
	return sharedHMController;
}

- (IBAction)printDocument:(id)sender
{
	NSPrintInfo *printInfo;
	NSPrintInfo *sharedInfo;
	NSPrintOperation *printOp;
	NSMutableDictionary *printInfoDict;
	NSMutableDictionary *sharedDict;
	
	sharedInfo = [NSPrintInfo sharedPrintInfo];
	sharedDict = [sharedInfo dictionary];
	printInfoDict = [NSMutableDictionary dictionaryWithDictionary:
		sharedDict];
	
	printInfo = [[NSPrintInfo alloc] initWithDictionary: printInfoDict];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:[[[HelpView mainFrame] frameView] documentView] 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
}

- (void) setSearchType:(int) type
{
	if (type==kFuzzyMatch || type==kExactMatch) {
		NSMenu *m = [(NSSearchFieldCell*)searchField searchMenuTemplate];
		
		searchType = type;
		[[m itemWithTag:kFuzzyMatch] setState:(searchType==kFuzzyMatch)?NSOnState:NSOffState];
		[[m itemWithTag:kExactMatch] setState:(searchType==kExactMatch)?NSOnState:NSOffState];
		[(NSSearchFieldCell*)searchField setSearchMenuTemplate:m];
	}
}

- (void) awakeFromNib
{
	[self setSearchType:kExactMatch];
}

- (IBAction)changeSearchType:(id)sender
{
	[self setSearchType:[sender tag]];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	[back setEnabled: [sender canGoBack]];
	[forward setEnabled: [sender canGoForward]];
}

@end
