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
 *                     Copyright (C) 1998-2012   The R Development Core Team
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
 *  Created by Simon Urbanek on Tue Jul 13 2004.
 *
 */

/* Rcallbacks define the interface between R and Cocoa.
   Each callback in R is mapped to the corresponding methods of the callback object. The current callback object should be always obtained dynamically fromt he REngine to ensure correct communication, potentially across threads. The acutal implementation of the functionality is left to the object implementing the callback interface. */

#ifndef __R_CALLBACKS__H__
#define __R_CALLBACKS__H__

/* this part is relevant only in included in Obj-C files */
#ifdef __OBJC__

#import "RSEXP.h"

/* protocol defining the callback interface on the Cocoa side, that is the receiving object. */
@protocol REPLHandler
- (void)  handleWriteConsole: (NSString*) msg withType: (int) oType;
- (char*) handleReadConsole: (int) addtohist;
- (void)  handleBusy: (BOOL) which;
- (void)  handleFlushConsole;
- (void)  handleWritePrompt: (NSString*) prompt;
- (void)  handleProcessEvents;
- (int)   handleChooseFile: (const char*) buf len: (int) length isNew: (int) new;
- (void)  handleShowMessage: (const char*) msg;
- (void)  handleProcessingInput: (char*) cmd;
- (int)   handleEdit: (const char*) file;
- (int)   handleEditFiles: (int) nfile withNames: (const char**) file titles: (const char**) wtitle pager: (const char*) pager;
- (int)   handleShowFiles: (int) nfile withNames: (const char**) file headers: (const char**) headers windowTitle: (const char*) wtitle pager: (const char*) pages andDelete: (BOOL) del;
@end

/* protocol defining additional callbacks specific to Aqua/Cocoa GUI */
@protocol CocoaHandler
// return value is unused so far - the return value on R side is 'stat', so any changes to that parameter are propagated to R
- (int) handlePackages: (int) count withNames: (const char**) name descriptions: (const char**) desc URLs: (const char**) url status: (BOOL*) stat;
// return value: 0=cancel, 1=ok
- (int) handleListItems: (int) count withNames: (const char**) name status: (BOOL*) stat multiple: (BOOL) multiple title: (NSString*) title;
// returns either nil or array of booleans of the size 'count' specifying which datasets to load
- (BOOL*) handleDatasets: (int) count withNames: (const char**) name descriptions: (const char**) desc packages: (const char**) pkg URLs: (const char**) url;
// return value is unused so far
- (int) handleInstalledPackages: (int) count withNames: (const char**) name installedVersions: (const char**) iver repositoryVersions: (const char**) rver update: (BOOL*) stat label: (const char*) label;
// its usage is identical to that of the 'system' command
- (int) handleSystemCommand: (const char*) cmd;
- (int) handleHelpSearch: (int) count withTopics: (const char**) topics packages: (const char**) pkgs descriptions: (const char**) descs urls: (const char**) urls title: (const char*) title;
- (int) handleCustomPrint: (const char*) type withObject: (RSEXP*) obj;
@end

#endif /* end of Obj-C code */

#include <R.h>
#include <Rinternals.h>
#include <stdio.h>

/* since R 2.7.0 (r43767) those are const */
#define R_EAPI_CONST const

/* functions provided as R callbacks */
int  Re_ReadConsole(R_EAPI_CONST char *prompt, unsigned char *buf, int len, int addtohistory);
void Re_RBusy(int which);
void Re_WriteConsole(R_EAPI_CONST char *buf, int len);
void Re_WriteConsoleEx(R_EAPI_CONST char *buf, int len, int oType);
void Re_ResetConsole();
void Re_FlushConsole();
void Re_ClearerrConsole();
int  Re_ChooseFile(int new, char *buf, int len);
void Re_ShowMessage(R_EAPI_CONST char *buf);
void Re_read_history(char *buf);
void Re_loadhistory(SEXP call, SEXP op, SEXP args, SEXP env);
void Re_savehistory(SEXP call, SEXP op, SEXP args, SEXP env);
int  Re_ShowFiles(int nfile, R_EAPI_CONST char **file, R_EAPI_CONST char **headers, R_EAPI_CONST char *wtitle, Rboolean del, R_EAPI_CONST char *pager);
int  Re_EditFiles(int nfile, R_EAPI_CONST char **file, R_EAPI_CONST char **title, R_EAPI_CONST char *pager);
int  Re_Edit(R_EAPI_CONST char *file);
int  Re_system(const char *cmd);

void Re_ProcessEvents(void);
SEXP Re_packagemanger(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_datamanger(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_browsepkgs(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_do_wsbrowser(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_do_hsbrowser(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_dataentry(SEXP call, SEXP op, SEXP args, SEXP rho);
SEXP Re_do_selectlist(SEXP call, SEXP op, SEXP args, SEXP rho);

#endif
