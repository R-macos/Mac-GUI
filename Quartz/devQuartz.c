/*
 *  For compatibility with 2.1.0 - implements stuff formerly present in devQuartz.c in libR
 *
 *  Created by Simon Urbanek on 1/13/05 (based on devQuartz in 2.0.1 by Stefano Iacus)
 *
 */

#include "devQuartz.h"

#include <Rversion.h>
#include <R.h>
#include <Rdefines.h>
#include <Rinternals.h>

/* since 2.1.0 devQuartz is no longer in libR, so we need to duplicate it here */
#if (R_VERSION >= R_Version(2,1,0))

static char *SaveFontSpec(SEXP sxp, int offset) {
	char *s;
	if(!isString(sxp) || length(sxp) <= offset)
		error("Invalid font specification");
	s = R_alloc(strlen(CHAR(STRING_ELT(sxp, offset)))+1, sizeof(char));
	strcpy(s, CHAR(STRING_ELT(sxp, offset)));
	return s;
}

char* RGUI_Quartz_TranslateFontFamily(char* family, int face, char *devfamily) {
	SEXP graphicsNS, quartzenv, fontdb, fontnames;
	int i, nfonts;
	char* result = devfamily;
	PROTECT_INDEX xpi;
	
	PROTECT(graphicsNS = R_FindNamespace(ScalarString(mkChar("grDevices"))));
	PROTECT_WITH_INDEX(quartzenv = findVar(install(".Quartzenv"), 
										   graphicsNS), &xpi);
	if(TYPEOF(quartzenv) == PROMSXP)
		REPROTECT(quartzenv = eval(quartzenv, graphicsNS), xpi);
	PROTECT(fontdb = findVar(install(".Quartz.Fonts"), quartzenv));
	PROTECT(fontnames = getAttrib(fontdb, R_NamesSymbol));
	nfonts = LENGTH(fontdb);
	if (strlen(family) > 0) {
		int found = 0;
		for (i=0; i<nfonts && !found; i++) {
			char* fontFamily = CHAR(STRING_ELT(fontnames, i));
			if (strcmp(family, fontFamily) == 0) {
				found = 1;
				result = SaveFontSpec(VECTOR_ELT(fontdb, i), face-1);
			}
		}
		if (!found)
			warning("Font family not found in Quartz font database");
	}
	UNPROTECT(4);
	return result;
}
#endif
