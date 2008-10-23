/*
 *  InfoPlist.h
 *  R
 *
 *  Created by Simon Urbanek on 10/23/08.
 *  Copyright 2008 R Foundation for Statistical Computing. All rights reserved.
 *
 */

#if LEOPARD_CFG
#define CFG_NAME Leopard build 32-bit
#endif
#if LEOPARD64_CFG
#define CFG_NAME Leopard build 64-bit
#endif
#if DEPLOY_CFG
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
