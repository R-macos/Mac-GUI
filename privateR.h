/*
 *  privateR.h
 *  R
 *
 *  Created by Simon Urbanek on 1/27/06.
 *  Copyright 2006 R-foundation. All rights reserved.
 *
 */

/* Whenever R.app needs access to private R headers, it should use
   this header instead. It is a proxy and makes sure everything is
   set up correctly - most notably config.h was not part of
   PrivateHeaders before 2.3.0 and this causes some headache.
   The long-term goal is to remove the dependency on R private
   headers alltogether, but we're not there yet.
*/

#ifndef __PRIVATE_R_HEADER__
#define __PRIVATE_R_HEADER__

#include <Rversion.h>

/* we include config.h in private headers only since 2.3.0 */
#if (R_VERSION < R_Version(2,3,0))
#define HAVE_WCHAR_H 1
#else
#include "config.h"
#endif

#include "Defn.h"
#include "Print.h"

#endif
