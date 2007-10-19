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

/* since Xcode may be using different compiler/flags than R, we have to make sure that inlining behavior is ok. Specifically, Xcode doesn't use -std=gnu99 which changes the inlining, so if we are in Leopard's gcc *and* Xcode didn't enable C99 then we have to override the inline semantics flag as it will be wrong! I have fixed this for R-devel (2.7.0-to-be), but previous R versions need it. */
#if __APPLE_CC__ > 5400 && !defined(C99_INLINE_SEMANTICS) && !defined(__STDC_VERSION__)
#define C99_INLINE_SEMANTICS 0
#endif

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
