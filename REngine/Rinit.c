
#include <R.h>
#include <Rinternals.h>
#include <Rversion.h>
#include "Rinit.h"
#include "Rcallbacks.h"
#include "IOStuff.h"
#include <R_ext/Parse.h>
#include <Parse.h>

#include <Rdevices.h>
#include <R_ext/GraphicsDevice.h>

#include <Rdefines.h>

/* This constant defines the maximal length of single ReadConsole input, which usually corresponds to the maximal length of a single line. The buffer is allocated dynamically, so an arbitrary size is fine. */
#ifndef MAX_R_LINE_SIZE
#define MAX_R_LINE_SIZE 32767
#endif

int setup_Rmainloop(void);  /* from src/main.c */
int end_Rmainloop(void);    /* from src/main.c */
int Rf_initialize_R(int ac, char **av); /* from src/unix/system.c */

extern Rboolean innerQuartzDevice(NewDevDesc*dd,char*display,
						   double width,double height,
						   double pointsize,char*family,
						   Rboolean antialias,
						   Rboolean autorefresh,int quartzpos,
						   int bg);
extern void getQuartzParameters(double *width, double *height, double *ps, char *family, 
						 Rboolean *antialias, Rboolean *autorefresh, int *quartzpos);

/*-------------------------------------------------------------------*
 * UNIX initialization (includes Darwin/Mac OS X)                    *
 *-------------------------------------------------------------------*/

/* from Defn.h */
extern Rboolean R_Interactive;   /* TRUE during interactive use*/

extern FILE*    R_Consolefile;   /* Console output file */
extern FILE*    R_Outputfile;   /* Output file */

typedef enum {
    SA_NORESTORE,/* = 0 */
    SA_RESTORE,
    SA_DEFAULT,/* was === SA_RESTORE */
    SA_NOSAVE,
    SA_SAVE,
    SA_SAVEASK,
    SA_SUICIDE
} SA_TYPE;

extern SA_TYPE SaveAction;

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
extern int  (*ptr_R_ShowFiles)(int, char **, char **, char *, Rboolean, char *);
extern int  (*ptr_R_EditFiles)(int, char **, char **, char *);


#if (R_VERSION >= R_Version(2,1,0))
extern int  (*ptr_R_EditFile)(char *); /* in r-devel ptr_Raqua_Edit is no longer used*/
#else
extern int  (*ptr_Raqua_Edit)(char *);
#endif
extern int  (*ptr_R_ChooseFile)(int, char *, int);
extern void (*ptr_R_loadhistory)(SEXP, SEXP, SEXP, SEXP);
extern void (*ptr_R_savehistory)(SEXP, SEXP, SEXP, SEXP);
extern void (*ptr_R_ProcessEvents)();
extern SEXP (*ptr_do_packagemanger)(SEXP, SEXP, SEXP, SEXP);
extern SEXP (*ptr_do_datamanger)(SEXP, SEXP, SEXP, SEXP);
extern SEXP (*ptr_do_browsepkgs)(SEXP, SEXP, SEXP, SEXP);
extern SEXP (*ptr_do_wsbrowser)(SEXP, SEXP, SEXP, SEXP);
extern SEXP (*ptr_do_hsbrowser)(SEXP, SEXP, SEXP, SEXP);
extern SEXP (*ptr_do_dataentry)(SEXP, SEXP, SEXP, SEXP);
extern int  (*ptr_CocoaSystem)(char *);

extern Rboolean (*ptr_CocoaInnerQuartzDevice)(NewDevDesc *,char *,
					  double ,double ,
					  double ,char *,
					  Rboolean ,
					  Rboolean ,int ,
					  int );
extern void (*ptr_CocoaGetQuartzParameters)(double *, double *, double *, 
		char *, Rboolean *, Rboolean *, int *);

/*--- note: the REPL code was modified, R_ReplState is not the same as used internally in R */

typedef struct {
  ParseStatus    status;
  int            prompt_type;
  int            browselevel;
  int            buflen;
  unsigned char *buf;
  unsigned char *bufp;
} R_ReplState;

static int  RGUI_ReplIteration(SEXP rho, int savestack, int browselevel, R_ReplState *state);
static void RGUI_ReplConsole(SEXP rho, int savestack, int browselevel);

/*---------- implementation -----------*/

static R_ReplState state = {0, 1, 0, (MAX_R_LINE_SIZE+1), NULL, NULL};

char *lastInitRError = 0;

int initR(int argc, char **argv) {
    if (!getenv("R_HOME")) {
        lastInitRError = "R_HOME is not set. Please set all required environment variables before running this program.";
        return -1;
    }
    
    int stat=Rf_initialize_R(argc, argv);
    if (stat<0) {
        lastInitRError = "Failed to initialize R!";;
        return -2;
    }

	if (state.buflen<128) state.buflen=1024;
	state.buf=(char*) malloc(state.buflen);
	
   // printf("R primary initialization done. Setting up parameters.\n");

    R_Outputfile = NULL;
    R_Consolefile = NULL;
    R_Interactive = 1;
    SaveAction = SA_SAVEASK;

    /* ptr_R_Suicide = Re_Suicide; */
    /* ptr_R_CleanUp = Re_CleanUp; */
    ptr_R_ShowMessage = Re_ShowMessage;
    ptr_R_ReadConsole =  Re_ReadConsole;
    ptr_R_WriteConsole = Re_WriteConsole;
    ptr_R_ResetConsole = Re_ResetConsole;
    ptr_R_FlushConsole = Re_FlushConsole;
    ptr_R_ClearerrConsole = Re_ClearerrConsole;
    ptr_R_Busy = Re_RBusy;
    ptr_R_ProcessEvents =  Re_ProcessEvents;

#if (R_VERSION >= R_Version(2,1,0))
	ptr_R_EditFile = Re_Edit;
#else
	ptr_Raqua_Edit = Re_Edit;
#endif
	
    ptr_R_ShowFiles = Re_ShowFiles;
	ptr_R_EditFiles = Re_EditFiles;
    ptr_R_ChooseFile = Re_ChooseFile;
	
	
	ptr_do_packagemanger = Re_packagemanger;
	ptr_do_datamanger = Re_datamanger;
	ptr_do_browsepkgs = Re_browsepkgs;
	ptr_do_wsbrowser = Re_do_wsbrowser;
	ptr_do_hsbrowser = Re_do_hsbrowser;
	
	ptr_CocoaInnerQuartzDevice = innerQuartzDevice;
	ptr_CocoaGetQuartzParameters = getQuartzParameters;
	ptr_CocoaSystem = Re_system;
	ptr_do_dataentry = Re_dataentry;
	
	setup_Rmainloop();

    return 0;
}


void run_REngineRmainloop(void)
{
    /* Here is the real R read-eval-loop. */
    /* We handle the console until end-of-file. */

    R_IoBufferInit(&R_ConsoleIob);
    SETJMP(R_Toplevel.cjmpbuf);
    R_GlobalContext = R_ToplevelContext = &R_Toplevel;
#ifdef REINSTALL_SIGNAL_HANDLERS
    signal(SIGINT, handleInterrupt);
    signal(SIGUSR1,onsigusr1);
    signal(SIGUSR2,onsigusr2);
#ifdef Unix
    signal(SIGPIPE, onpipe);
#endif
#endif
    RGUI_ReplConsole(R_GlobalEnv, 0, 0);
	end_Rmainloop(); /* must go here */
}

extern void Re_WritePrompt(char *prompt);
extern char *R_PromptString(int browselevel, int type); /* from main.c */
extern void Rf_callToplevelHandlers(SEXP expr, SEXP value, Rboolean succeeded, 
			Rboolean visible);  /* from main.c */
extern int Rf_ParseBrowser(SEXP, SEXP);
									

static void RGUI_ReplConsole(SEXP rho, int savestack, int browselevel)
{
    int status;

    R_IoBufferWriteReset(&R_ConsoleIob);
    state.buf[0] = '\0';
    state.buf[state.buflen-1] = '\0'; /* stopgap measure */
    state.bufp = state.buf;
    if(R_Verbose)
		REprintf(" >R_ReplConsole(): before \"for(;;)\" {main.c}\n");
    for(;;) {
		status = RGUI_ReplIteration(rho, savestack, browselevel, &state);
		if(status < 0)
			return;
    }
}

static int cleanExit=1;

static int RGUI_ReplIteration(SEXP rho, int savestack, int browselevel, R_ReplState *state)
{
    int c, browsevalue;
    SEXP value;
    Rboolean wasDisplayed = FALSE;

	if (!cleanExit) // if previous eval was aborted, we may need to clear the busy flag
		R_Busy(0);
	
    if(!*state->bufp) {
	    if (Re_ReadConsole(R_PromptString(browselevel, state->prompt_type),
						   state->buf, state->buflen-1, 1) == 0) return(-1);
	    state->bufp = state->buf;
    }
#ifdef SHELL_ESCAPE
    if (*state->bufp == '!') {
#ifdef HAVE_SYSTEM
	    R_system(&(state->buf[1]));
#else
	    Rprintf("error: system commands are not supported in this version of R.\n");
#endif /* HAVE_SYSTEM */
	    state->buf[0] = '\0';
	    return(0);
    }
#endif /* SHELL_ESCAPE */
    while((c = *state->bufp++)) {
	    R_IoBufferPutc(c, &R_ConsoleIob);
	    if(c == ';' || c == '\n') break;
    }

    R_PPStackTop = savestack;
    R_CurrentExpr = R_Parse1Buffer(&R_ConsoleIob, 0, &state->status);
    switch(state->status) {
    case PARSE_NULL:

	    if (browselevel)
		    return(-1);
	    R_IoBufferWriteReset(&R_ConsoleIob);
	    state->prompt_type = 1;
	    return(1);

    case PARSE_OK:

 	    R_IoBufferReadReset(&R_ConsoleIob);
	    R_CurrentExpr = R_Parse1Buffer(&R_ConsoleIob, 1, &state->status);
	    if (browselevel) {
		    browsevalue = Rf_ParseBrowser(R_CurrentExpr, rho);
		    if(browsevalue == 1 )
			    return(-1);
		    if(browsevalue == 2 ) {
			    R_IoBufferWriteReset(&R_ConsoleIob);
			    return(0);
		    }
	    }
	    R_Visible = 0;
	    R_EvalDepth = 0;
	    PROTECT(R_CurrentExpr);
		cleanExit=0;
	    R_Busy(1);
	    value = eval(R_CurrentExpr, rho);
	    SET_SYMVALUE(R_LastvalueSymbol, value);
	    wasDisplayed = R_Visible;
	    if (R_Visible)
		    PrintValueEnv(value, rho);
	    if (R_CollectWarnings)
			PrintWarnings();
	    Rf_callToplevelHandlers(R_CurrentExpr, value, TRUE, wasDisplayed);
	    R_CurrentExpr = value; /* Necessary? Doubt it. */
	    R_Busy(0);
		cleanExit=1;
	    UNPROTECT(1);
	    R_IoBufferWriteReset(&R_ConsoleIob);
	    state->prompt_type = 1;
	    return(1);

    case PARSE_ERROR:

	    state->prompt_type = 1;
	    error("syntax error");
	    R_IoBufferWriteReset(&R_ConsoleIob);
	    return(1);

    case PARSE_INCOMPLETE:

	    R_IoBufferReadReset(&R_ConsoleIob);
	    state->prompt_type = 2;
	    return(2);

    case PARSE_EOF:

	    return(-1);
	    break;
    }

    return(0);
}

