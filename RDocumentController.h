/* RDocumentController */

#import <Cocoa/Cocoa.h>

@interface RDocumentController : NSDocumentController
{
}

- (IBAction)newDocument:(id)sender;
- (IBAction)openDocument:(id)sender;
- (id)openDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag;
- (id)openRDocumentWithContentsOfFile:(NSString *)aFile display:(BOOL)flag;

@end
