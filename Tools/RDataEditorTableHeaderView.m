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
 *  Code snippets were taken from http://cocotron.googlecode.com/svn/trunk/AppKit/NSTableHeaderView.m
 *  Copyright (c) 2006-2007 Christopher J. W. Lloyd
 *
 *
 *  RDataEditorTableHeaderView.m
 *
 *  Created by Hans-J. Bibiko on 05/07/2011.
 *
 */

#import "RDataEditorTableHeaderView.h"
#import "../REditor.h"

@interface RDataEditorTableHeaderView (Private)

- (NSRect)_resizeRectBeforeColumn:(NSInteger)column;

@end

@implementation RDataEditorTableHeaderView (private)

- (NSRect)_resizeRectBeforeColumn:(NSInteger)column
{
	NSRect rect=[self headerRectOfColumn:column];

	rect.origin.x -= 2;
	rect.size.width = 6;

	return rect;
}

@end

#pragma mark -

@implementation RDataEditorTableHeaderView

// -(void)mouseDown:(NSEvent *)theEvent
// {
// 	// Submit pending changes of column names
// 	if([[[NSApp keyWindow] firstResponder] isKindOfClass:[NSTextView class]])
// 		[[self.tableView delegate] textView:(NSTextView*)[[NSApp keyWindow] firstResponder] doCommandBySelector:@selector(insertNewline:)];
// }
// 
-(void)mouseDown:(NSEvent *)theEvent
{
	NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger clickedColumn = [self columnAtPoint:location];

	// Submit pending changes of column names
	if([[[NSApp keyWindow] firstResponder] isKindOfClass:[NSTextView class]])
		[[self.tableView delegate] textView:(NSTextView*)[[NSApp keyWindow] firstResponder] doCommandBySelector:@selector(insertNewline:)];

	// check if delegate implemented tableView:mouseDownInHeaderOfTableColumn:
	if ([[self.tableView delegate] respondsToSelector:@selector(tableView:mouseDownInHeaderOfTableColumn:)]) {
		if(clickedColumn != -1)
			[[self.tableView delegate] tableView:self.tableView mouseDownInHeaderOfTableColumn:[[self.tableView tableColumns] objectAtIndex:clickedColumn]];
		if([[NSApp currentEvent] clickCount] > 1) {
			// deselect clicked column for editing column name and return
			[self.tableView deselectAll:nil];
			return;
		}
	}

	// resizing mode
	if ([self.tableView allowsColumnResizing]) {
		NSInteger i, count=[[self.tableView tableColumns] count];

		// ends editing
		if ([self.tableView editedColumn] != -1 || [self.tableView editedRow] != -1)
			[[self window] endEditingFor:nil];

		for (i = 1; i < count; ++i) {
			if (NSMouseInRect(location, [self _resizeRectBeforeColumn:i], [self isFlipped])) {
				NSTableColumn *resizingColumn = [[self.tableView tableColumns] objectAtIndex:i-1];

				if ([resizingColumn resizingMask] == NSTableColumnNoResizing)
					return;

				//FIXME: self.resizedColumn = i - 1;
				location=[self convertPoint:[theEvent locationInWindow] fromView:nil];
				do {
					NSPoint newPoint;
					NSRect newRect;
					NSInteger q;
					CGFloat newWidth=newPoint.x;

					theEvent=[[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];
					newPoint=[self convertPoint:[theEvent locationInWindow] fromView:nil];

					newWidth=newPoint.x;
					for (q = 0; q < self.resizedColumn; ++q) {
						newWidth -= [[[self.tableView tableColumns] objectAtIndex:q] width];
						newWidth -= [self.tableView intercellSpacing].width;
					}

					[resizingColumn setWidth:newWidth];

					[self.tableView tile];
					newRect.origin=[self.tableView convertPoint:newPoint fromView:self];
					newRect.size=NSMakeSize(10,10);
					[self.tableView scrollRectToVisible:newRect];

					location=newPoint;
				} while ([theEvent type] != NSLeftMouseUp);

				[[self window] invalidateCursorRectsForView:self];

				//self.resizedColumn = -1;
				return;
			}
		}
	}

	// column selection including the chance to select non-continous columns via holding ⌘
	if ([self.tableView allowsColumnSelection]) {
		// extend/change selection
		if ([theEvent modifierFlags] & NSCommandKeyMask) {
			// deselect previously selected?
			if ([self.tableView isColumnSelected:clickedColumn])
				[self.tableView deselectColumn:clickedColumn];
			else if ([self.tableView allowsMultipleSelection] == YES) {
				// add to selection
				[self.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex:clickedColumn] byExtendingSelection:YES];
			}
		}
		else if ([theEvent modifierFlags] & NSShiftKeyMask) {
			NSInteger firstColumn = [self.tableView selectedColumn];
			NSInteger lastColumn  = clickedColumn;

			if (firstColumn == -1)
				firstColumn = 0;
			if (firstColumn > lastColumn) {
				lastColumn = firstColumn;
				firstColumn = clickedColumn;
			}

			[self.tableView deselectAll:nil];
			while (firstColumn <= lastColumn)
				[self.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex:firstColumn++] byExtendingSelection:YES];
		}
		else
			[self.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex:clickedColumn] byExtendingSelection:NO];
	}

}

@end
