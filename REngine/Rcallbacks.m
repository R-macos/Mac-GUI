
#include <Defn.h>
#include <R.h>
#include <Rdefines.h>
#include <Rinternals.h>

#include <sys/select.h>
#include <unistd.h>
#include <stdio.h>

#include "Print.h"

#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Parse.h>
#include <R_ext/eventloop.h>

#import "REngine.h"
#import "RController.h"
#import "RDocument.h"
#import "PackageManager.h"
#import "DataManager.h"
#import "PackageInstaller.h"
#import "WSBrowser.h"
#import "SearchTable.h"
#import "REditor.h"

/* from Defn.h */
extern Rboolean R_Interactive;   /* TRUE during interactive use*/

extern FILE*    R_Consolefile;   /* Console output file */
extern FILE*    R_Outputfile;   /* Output file */

/* from src/unix/devUI.h */

extern void (*ptr_R_Suicide)(char *);
extern void (*ptr_R_ShowMessage)();
extern int  (*ptr_R_ReadConsole)(char *, unsigned char *, int, int);
extern void (*ptr_R_WriteConsole)(char *, int);
extern void (*ptr_R_ResetConsole)();
extern void (*ptr_R_FlushConsole)();
extern void (*ptr_R_ClearerrConsole)();
extern void (*ptr_R_Busy)(int);
/* extern void (*ptr_R_CleanUp)(SA_TYPE, int, int); */
//extern int  (*ptr_R_ShowFiles)(int, char **, char **, char *, Rboolean, char *);
//extern int  (*ptr_R_EditFiles)(int, char **, char **, char *);
extern int  (*ptr_R_ChooseFile)(int, char *, int);
extern void (*ptr_R_loadhistory)(SEXP, SEXP, SEXP, SEXP);
extern void (*ptr_R_savehistory)(SEXP, SEXP, SEXP, SEXP);

//extern void (*ptr_R_StartCocoaRL)();

void Re_WritePrompt(char *prompt)
{
    [[REngine mainHandler] handleWritePrompt:[NSString stringWithCString:prompt]];
}

void Re_ProcessEvents(void){
	[[REngine mainHandler] handleProcessEvents];
}

static char *readconsBuffer=0;
static char *readconsPos=0;

int Re_ReadConsole(char *prompt, unsigned char *buf, int len, int addtohistory)
{
	Re_WritePrompt(prompt);

	if (!readconsBuffer) {
	    char *newc = [[REngine mainHandler] handleReadConsole: addtohistory];
	    if (!newc) return 0;
		readconsPos=readconsBuffer=newc;
	}
		
	if (readconsBuffer) {
		char *c = readconsPos;
		while (*c && *c!='\n' && *c!='\r') c++;
		if (*c=='\r' && c[1]!='\n') *c='\n'; /* this should fix mac-only line endings */
		if (*c) c++; /* if not at the end, point past the content to use */
		if (c-readconsPos>=len) c=readconsPos+(len-1);
		memcpy(buf, readconsPos, c-readconsPos);
		buf[c-readconsPos]=0;
		if (*c)
			readconsPos=c;
		else
			readconsPos=readconsBuffer=0;
		[[REngine mainHandler] handleProcessingInput: buf];
		return 1;
	}

    return 0;
}

void Re_RBusy(int which)
{
    [[REngine mainHandler] handleBusy: (which==0)?NO:YES];
}

void Re_WriteConsole(char *buf, int len)
{
	[[REngine mainHandler] handleWriteConsole: [NSString stringWithCString:buf length:len]];
}

/* Indicate that input is coming from the console */
void Re_ResetConsole()
{
}

/* Stdio support to ensure the console file buffer is flushed */
void Re_FlushConsole()
{
}

/* Reset stdin if the user types EOF on the console. */
void Re_ClearerrConsole()
{
}

int Re_ChooseFile(int new, char *buf, int len)
{
	return [[REngine mainHandler] handleChooseFile: buf len:len isNew:new];	
}

void Re_ShowMessage(char *buf)
{
	[[REngine mainHandler] handleShowMessage: buf];
}

int  Re_Edit(char *file){
	return [[REngine mainHandler] handleEdit: file];
}

int  Re_EditFiles(int nfile, char **file, char **wtitle, char *pager){
	return [[REngine mainHandler] handleEditFiles: nfile withNames: file titles: wtitle pager: pager];
}

int Re_ShowFiles(int nfile, char **file, char **headers, char *wtitle, Rboolean del, char *pager)
{
	return [[REngine mainHandler] handleShowFiles: nfile withNames: file headers: headers windowTitle: wtitle pager: pager andDelete: del];
}

//==================================================== the following callbacks are Cocoa-specific callbacks (see CocoaHandler)

int Re_system(char *cmd) {
	if ([REngine cocoaHandler])
		return [[REngine cocoaHandler] handleSystemCommand: cmd];
	else { // fallback in case there's no handler
		   // reset signal handlers
		signal(SIGINT, SIG_DFL);
		signal(SIGTERM, SIG_DFL);
		signal(SIGQUIT, SIG_DFL);
		signal(SIGALRM, SIG_DFL);
		signal(SIGCHLD, SIG_DFL);
		return system(cmd);
	}		
}

SEXP Re_packagemanger(SEXP call, SEXP op, SEXP args, SEXP env)
{
	SEXP pkgname, pkgstatus, pkgdesc, pkgurl;
	char *vm;
	SEXP ans; 
	int i, len;
	
	char **sName, **sDesc, **sURL;
	BOOL *bStat;
	
	checkArity(op, args);

	if (![REngine cocoaHandler]) return R_NilValue;
	
	vm = vmaxget();
	pkgstatus = CAR(args); args = CDR(args);
	pkgname = CAR(args); args = CDR(args);
	pkgdesc = CAR(args); args = CDR(args);
	pkgurl = CAR(args); args = CDR(args);
  
	if(!isString(pkgname) || !isLogical(pkgstatus) || !isString(pkgdesc) || !isString(pkgurl))
		errorcall(call, "invalid arguments");
   
	len = LENGTH(pkgname);
	if (len!=LENGTH(pkgstatus) || len!=LENGTH(pkgdesc) || len!=LENGTH(pkgurl))
		errorcall(call, "invalid arguments (length mismatch)");

	if (len==0) {
		[[REngine cocoaHandler] handlePackages: 0 withNames: 0 descriptions: 0 URLs: 0 status: 0];
		vmaxset(vm);
		return pkgstatus;
	}

	sName = (char**) malloc(sizeof(char*)*len);
	sDesc = (char**) malloc(sizeof(char*)*len);
	sURL  = (char**) malloc(sizeof(char*)*len);
	bStat = (BOOL*) malloc(sizeof(BOOL)*len);

	i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
	while (i<len) {
		sName[i] = CHAR(STRING_ELT(pkgname, i));
		sDesc[i] = CHAR(STRING_ELT(pkgdesc, i));
		sURL [i] = CHAR(STRING_ELT(pkgurl, i));
		bStat[i] = (BOOL)LOGICAL(pkgstatus)[i];
		i++;
	}
	[[REngine cocoaHandler] handlePackages: len withNames: sName descriptions: sDesc URLs: sURL status: bStat];
	free(sName); free(sDesc); free(sURL);
	
	PROTECT(ans = NEW_LOGICAL(len));
	for(i=0;i<len;i++)
		LOGICAL(ans)[i] = bStat[i];
	UNPROTECT(1);
	free(bStat);
	
	vmaxset(vm);
  	return ans;
}

SEXP Re_datamanger(SEXP call, SEXP op, SEXP args, SEXP env)
{
  SEXP  dsets, dpkg, ddesc, durl, ans;
  char *vm;
  int i, len;
  
  char **sName, **sDesc, **sURL, **sPkg;
  BOOL *res;

  checkArity(op, args);

  vm = vmaxget();
  dsets = CAR(args); args = CDR(args);
  dpkg = CAR(args); args = CDR(args);
  ddesc = CAR(args); args = CDR(args);
  durl = CAR(args);
  
  if (!isString(dsets) || !isString(dpkg) || !isString(ddesc)  || !isString(durl) )
	errorcall(call, "invalid arguments");

  len = LENGTH(dsets);
  if (LENGTH(dpkg)!=len || LENGTH(ddesc)!=len || LENGTH(durl)!=len)
	  errorcall(call, "invalid arguments (length mismatch)");
	  
  if (len==0) {
	  [[REngine cocoaHandler] handleDatasets: 0 withNames: 0 descriptions: 0 packages: 0 URLs: 0];
	  vmaxset(vm);
	  return R_NilValue;
  }

  sName = (char**) malloc(sizeof(char*)*len);
  sDesc = (char**) malloc(sizeof(char*)*len);
  sURL  = (char**) malloc(sizeof(char*)*len);
  sPkg  = (char**) malloc(sizeof(char*)*len);
  
  i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
  while (i<len) {
	  sName[i] = CHAR(STRING_ELT(dsets, i));
	  sDesc[i] = CHAR(STRING_ELT(ddesc, i));
	  sURL [i] = CHAR(STRING_ELT(durl, i));
	  sPkg [i] = CHAR(STRING_ELT(dpkg, i));
	  i++;
  }

  res = [[REngine cocoaHandler] handleDatasets: len withNames: sName descriptions: sDesc packages: sPkg URLs: sURL];
  
  free(sName); free(sDesc); free(sPkg); free(sURL);
  
  if (res) {
	  PROTECT(ans=allocVector(LGLSXP, len));
	  i=0;
	  while (i<len) {
		  LOGICAL(ans)[i]=res[i];
		  i++;
	  }
	  UNPROTECT(1);
  } else {
	  // this should be the default:	  ans=R_NilValue;
	  // but until the R code is fixed to accept this, we have to fake a result
	  ans=allocVector(LGLSXP, 0);
  }
  
  vmaxset(vm);
  
  return ans;
}

SEXP Re_browsepkgs(SEXP call, SEXP op, SEXP args, SEXP env)
{
  char *vm;
  int i, len;
  SEXP rpkgs, rvers, ivers, wwwhere, install_dflt;

  char **sName, **sIVer, **sRVer;
  BOOL *bStat;

  checkArity(op, args);

  vm = vmaxget();
  rpkgs = CAR(args); args = CDR(args);
  rvers = CAR(args); args = CDR(args);
  ivers = CAR(args); args = CDR(args);
  wwwhere = CAR(args); args=CDR(args);
  install_dflt = CAR(args); 
  
  if(!isString(rpkgs) || !isString(rvers) || !isString(ivers) || !isString(wwwhere) || !isLogical(install_dflt))
	  errorcall(call, "invalid arguments");

  len = LENGTH(rpkgs);
  if (LENGTH(rvers)!=len || LENGTH(ivers)!=len || LENGTH(wwwhere)<1 || LENGTH(install_dflt)!=len)
	  errorcall(call, "invalid arguments (length mismatch)");
	  
  if (len==0) {
	  [[REngine cocoaHandler] handleInstalledPackages: 0 withNames: 0 installedVersions: 0 repositoryVersions: 0 update: 0 label: 0];
	  vmaxset(vm);
	  return R_NilValue;
  }
  
  sName = (char**) malloc(sizeof(char*)*len);
  sIVer = (char**) malloc(sizeof(char*)*len);
  sRVer = (char**) malloc(sizeof(char*)*len);
  bStat = (BOOL*) malloc(sizeof(BOOL)*len);
  
  i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
  while (i<len) {
	  sName[i] = CHAR(STRING_ELT(rpkgs, i));
	  sIVer[i] = CHAR(STRING_ELT(ivers, i));
	  sRVer[i] = CHAR(STRING_ELT(rvers, i));
	  bStat[i] = (BOOL)LOGICAL(install_dflt)[i];
	  i++;
  }
  
  [[REngine cocoaHandler] handleInstalledPackages: len withNames: sName installedVersions: sIVer repositoryVersions: sRVer update: bStat label:CHAR(STRING_ELT(wwwhere,0))];
  free(sName); free(sIVer); free(sRVer); free(bStat);
    
  vmaxset(vm);
  return allocVector(LGLSXP, 0);
}

//==================================================== the following callbacks need to be moved!!! (TODO)

int freeWorkspaceList(int newlen);

int NumOfWSObjects;
int *ws_IDNum;              /* id          */
Rboolean *ws_IsRoot;        /* isroot      */
Rboolean *ws_IsContainer;   /* iscontainer */
UInt32 *ws_numOfItems;      /* numofit     */
int *ws_parID;           /* parid       */
char **ws_name;            /* name        */
char **ws_type;            /* type        */
char **ws_size;            /* objsize     */
int NumOfID = 0;         /* length of the vectors    */
                                /* We do not check for this */ 
 

BOOL WeHaveWorkspace;

SEXP Re_do_wsbrowser(SEXP call, SEXP op, SEXP args, SEXP env)
{
	int i, len;
	SEXP ids, isroot, iscont, numofit, parid;
	SEXP name, type, objsize;
	char *vm;
   
    
	checkArity(op, args);

	vm = vmaxget();
	ids = CAR(args); args = CDR(args);
	isroot = CAR(args); args = CDR(args);
	iscont = CAR(args); args = CDR(args);
	numofit = CAR(args); args = CDR(args);
	parid = CAR(args); args = CDR(args);
	name = CAR(args); args = CDR(args);
	type = CAR(args); args = CDR(args);
	objsize = CAR(args); 

	if(!isInteger(ids)) 
		errorcall(call,"`id' must be integer");      
	if(!isString(name))
		errorcall(call, "invalid objects' name");
	if(!isString(type))
		errorcall(call, "invalid objects' type");
	if(!isString(objsize))
		errorcall(call, "invalid objects' size");
	if(!isLogical(isroot))
		errorcall(call, "invalid `isroot' definition");
	if(!isLogical(iscont))
		errorcall(call, "invalid `iscont' definition");
	if(!isInteger(numofit))
		errorcall(call,"`numofit' must be integer");
	if(!isInteger(parid))
		errorcall(call,"`parid' must be integer");
  
    len = LENGTH(ids);

	if(len>0){
		WeHaveWorkspace = YES;
		NumOfWSObjects = freeWorkspaceList(len);		
  
		for(i=0; i<NumOfWSObjects; i++){

		if (!isNull(STRING_ELT(name, i)))
			ws_name[i] = strdup(CHAR(STRING_ELT(name, i)));
		else
			ws_name[i] = strdup(CHAR(R_BlankString));

		if (!isNull(STRING_ELT(type, i)))
			ws_type[i] = strdup(CHAR(STRING_ELT(type, i)));
		else
			ws_type[i] = strdup(CHAR(R_BlankString));

		if (!isNull(STRING_ELT(objsize, i)))
			ws_size[i] = strdup(CHAR(STRING_ELT(objsize, i)));
		else
			ws_size[i] = strdup(CHAR(R_BlankString));  

		ws_IDNum[i] = INTEGER(ids)[i];
		ws_numOfItems[i] = INTEGER(numofit)[i];
		if(INTEGER(parid)[i] == -1)
			ws_parID[i] = -1;
		else 
			ws_parID[i] = INTEGER(parid)[i]; 
		ws_IsRoot[i] = LOGICAL(isroot)[i];
		ws_IsContainer[i] = LOGICAL(iscont)[i];
	}
  }

  vmaxset(vm);

   [WSBrowser toggleWorkspaceBrowser];

  return R_NilValue;
}




int freeWorkspaceList(int newlen)
{
	if(ws_name){
		free(ws_name);
		ws_name = 0;
	}
	
	if(ws_type){
		free(ws_type);
		ws_type = 0;
	}
	
	if(ws_size){
		free(ws_size);
		ws_size = 0;
	}
	
	if(ws_parID){
		free(ws_parID);
		ws_parID = 0;
	}
	
	if(ws_numOfItems){
		free(ws_numOfItems);
		ws_numOfItems = 0;
	}
	
	if(ws_IsRoot){
		free(ws_IsRoot);
		ws_IsRoot = 0;
	}
	
	if(ws_IsContainer){
		free(ws_IsContainer);
		ws_IsContainer = 0;
	}

	if(ws_IDNum){
		free(ws_IDNum);
		ws_IDNum = 0;
	}
	if(newlen <= 0)
		newlen = 0;
	else {
		ws_name = (char **)calloc(newlen, sizeof(char *) );
		ws_type = (char **)calloc(newlen, sizeof(char *) );
		ws_size = (char **)calloc(newlen, sizeof(char *) );
		ws_parID = (int *)calloc(newlen, sizeof(int));
		ws_numOfItems = (UInt32 *)calloc(newlen, sizeof(UInt32));
		ws_IsRoot = (Rboolean *)calloc(newlen, sizeof(Rboolean));
		ws_IsContainer = (Rboolean *)calloc(newlen, sizeof(Rboolean));
		ws_IDNum = (int *)calloc(newlen, sizeof(int));
	}
	
	return(newlen);
}		

int freeSearchList(int newlen);

int NumOfMatches;
char **hs_topic; 
char **hs_pkg;
char **hs_desc;
char **hs_url;
BOOL WeHaveSearchTopics;  
SEXP Re_do_hsbrowser(SEXP call, SEXP op, SEXP args, SEXP env)
{
  char *vm;
  SEXP ans; 
  int i, len;
  SEXP h_topic, h_pkg, h_desc, h_wtitle, h_url;

  checkArity(op, args);

  vm = vmaxget();
  h_topic = CAR(args); args = CDR(args);
  h_pkg = CAR(args); args = CDR(args);
  h_desc = CAR(args); args = CDR(args);
  h_wtitle = CAR(args); args = CDR(args);
  h_url = CAR(args); 
  
  if(!isString(h_topic) | !isString(h_pkg) | !isString(h_desc) )
	errorcall(call, "invalid arguments");


  len = LENGTH(h_topic);
  if(len>0){
	WeHaveSearchTopics = YES;
	NumOfMatches = freeSearchList(len);		
	for(i=0;i<NumOfMatches;i++){
		hs_topic[i] = strdup(CHAR(STRING_ELT(h_topic, i)));
		hs_pkg[i] = strdup( CHAR(STRING_ELT(h_pkg, i)));
		hs_desc[i] = strdup( CHAR(STRING_ELT(h_desc, i)));
		hs_url[i] = strdup( CHAR(STRING_ELT(h_url, i)));
		/* CHAR(STRING_ELT(wtitle,0)) */
	}
  }

   
  PROTECT(ans = NEW_LOGICAL(NumOfMatches));
  for(i=1;i<=NumOfMatches;i++)
   LOGICAL(ans)[i-1] = 0;
 [SearchTable toggleHSBrowser: [NSString stringWithCString:CHAR(STRING_ELT(h_wtitle,0))]];
   
  vmaxset(vm);
  
  UNPROTECT(1);

  return ans;
}

int freeSearchList(int newlen)
{
	if(hs_topic){
		free(hs_topic);
		hs_topic = 0;
	}
	
	if(hs_pkg){
		free(hs_pkg);
		hs_pkg = 0;
	}
	
	if(hs_desc){
		free(hs_desc);
		hs_desc = 0;
	}
		
	if(hs_url){
		free(hs_url);
		hs_url = 0;
	}
	
	if(newlen <= 0)
		newlen = 0;
	else {
		hs_topic = (char **)calloc(newlen, sizeof(char *) );
		hs_pkg = (char **)calloc(newlen, sizeof(char *) );
		hs_desc = (char **)calloc(newlen, sizeof(char *) );
		hs_url = (char **)calloc(newlen, sizeof(char *) );
	}
	
	return(newlen);
}		




SEXP work, names, lens;
PROTECT_INDEX wpi, npi, lpi;
SEXP ssNA_STRING;
double ssNA_REAL;
 int xmaxused, ymaxused;

#ifndef max
#define max(x,y) x<y?y:x;
#endif

extern BOOL IsDataEntry;
/*
   ssNewVector is just an interface to allocVector but it lets us
   set the fields to NA. We need to have a special NA for reals and
   strings so that we can differentiate between uninitialized elements
   in the vectors and user supplied NA's; hence ssNA_REAL and ssNA_STRING
 */

SEXP ssNewVector(SEXPTYPE type, int vlen)
{
    SEXP tvec;
    int j;

    tvec = allocVector(type, vlen);
    for (j = 0; j < vlen; j++)
	if (type == REALSXP)
	    REAL(tvec)[j] = ssNA_REAL;
	else if (type == STRSXP)
	    SET_STRING_ELT(tvec, j, STRING_ELT(ssNA_STRING, 0));
    SETLEVELS(tvec, 0);
    return (tvec);
}

int nprotect;
SEXP Re_dataentry(SEXP call, SEXP op, SEXP args, SEXP rho)
{
    SEXP colmodes, tnames, tvec, tvec2, work2;
    SEXPTYPE type;
    int i, j, cnt, len;
    char clab[25];

	
    nprotect = 0;/* count the PROTECT()s */
    PROTECT_WITH_INDEX(work = duplicate(CAR(args)), &wpi); nprotect++;
    colmodes = CADR(args);
    tnames = getAttrib(work, R_NamesSymbol);

    if (TYPEOF(work) != VECSXP || TYPEOF(colmodes) != VECSXP)
	errorcall(call, "invalid argument");

    /* initialize the constants */

    ssNA_REAL = -NA_REAL;
    tvec = allocVector(REALSXP, 1);
    REAL(tvec)[0] = ssNA_REAL;
    PROTECT(ssNA_STRING = coerceVector(tvec, STRSXP)); nprotect++;
    
    /* setup work, names, lens  */
    xmaxused = length(work); ymaxused = 0;
    PROTECT_WITH_INDEX(lens = allocVector(INTSXP, xmaxused), &lpi);
    nprotect++;

    if (isNull(tnames)) {
		PROTECT_WITH_INDEX(names = allocVector(STRSXP, xmaxused), &npi);
		for(i = 0; i < xmaxused; i++) {
			sprintf(clab, "var%d", i);
			SET_STRING_ELT(names, i, mkChar(clab));
		}
    } else 
		PROTECT_WITH_INDEX(names = duplicate(tnames), &npi);
    nprotect++;

    for (i = 0; i < xmaxused; i++) {
	int len = LENGTH(VECTOR_ELT(work, i));
	INTEGER(lens)[i] = len;
	ymaxused = max(len, ymaxused);
        type = TYPEOF(VECTOR_ELT(work, i));
    if (LENGTH(colmodes) > 0 && !isNull(VECTOR_ELT(colmodes, i)))
	    type = str2type(CHAR(STRING_ELT(VECTOR_ELT(colmodes, i), 0)));
	if (type != STRSXP) type = REALSXP;
	if (isNull(VECTOR_ELT(work, i))) {
	    if (type == NILSXP) type = REALSXP;
	    SET_VECTOR_ELT(work, i, ssNewVector(type, 100));
	} else if (!isVector(VECTOR_ELT(work, i)))
	    errorcall(call, "invalid type for value");
	else {
	    if (TYPEOF(VECTOR_ELT(work, i)) != type)
		SET_VECTOR_ELT(work, i, 
			       coerceVector(VECTOR_ELT(work, i), type));
	}
    }


    /* start up the window, more initializing in here */

	IsDataEntry = YES;
	[REditor startDataEntry];
	IsDataEntry = NO;

	/* drop out unused columns */
    for(i = 0, cnt = 0; i < xmaxused; i++)
	if(!isNull(VECTOR_ELT(work, i))) cnt++;
    if (cnt < xmaxused) {
	PROTECT(work2 = allocVector(VECSXP, cnt)); nprotect++;
	for(i = 0, j = 0; i < xmaxused; i++) {
	    if(!isNull(VECTOR_ELT(work, i))) {
		SET_VECTOR_ELT(work2, j, VECTOR_ELT(work, i));
		INTEGER(lens)[j] = INTEGER(lens)[i];
		SET_STRING_ELT(names, j, STRING_ELT(names, i));
		j++;
	    }
	}
	REPROTECT(names = lengthgets(names, cnt), npi);
    } else work2 = work;

    for (i = 0; i < LENGTH(work2); i++) {
	len = INTEGER(lens)[i];
	tvec = VECTOR_ELT(work2, i);
	if (LENGTH(tvec) != len) {
	    tvec2 = ssNewVector(TYPEOF(tvec), len);
	    for (j = 0; j < len; j++) {
		if (TYPEOF(tvec) == REALSXP) {
		    if (REAL(tvec)[j] != ssNA_REAL)
			REAL(tvec2)[j] = REAL(tvec)[j];
		    else
			REAL(tvec2)[j] = NA_REAL;
		} else if (TYPEOF(tvec) == STRSXP) {
		    if (!streql(CHAR(STRING_ELT(tvec, j)),
				CHAR(STRING_ELT(ssNA_STRING, 0))))
			SET_STRING_ELT(tvec2, j, STRING_ELT(tvec, j));
		    else
			SET_STRING_ELT(tvec2, j, NA_STRING);
		} else
		    error("dataentry: internal memory problem");
	    }
	    SET_VECTOR_ELT(work2, i, tvec2);
	}
    }

    setAttrib(work2, R_NamesSymbol, names);    
    UNPROTECT(nprotect);

    return work2;
}
