#ifndef __R_INIT__H__
#define __R_INIT__H__

extern char* lastInitRError;

void run_REngineRmainloop(void);
int initR(int argc, char **argv);

#endif
