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

+ (id) getHMController{
	return sharedHMController;
}


@end
