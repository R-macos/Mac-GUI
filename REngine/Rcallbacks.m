
#include <Defn.h>
#include <R.h>
#include <Rdefines.h>
#include <Rinternals.h>

#include <sys/select.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>

#include <Security/Authorization.h>
#include <Security/AuthorizationTags.h>

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
extern char*    R_TempDir;   /* Name of per-session dir */

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

//==================================================== the following callback need to be moved!!! (TODO)

int  Re_Edit(char *file){
	if(!R_FileExists(file))
		return(0);
		
	RDocument *document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: [NSString stringWithCString:R_ExpandFileName(file)] display:true];
	[document setREditFlag: YES];

	NSEnumerator *e = [[document windowControllers] objectEnumerator];
	NSWindowController *wc = nil;
	while (wc = [e nextObject]) {
		NSWindow *window = [wc window];
		NSModalSession session = [NSApp beginModalSessionForWindow:window];
		while([document hasREditFlag])
			[NSApp runModalSession:session];
		
		[NSApp endModalSession:session];
	}

	return(0);
}

/* FIXME: the filename is not set for newvly created files */

int  Re_EditFiles(int nfile, char **file, char **wtitle, char *pager){
	int    	i;
    
    if (nfile <=0) return 1;
	
    for (i = 0; i < nfile; i++){
		if(R_FileExists(file[i]))
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: [NSString stringWithCString:R_ExpandFileName(file[i])] display:true];
		else
			[[NSDocumentController sharedDocumentController] newDocument: [RController getRController]];
		
		NSDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
		if(wtitle[i]!=nil)
			[RDocument changeDocumentTitle: document Title: [NSString stringWithCString:wtitle[i]]];
    }
	return 1;
}

int Re_ShowFiles(int nfile, 		/* number of files */
                 char **file,		/* array of filenames */
                 char **headers,	/* the `headers' args of file.show. Printed before each file. */
                 char *wtitle,          /* title for window = `title' arg of file.show */
                 Rboolean del,	        /* should files be deleted after use? */
                 char *pager)		/* pager to be used */
{
	int    	i;
    
    if (nfile <=0) return 1;
	
    for (i = 0; i < nfile; i++){
		RDocument *document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: [NSString stringWithCString:R_ExpandFileName(file[i])] display:true];
		if(wtitle[i]!=nil)
			[RDocument changeDocumentTitle: document Title: [NSString stringWithCString:wtitle]];
		[document setEditable: NO];
		[document setHighlighting: NO];
    }
	return 1;
}


int NumOfAllPkgs=0;

char **p_name=0;
char **p_desc=0;
char **p_url=0;
BOOL *p_stat=0;

int freePackagesList(int newlen);

/* FIXME: Possible memory leaks, check */
BOOL WeHavePackages=NO;

SEXP Re_packagemanger(SEXP call, SEXP op, SEXP args, SEXP env)
{
	SEXP pkgname, pkgstatus, pkgdesc, pkgurl;
	char *vm;
	SEXP ans; 
	int i, len;
	checkArity(op, args);

	vm = vmaxget();
	pkgstatus = CAR(args); args = CDR(args);
	pkgname = CAR(args); args = CDR(args);
	pkgdesc = CAR(args); args = CDR(args);
	pkgurl = CAR(args); args = CDR(args);
  
   
	if(!isString(pkgname) | !isLogical(pkgstatus) | !isString(pkgdesc) | !isString(pkgurl))
		errorcall(call, "invalid arguments");
   
	len = LENGTH(pkgname);	
	if(len>0){
		WeHavePackages = YES;
		NumOfAllPkgs = freePackagesList(len);		
		for(i=0;i<NumOfAllPkgs;i++){
			p_name[i] = strdup(CHAR(STRING_ELT(pkgname, i)));
			p_desc[i] = strdup( CHAR(STRING_ELT(pkgdesc, i)));
			p_url[i] = strdup( CHAR(STRING_ELT(pkgurl, i)));
			p_stat[i] = (BOOL)LOGICAL(pkgstatus)[i];
		}
  }

	PROTECT(ans = NEW_LOGICAL(NumOfAllPkgs));
	for(i=1;i<=NumOfAllPkgs;i++)
		LOGICAL(ans)[i-1] = LOGICAL(pkgstatus)[i-1];
   
	vmaxset(vm);
  
	UNPROTECT(1);
	[PackageManager togglePackageManager];
	return ans;
}


int		NumOfDSets=0;
BOOL WeHaveDataSets = NO;
char **d_name=0;
char **d_pkg=0;
char **d_desc=0;
char **d_url=0;
int freeDataSetList(int newlen);


SEXP Re_datamanger(SEXP call, SEXP op, SEXP args, SEXP env)
{
  SEXP  dsets, dpkg, ddesc, durl;
  char *vm;
  SEXP ans; 
  int i, len;
  checkArity(op, args);

  vm = vmaxget();
  dsets = CAR(args); args = CDR(args);
  dpkg = CAR(args); args = CDR(args);
  ddesc = CAR(args); args = CDR(args);
  durl = CAR(args);
  
  if(!isString(dsets) | !isString(dpkg) | !isString(ddesc)  | !isString(durl) )
	errorcall(call, "invalid arguments");

  len = LENGTH(dsets);
  if(len>0){
	WeHaveDataSets = YES;
	NumOfDSets = freeDataSetList(len);		
	for(i=0;i<NumOfDSets;i++){
		d_name[i] = strdup(CHAR(STRING_ELT(dsets, i)));
		d_pkg[i] = strdup( CHAR(STRING_ELT(dpkg, i)));
		d_desc[i] = strdup( CHAR(STRING_ELT(ddesc, i)));
		d_url[i] = strdup( CHAR(STRING_ELT(durl, i)));		
	}
  }
  
  PROTECT(ans = NEW_LOGICAL(NumOfDSets));
  for(i=1;i<=NumOfDSets;i++)
   LOGICAL(ans)[i-1] = 0;
   
  vmaxset(vm);
  
  UNPROTECT(1);
	[DataManager toggleDataManager];
  return ans;
}

int freeDataSetList(int newlen)
{
	if(d_name){
		free(d_name);
		d_name = 0;
	}
	
	if(d_pkg){
		free(d_pkg);
		d_pkg = 0;
	}
	
	if(d_desc){
		free(d_desc);
		d_desc = 0;
	}
	
	if(d_url){
		free(d_url);
		d_url = 0;
	}

	if(newlen <= 0)
		newlen = 0;
	else {
		d_name = (char **)calloc(newlen, sizeof(char *) );
		d_pkg = (char **)calloc(newlen, sizeof(char *) );
		d_desc = (char **)calloc(newlen, sizeof(char *) );
		d_url = (char **)calloc(newlen, sizeof(char *) );
	}
	
	return(newlen);
}		

int freePackagesList(int newlen)
{
	if(p_name){
		free(p_name);
		p_name = 0;
	}
	
	if(p_url){
		free(p_url);
		p_url = 0;
	}
	
	if(p_desc){
		free(p_desc);
		p_desc = 0;
	}
	
	if(p_stat){
		free(p_stat);
		p_stat = 0;
	}
	
	if(newlen <= 0)
		newlen = 0;
	else {
		p_name = (char **)calloc(newlen, sizeof(char *) );
		p_url = (char **)calloc(newlen, sizeof(char *) );
		p_desc = (char **)calloc(newlen, sizeof(char *) );
		p_stat = (BOOL *)calloc(newlen, sizeof(BOOL) );
	}
	
	return(newlen);
}		


int  NumOfRepPkgs=0;
BOOL WeHaveRepository = NO;
char **r_name=0;
char **i_ver=0;
char **r_ver=0;
int freeRepositoryList(int newlen);

SEXP Re_browsepkgs(SEXP call, SEXP op, SEXP args, SEXP env)
{
  char *vm;
  SEXP ans; 
  int i, len;
  SEXP rpkgs, rvers, ivers, wwwhere, install_dflt;
  
  checkArity(op, args);

  vm = vmaxget();
  rpkgs = CAR(args); args = CDR(args);
  rvers = CAR(args); args = CDR(args);
  ivers = CAR(args); args = CDR(args);
  wwwhere = CAR(args); args=CDR(args);
  install_dflt = CAR(args); 
  
  
  if(!isString(rpkgs) | !isString(rvers) | !isString(ivers) | !isString(wwwhere) )
	errorcall(call, "invalid arguments");
  if(!isLogical(install_dflt))
    errorcall(call, "invalid arguments");
   


  len = LENGTH(rpkgs);
  if(len>0){
	WeHaveRepository = YES;
	NumOfRepPkgs = freeRepositoryList(len);		
	for(i=0;i<NumOfRepPkgs;i++){
		r_name[i] = strdup(CHAR(STRING_ELT(rpkgs, i)));
		i_ver[i] = strdup( CHAR(STRING_ELT(ivers, i)));
		r_ver[i] = strdup( CHAR(STRING_ELT(rvers, i)));
	}
  }
  
  PROTECT(ans =  NEW_LOGICAL(NumOfRepPkgs));

  for(i=0;i<NumOfRepPkgs;i++)
	LOGICAL(ans)[i] = 0;
  

  vmaxset(vm);
  
  UNPROTECT(1);  /*ans*/
  	[PackageInstaller togglePackageInstaller];

  return ans;
}



int freeRepositoryList(int newlen)
{
	if(r_name){
		free(r_name);
		r_name = 0;
	}
	
	if(i_ver){
		free(i_ver);
		i_ver = 0;
	}
	
	if(r_ver){
		free(r_ver);
		r_ver = 0;
	}
	
	if(newlen <= 0)
		newlen = 0;
	else {
		r_name = (char **)calloc(newlen, sizeof(char *) );
		i_ver = (char **)calloc(newlen, sizeof(char *) );
		r_ver = (char **)calloc(newlen, sizeof(char *) );
	}
	
	return(newlen);
}		




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

int Re_system(char *cmd) {
	int cstat=-1;
	pid_t pid;
	
	if ([[RController getRController] getRootFlag]) {
		FILE *f;
		char *argv[3] = { "-c", cmd, 0 };
		int fd;
 		NSBundle *b = [NSBundle mainBundle];
		char *sushPath=0;
		if (b) {
			NSString *sush=[[b resourcePath] stringByAppendingString:@"/sush"];
			sushPath = (char*) malloc([sush cStringLength]+1);
			[sush getCString:sushPath maxLength:[sush cStringLength]];
		}
		
		fd = runRootScript(sushPath?sushPath:"/bin/sh",argv,&f,1);
		if (!fd && f)
			[[RController getRController] setRootFD:fileno(f)];
		if (sushPath) free(sushPath);
		return fd;
	}
	
	pid=fork();
	if (pid==0) {
		// int sr;
		// reset signal handlers
		signal(SIGINT, SIG_DFL);
		signal(SIGTERM, SIG_DFL);
		signal(SIGQUIT, SIG_DFL);
		signal(SIGALRM, SIG_DFL);
		signal(SIGCHLD, SIG_DFL);
		execl("/bin/sh","/bin/sh","-c",cmd,0);
		exit(-1);
		//sr=system(cmd);
		//exit(WEXITSTATUS(sr));
	}
	if (pid==-1) return -1;

	[[RController getRController] addChildProcess: pid];
	
	while (1) {
		pid_t w = waitpid(pid, &cstat, WNOHANG);
		if (w!=0) break;
		Re_ProcessEvents();
	}
	[[RController getRController] rmChildProcess: pid];
	return cstat;
}

AuthorizationRef rootAuthorizationRef=0;

int removeRootAuthorization()
{
	if (rootAuthorizationRef) {
		AuthorizationFree (rootAuthorizationRef, kAuthorizationFlagDefaults);
		rootAuthorizationRef=0;
	}
	return 0;
}

int requestRootAuthorization(int forceFresh)
{
    OSStatus myStatus;
    AuthorizationFlags myFlags = kAuthorizationFlagDefaults;	
	
	if (rootAuthorizationRef) {
		if (!forceFresh)
			return 0;
		removeRootAuthorization();
	}
	
    myStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
                                   myFlags, &rootAuthorizationRef);
    if (myStatus != errAuthorizationSuccess)
        return -1;
    do {
        AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
        AuthorizationRights myRights = {1, &myItems};
        myFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
            kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
        myStatus = AuthorizationCopyRights (rootAuthorizationRef, &myRights, NULL, myFlags, NULL );
		
        if (myStatus != errAuthorizationSuccess) break;
        return 0;
	} while (0);
	AuthorizationFree (rootAuthorizationRef, kAuthorizationFlagDefaults);
	rootAuthorizationRef=0;
	return -1;
}

int runRootScript(const char* script, char** args, FILE **fptr, int keepAuthorized) {
    OSStatus myStatus;
	AuthorizationFlags myFlags = kAuthorizationFlagDefaults;
	
	if (!rootAuthorizationRef && requestRootAuthorization(0)) return -1;
	
	myStatus = AuthorizationExecuteWithPrivileges
		(rootAuthorizationRef, script, myFlags, args, fptr);
	
	if (!keepAuthorized) removeRootAuthorization();
	
	return (myStatus == errAuthorizationSuccess)?0:-1;
}

