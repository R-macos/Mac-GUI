/*
 *  InfoPlist.h
 *  R
 *
 *  Created by Simon Urbanek on 10/23/08.
 *  Copyright 2008-2011 R Foundation for Statistical Computing. All rights reserved.
 *
 */

/* GUI version as shown in infos e.g. 1.27-devel */
#define GUI_VER 1.52
/* R postfix used to denote release versions of GUI - set to R release version (e.g. 2.8.0) or to anything that will be shown in between R and GUI (e.g. - or for Mac) */
#define R_RELEASE 2.15.1

#if LEOPARD_CFG
#define CFG_NAME Leopard build 32-bit
#endif
#if SNOWLEOPARD_CFG
#define CFG_NAME Snow Leopard build
#endif
#if LEOPARD64_CFG
#define CFG_NAME Leopard build 64-bit
#endif
#if DEPLOY_CFG || DEPLOYMENT_CFG
#define CFG_NAME Tiger build 32-bit
#endif
#if DEPLOY64_CFG
#define CFG_NAME Tiger build 64-bit
#endif
#if DEBUG_CFG
#define CFG_NAME Debug build
#endif
#if DEVELOPMENT_CFG
#define CFG_NAME Development build
#endif
#ifndef CFG_NAME
#define CFG_NAME unknown
#endif
