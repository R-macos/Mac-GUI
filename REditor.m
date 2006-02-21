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

#include "privateR.h"
// needs Defn.h Print.h
#import "RGUI.h"
#import "REditor.h"
#include <R.h>
#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <Rdefines.h>
#include <Rinternals.h>
#include <Rversion.h>


#ifndef max
#define max(x,y) x<y?y:x;
#endif

int newvar;
static id sharedDEController;

extern  SEXP work, names, lens;
extern int xmaxused, ymaxused;

extern SEXP ssNA_STRING;
extern double ssNA_REAL;
extern SEXP ssNewVector(SEXPTYPE type, int vlen);
extern PROTECT_INDEX wpi, npi, lpi;
extern int nprotect;
typedef enum { UP, DOWN, LEFT, RIGHT } DE_DIRECTION;

typedef enum {UNKNOWNN, NUMERIC, CHARACTER} CellType;

BOOL IsDataEntry;
 
char *get_col_name(int col)
{
    static char clab[25];
    if (col <= xmaxused) {
	/* don't use NA labels */
	SEXP tmp = STRING_ELT(names, col - 1);
	if(tmp != NA_STRING) return(CHAR(tmp));
    }
    sprintf(clab, "var%d", col);
    return clab;
}
 
CellType get_col_type(int col)
{
    SEXP tmp;
    CellType res = UNKNOWNN;

    if (col <= xmaxused) {
	tmp = VECTOR_ELT(work, col - 1);
	if(TYPEOF(tmp) == REALSXP) res = NUMERIC;
	if(TYPEOF(tmp) == STRSXP) res = CHARACTER;
    }
    return res;
}


void printelt(SEXP invec, int vrow, char *strp)
{

    if(!strp)
     return;
     
     
    PrintDefaults(R_NilValue);
    if (TYPEOF(invec) == REALSXP) {
	if (REAL(invec)[vrow] != ssNA_REAL) {
#if (R_VERSION >= R_Version(2,2,0))
	    strcpy(strp, EncodeElement(invec, vrow, 0, '.'));
#else
	    strcpy(strp, EncodeElement(invec, vrow, 0));
#endif
	    return;
	}
    }
    else if (TYPEOF(invec) == STRSXP) {
    if(CHAR(STRING_ELT(invec, vrow))){
	if (!streql(CHAR(STRING_ELT(invec, vrow)),
		    CHAR(STRING_ELT(ssNA_STRING, 0)))) {
#if (R_VERSION >= R_Version(2,2,0))
	    strcpy(strp, EncodeElement(invec, vrow, 0, '.'));
#else
	    strcpy(strp, EncodeElement(invec, vrow, 0));
#endif
	    return;
	}
    }
    }
    else
	error("dataentry: internal memory error"); /* FIXME: localize */
}

@implementation REditor



- (id)init
{

    self = [super init];
    if (self) {
		sharedDEController = self;
		// Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		toolbar = nil;

    }
	
    return self;
}

- (void) awakeFromNib {
	
	[self setupToolbar];
}

- (void)dealloc {
	[super dealloc];
}

/* These two routines are needed to update the  TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return ymaxused;
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
		row: (int)row
{
	int i = [[tableColumn identifier] intValue];
	if(i > xmaxused)
		return @"";
	
 	SEXP tmp = VECTOR_ELT(work, i-1);
 	char buf[1025];
 	buf[0] = '\0';
 	if (!isNull(tmp)) {
	 		if(LENGTH(tmp)>row){
		 			printelt(tmp, row, buf);
		 			return [NSString stringWithUTF8String:buf];
		 		} else return @"";
	 	} else return @"";
 
 
}


- (void)tableView:(NSTableView *)aTableView
	setObjectValue:anObject
	forTableColumn:(NSTableColumn *)tableColumn
	row:(int)row
{
	int col;
	if(row<0) return;
	SEXP tmp;
	char buf[256];
	
	buf[0] = '\0';

	col = [[tableColumn identifier] intValue];
	
	tmp = VECTOR_ELT(work, col-1);
	
 	CFStringGetCString((CFStringRef)anObject, buf, 255,  kCFStringEncodingMacRoman);
	

	
	switch(get_col_type(col)){
		case NUMERIC:
			if(buf[0] == '\0') 
				REAL(tmp)[row] = NA_REAL;
			 else {
					char *endp;
					double new = R_strtod(buf, &endp);
					REAL(tmp)[row] = new;
					INTEGER(lens)[col-1] = max(INTEGER(lens)[col-1],row+1);
			 }
		break;

		case CHARACTER:
			if(buf[0] == '\0')
				SET_STRING_ELT(tmp, row, NA_STRING);
			 else 
				SET_STRING_ELT(tmp, row, mkChar(buf));
			INTEGER(lens)[col-1] = max(INTEGER(lens)[col-1],row+1);
		break;

		default:
		break;
	}
	return;
}


- (void)setDatas:(BOOL)removeAll
{
	int i;
    NSArray		*theColumns;
	
	if(removeAll){
		theColumns = [editorSource tableColumns];
		while ([theColumns count]) 
			[editorSource removeTableColumn:[theColumns objectAtIndex:0]];
	}

    for (i = 1; i <= xmaxused ; i++) {
		NSTableColumn *col;
		col = [[[NSTableColumn alloc] initWithIdentifier:[NSNumber numberWithInt:i]] autorelease];
		[[col headerCell] setTitle:[NSString stringWithUTF8String:get_col_name(i)]];
        [col setWidth: 50];
        [col setMaxWidth: 300];
		[col sizeToFit];
        [editorSource addTableColumn: col];
	}
	[editorSource reloadData];

}


- (id) window
{
	return dataWindow;
}

- (BOOL)windowShouldClose:(id)sender{
	
	if(IsDataEntry){
		[NSApp stopModal];
		IsDataEntry = NO;
	}
	return YES;

}



- (void) setupToolbar {
	
    // Create a new toolbar instance, and attach it to our document window 
	toolbar = [[[NSToolbar alloc] initWithIdentifier: DataEditorToolbarIdentifier] autorelease];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [dataWindow setToolbar: toolbar];
}
 
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    
    if ([itemIdent isEqual: AddColToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLSC(@"Add Col",@"Add column - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel: NLS(@"Add Column")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Adds a new columns to the right of a group of selected colums or just at the end of the data")];
		[toolbarItem setImage: [NSImage imageNamed: @"add_col"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(addCol:)];
    } else  if ([itemIdent isEqual: RemoveColsToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLSC(@"Remove Col",@"Remove columns - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel: NLS(@"Remove Columns")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Remove selected columns")];
		[toolbarItem setImage: [NSImage imageNamed: @"rem_col"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(remCols:)];
    } else  if ([itemIdent isEqual: AddRowToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLSC(@"Add Row",@"Add row - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel: NLS(@"Add New Row")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Adds a row below a group of selected rows or at the bottom of the data")];
		[toolbarItem setImage: [NSImage imageNamed: @"add_row"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(addRow:)];
    } else  if ([itemIdent isEqual: RemoveRowsToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLSC(@"Remove Row",@"Remove row - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel: NLS(@"Remove Rows")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Removes selected rows")];
		[toolbarItem setImage: [NSImage imageNamed: @"rem_row"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(remRows:)];
    } else {
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
    }
    return toolbarItem;
}


- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default    
    // If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
    // user chooses to revert to the default items this set will be used 
    return [NSArray arrayWithObjects:	AddColToolbarItemIdentifier,  RemoveColsToolbarItemIdentifier, 
		AddRowToolbarItemIdentifier,  RemoveRowsToolbarItemIdentifier, nil];
}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
    // The set of allowed items is used to construct the customization palette 
    return [NSArray arrayWithObjects: 	AddColToolbarItemIdentifier,  RemoveColsToolbarItemIdentifier, 
		AddRowToolbarItemIdentifier,  RemoveRowsToolbarItemIdentifier
		, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place 
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being 
    // added is found by referencing the @"item" key in the userInfo 
//    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
    // the chance to tear down information related to the item that may have been cached.   The notification object
    // is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
    // key in the userInfo 
	// NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method:  This message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
    BOOL enable = NO;

	if ([[toolbarItem itemIdentifier] isEqual: AddColToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: RemoveColsToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: AddRowToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: RemoveRowsToolbarItemIdentifier]) {
		enable = YES;
    }		
    return enable;
}

/* Adds a column to the data either at the end or after the last columns selected by the user */

-(IBAction) addCol:(id)sender{
	char clab[25];
	int lastcol, i;
	SEXP names2, work2;
	/* extend work, names and lens */
	NSIndexSet *cols =  [editorSource selectedColumnIndexes];			
	lastcol = [cols lastIndex];
	if(lastcol == NSNotFound)
		lastcol = xmaxused -1;
	
	xmaxused++;
	newvar++;
	PROTECT(names2 = duplicate(names)); nprotect++;
	PROTECT(work2 = duplicate(work)); nprotect++;
	
	REPROTECT(work = allocVector(VECSXP, xmaxused), wpi);
	REPROTECT(names = allocVector(STRSXP, xmaxused), npi);
	REPROTECT(lens = allocVector(INTSXP, xmaxused), lpi);
	
	
	for (i = 0; i <= lastcol; i++) {
		SET_VECTOR_ELT(work, i, VECTOR_ELT(work2,i));
		SET_VECTOR_ELT(names, i, VECTOR_ELT(names2,i));
		INTEGER(lens)[i] = ymaxused;
	}

	sprintf(clab, "var%d", newvar);
	SET_STRING_ELT(names, lastcol+1, mkChar(clab));
	INTEGER(lens)[lastcol+1] = ymaxused;
    SET_VECTOR_ELT(work, lastcol+1, ssNewVector(REALSXP, ymaxused));
	
	for (i = lastcol+2; i <xmaxused; i++) {
		SET_VECTOR_ELT(work, i, VECTOR_ELT(work2,i-1));
		SET_VECTOR_ELT(names, i, VECTOR_ELT(names2,i-1));
		INTEGER(lens)[i] = ymaxused;
	}
	
	[[REditor getDEController] setDatas:YES];	
}

/* remove selected columns */
-(IBAction) remCols:(id)sender
{
	SEXP work2,names2;
	int i,j,ncols;
	int *colidx;

	NSIndexSet *cols =  [editorSource selectedColumnIndexes];			
	unsigned current_index = [cols firstIndex];
	if(current_index == NSNotFound)
		return;
	
	ncols = [editorSource numberOfSelectedColumns];
	colidx = (int *)malloc(xmaxused);
	if(!colidx)
		return;
	for(i =0; i<xmaxused;i++) 
		colidx[i] = i;
	
	
	while (current_index != NSNotFound){
		colidx[current_index] = -1; 
		current_index = [cols indexGreaterThanIndex: current_index];
	}
	
	PROTECT(work2 = allocVector(VECSXP, xmaxused-ncols)); nprotect++;
	PROTECT(names2 = allocVector(STRSXP, xmaxused-ncols)); nprotect++;
	
	for(i = 0, j = 0; i < xmaxused; i++) {
	    if(!isNull(VECTOR_ELT(work, i))  && (colidx[i] != -1)) {
			SET_VECTOR_ELT(work2, j, VECTOR_ELT(work, i));
			INTEGER(lens)[j] = INTEGER(lens)[i];
			SET_STRING_ELT(names2, j, STRING_ELT(names, i));
			j++;
	    }
	}

	REPROTECT(names = duplicate(names2), npi);
	REPROTECT(work = duplicate(work2), wpi);
	
	xmaxused = xmaxused - ncols;
	REPROTECT(lens = allocVector(INTSXP, xmaxused), lpi);
	for(i=0; i < xmaxused; i++)
		INTEGER(lens)[i] = ymaxused;
	
	if(colidx)
		free(colidx);
	[[REditor getDEController] setDatas:YES];	
	
	
}

/* Adds a row to the data either at the end or after the last row selected by the user */
/* FIXME: it actually crashes if a row is added in the middle of the data */

-(IBAction) addRow:(id)sender{
	int col, row, lastrow;
	SEXP tmp, tmp2, work2;
	SEXPTYPE type;
	
	NSIndexSet *rows =  [editorSource selectedRowIndexes];			
	lastrow = [rows lastIndex]; /* last row selected by the user */
	if(lastrow == NSNotFound)
		lastrow = ymaxused - 1;

	ymaxused++;
	PROTECT(work2 = allocVector(VECSXP, xmaxused)); nprotect++;

	for(col=1; col<= xmaxused; col++){
		if (!isVector(tmp = VECTOR_ELT(work, col-1)))
			error("internal type error in dataentry");
		type = TYPEOF(tmp);
		tmp2 = ssNewVector(type, ymaxused);
		for (row = 0; row <= lastrow; row++){
			if (type == REALSXP)
				REAL(tmp2)[row] = REAL(tmp)[row];
			else if (type == STRSXP)
				SET_STRING_ELT(tmp2, row, STRING_ELT(tmp, row));
			else
				error("internal type error in dataentry");
		}
		
		for (row = lastrow+2; row < ymaxused; row++)
			if (type == REALSXP)
				REAL(tmp2)[row] = REAL(tmp)[row-1];
			else if (type == STRSXP)
				SET_STRING_ELT(tmp2, row, STRING_ELT(tmp, row));
			else
				error("internal type error in dataentry");
		
		SET_VECTOR_ELT(work2, col-1, tmp2);	
		INTEGER(lens)[col - 1] = ymaxused;
	}
	REPROTECT(work = duplicate(work2), wpi);
	[[REditor getDEController] setDatas:YES];	
}

/* removes selected rows */
-(IBAction) remRows:(id)sender{

	SEXP tmp, newc;
	int idx,col,row,nrows;
	SEXPTYPE type;

	NSIndexSet *rows =  [editorSource selectedRowIndexes];			
	nrows = [rows count];
	if (nrows<1) return;
	
	for(col=1; col<= xmaxused; col++){
		idx = 0;
		if (!isVector(tmp = VECTOR_ELT(work, col-1)))
			error("internal type error in dataentry");
		if (LENGTH(tmp)!=ymaxused)
			error("a data vector is of different length than the table");
		type = TYPEOF(tmp);
		PROTECT(newc = allocVector(type, ymaxused - nrows));
		for(row=0; row<ymaxused; row++){
			if(![rows containsIndex: row]){
				if (type == REALSXP)
					REAL(newc)[idx] = REAL(tmp)[row];
				else if (type == STRSXP)
					SET_STRING_ELT(newc, idx, duplicate(STRING_ELT(tmp, row)));
				else
					error("internal type error in dataentry");	
				idx++;
			}
		}
		UNPROTECT(1);
		
		INTEGER(lens)[col - 1] -= nrows;
		SET_VECTOR_ELT(work, col-1, newc);	
	}

	ymaxused -= nrows;

	[[REditor getDEController] setDatas:YES];	
	
 
}

+ (id) getDEController{
	return sharedDEController;
}


+ (void)startDataEntry
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	newvar = 0;
	[[REditor getDEController] setDatas:YES];	
	[[[REditor getDEController] window] orderFront:self];
	[NSApp runModalForWindow:[[REditor getDEController] window]];

	[pool release];
}


@end
