/*
 *  Authorization.h
 *
 *  Created by Simon Urbanek on 10/30/04.
 *
 */

#include <stdio.h>

int requestRootAuthorization(int forceFresh);
int removeRootAuthorization();
int runRootScript(const char* script, char** args, FILE **fptr, int keepAuthorized);
