/*
 *  Authorization.c
 *
 *  Created by Simon Urbanek on 10/30/04.
 *
 */

#include "Authorization.h"

#include <Security/Authorization.h>
#include <Security/AuthorizationTags.h>

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

