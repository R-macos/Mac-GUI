/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-11  The R Foundation
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
 *  RDataEditorTableView.m
 *
 *  Created by Hans-J. Bibiko on 21/06/2011.
 *
 */

#import "RDataEditorTableView.h"
#import "RGUI.h"
#import "../REditor.h"

extern SEXP ssNA_STRING;
extern double ssNA_REAL;
extern SEXP work, names;
extern void printelt(SEXP invec, int vrow, char *strp);
extern const char *get_col_name(int col);

#pragma mark -
#pragma mark Private API

@interface RDataEditorTableView (PrivateAPI)

- (NSString*) _getStringDataForColumn:(NSInteger)col andRow:(NSInteger)row;

@end

@implementation  RDataEditorTableView (PrivateAPI)

- (NSString*) _getStringDataForColumn:(NSInteger)col andRow:(NSInteger)row
{
	SEXP tmp = VECTOR_ELT(work, col);
	NSString *cellData = @"";
	if (!isNull(tmp)) {
		if(LENGTH(tmp)>row) {
			int buflen = 1025;
			// get the number of utf-8 bytes
			if (TYPEOF(tmp) == STRSXP && CHAR(STRING_ELT(tmp, row)))
				buflen = strlen(CHAR(STRING_ELT(tmp, row)))+1;
			char buf[buflen];
			buf[0] = '\0';
			printelt(tmp, row, buf);
			cellData = [NSString stringWithUTF8String:buf];
		}
	}
	return cellData;
}

@end

#pragma mark -

@implementation RDataEditorTableView


/**
 * Handles the general Copy action of selected rows as tab delimited data
 */
- (void)copy:(id)sender
{
	NSString *tmp = nil;

	switch([sender tag]) {
		case 0:
		tmp = [self rowsAsTabStringWithHeaders:YES];
		break;
		case 1:
		tmp = [self rowsAsCsvStringWithHeaders:YES];
		break;
		default:
		NSBeep();
		return;
	}

	if ( nil != tmp )
	{
		NSPasteboard *pb = [NSPasteboard generalPasteboard];

		[pb declareTypes:[NSArray arrayWithObjects:
								NSTabularTextPboardType,
								NSStringPboardType,
								nil]
				   owner:nil];

		[pb setString:tmp forType:NSStringPboardType];
		[pb setString:tmp forType:NSTabularTextPboardType];
	}

}

- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

- (NSString *)rowsAsTabStringWithHeaders:(BOOL)withHeaders
{
	if (![self numberOfSelectedRows]) return nil;

	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSUInteger i;
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		for( i = 1; i <= numColumns; i++ ){
			if([result length])
				[result appendString:@"\t"];
			[result appendString:[NSString stringWithUTF8String:get_col_name(i)]];
		}
		[result appendString:@"\n"];
	}

	// Loop through the rows, adding their descriptive contents
	NSUInteger rowIndex = [selectedRows firstIndex];
	
	while ( rowIndex != NSNotFound )
	{
		for ( i = 0; i < numColumns; i++ )
			[result appendFormat:@"%@\t", [self _getStringDataForColumn:i andRow:rowIndex]];

		// Remove the trailing tab and add the linebreak
		if ([result length])
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];

		[result appendString:@"\n"];
	
		// Select the next row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}
	
	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;

}

- (NSString *)rowsAsCsvStringWithHeaders:(BOOL)withHeaders
{
	if (![self numberOfSelectedRows]) return nil;

	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSUInteger i;
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		for( i = 1; i <= numColumns; i++ ){
			if([result length])
				[result appendString:@","];
			[result appendFormat:@"\"%@\"", [[NSString stringWithUTF8String:get_col_name(i)] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
		}
		[result appendString:@"\n"];
	}

	// Loop through the rows, adding their descriptive contents
	NSUInteger rowIndex = [selectedRows firstIndex];
	
	while ( rowIndex != NSNotFound )
	{
		for ( i = 0; i < numColumns; i++ )
			[result appendFormat:@"\"%@\",", [[self _getStringDataForColumn:i andRow:rowIndex] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];

		// Remove the trailing comma and add the linebreak
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:@"\n"];

		// Select the next row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}

	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;
}

- (CGFloat)widthForColumn:(NSInteger)columnIndex andHeaderName:(NSString*)colName
{

	CGFloat        columnBaseWidth;
	NSString       *contentString;
	NSUInteger     cellWidth, maxCellWidth, i;
	NSRange        linebreakRange;
	double         rowStep;

	NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
	 															 forKey:NSFontAttributeName];

	NSCharacterSet *newLineCharSet = [NSCharacterSet newlineCharacterSet];

	NSInteger rowsToCheck = 100;
	NSUInteger maxRows = [[self delegate] numberOfRowsInTableView:self];

	// Check the number of rows available to check, sampling every n rows
	if (maxRows < rowsToCheck)
		rowStep = 1;
	else
		rowStep = floor(maxRows / rowsToCheck);

	rowsToCheck = (rowsToCheck > maxRows) ? maxRows : rowsToCheck;

	// Set a default padding for this column
	columnBaseWidth = 32.0f;

	// Iterate through the data store rows, checking widths
	maxCellWidth = 0;
	for (i = 0; i < rowsToCheck; i += rowStep) {

		// Retrieve the cell's content
		SEXP tmp = VECTOR_ELT(work, columnIndex-1);

		contentString = @"";
		if (!isNull(tmp)) {
			if(LENGTH(tmp)>i) {
				int buflen = 1025;
				// get the number of utf-8 bytes
				if (TYPEOF(tmp) == STRSXP && CHAR(STRING_ELT(tmp, i)))
					buflen = strlen(CHAR(STRING_ELT(tmp, i)))+1;
				char buf[buflen];
				buf[0] = '\0';
				printelt(tmp, (int)i, buf);
				contentString = [NSString stringWithUTF8String:buf];
			}
		}

		if ([(NSString *)contentString length] > 500) {
			contentString = [contentString substringToIndex:500];
		}

		// If any linebreaks are present, use only the visible part of the string
		linebreakRange = [contentString rangeOfCharacterFromSet:newLineCharSet];
		if (linebreakRange.location != NSNotFound) {
			contentString = [contentString substringToIndex:linebreakRange.location];
		}

		// Calculate the width, using it if it's higher than the current stored width
		cellWidth = [contentString sizeWithAttributes:stringAttributes].width;
		if (cellWidth > maxCellWidth) maxCellWidth = cellWidth;
		if (maxCellWidth > 400) {
			maxCellWidth = 400;
			break;
		}
	}

	// Add the padding
	maxCellWidth += columnBaseWidth;

	// If the header width is wider than this expanded width, use it instead
	if(colName) {
		cellWidth = [colName sizeWithAttributes:[NSDictionary dictionaryWithObject:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]] forKey:NSFontAttributeName]].width;
		if (cellWidth + columnBaseWidth > maxCellWidth) maxCellWidth = cellWidth + columnBaseWidth;
		if (maxCellWidth > 400) maxCellWidth = 400;
	}

	return maxCellWidth;
}

- (void)setFont:(NSFont *)font;
{
	NSArray *tableColumns = [self tableColumns];
	NSUInteger columnIndex = [tableColumns count];
	
	while (columnIndex--) 
	{
		[[(NSTableColumn *)[tableColumns objectAtIndex:columnIndex] dataCell] setFont:font];
	}
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{

	SLog(@"RDataEditorTableView received selector %@", NSStringFromSelector(command));

	NSInteger row, column;

	row = [self editedRow];
	column = [self editedColumn];

	// Trap down arrow key
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(moveDown:)] )
	{

		NSInteger newRow = row+1;
		if (newRow >= [[self delegate] numberOfRowsInTableView:self]) return YES; //check if we're already at the end of the list

		[[control window] makeFirstResponder:control];

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		return YES;

	}

	// Trap up arrow key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(moveUp:)] )
	{

		if (row==0) return YES; //already at the beginning of the list
		NSInteger newRow = row-1;

		if (newRow>=[[self delegate] numberOfRowsInTableView:self]) return YES; // saveRowToTable could reload the table and change the number of rows
		[[control window] makeFirstResponder:control];

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}

	return NO;

}

- (void)keyDown:(NSEvent*)theEvent
{
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	long curFlags = ([theEvent modifierFlags] & allFlags);

	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	// or for non-US keyboards to allow to enter dead keys
	// e.g. for German keyboard ` is a dead key, press space to enter `
	if ((curFlags & allFlags) == NSAlternateKeyMask || [[theEvent characters] length] == 0) {
		[super keyDown:theEvent];
		return;
	}

	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];

	// ⇧⌥⌘C - add col as CHARACTER
	if(((curFlags & allFlags) == (NSCommandKeyMask|NSAlternateKeyMask|NSShiftKeyMask)) && [charactersIgnMod isEqualToString:@"C"]) {
		NSMenuItem *m = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
		[m setTag:2];
		[[self delegate] addCol:m];
		[m release];
		return;
	}

	// ⌥⌘C - add col as NUMERIC
	if(((curFlags & allFlags) == (NSCommandKeyMask|NSAlternateKeyMask)) && [charactersIgnMod isEqualToString:@"c"]) {
		NSMenuItem *m = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
		[m setTag:1];
		[[self delegate] addCol:m];
		[m release];
		return;
	}

	// ⌥⌘A - add row
	if(((curFlags & allFlags) == (NSCommandKeyMask|NSAlternateKeyMask)) && [charactersIgnMod isEqualToString:@"a"]) {
		[[self delegate] addRow:nil];
		return;
	}

	// ^⌥⌘⎋ cancel editing without saving data
	if(((curFlags & allFlags) == (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) && [theEvent keyCode] == 51) {
		[[self delegate] cancelEditing:nil];
		return;
	}

	// ⌘⌫ delete selected rows or columns according to selection
	if((curFlags & allFlags) == NSCommandKeyMask && [theEvent keyCode] == 51) {
		if([[self selectedColumnIndexes] count])
			[[self delegate] remCols:nil];
		else if([[self selectedRowIndexes] count])
			[[self delegate] remRows:nil];
		else
			NSBeep();
		return;
	}

	[super keyDown:theEvent];

}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	if ([menuItem action] == @selector(copy:)) {
		return ([self numberOfSelectedRows] > 0);
	}
	if ([menuItem action] == @selector(remSelection:)) {
		return ([[self selectedColumnIndexes] count] || [[self selectedRowIndexes] count]);
	}

	return YES;

}

@end
