R app embedding R.

This is a true Cocoa application that embeds R.

The original code for embedding R in Cocoa is Simon's work.

You can consider this or any other derivative of this product a four-hand work of me and Simon.

R is started up with the option --gui=cocoa, this is temporarily needed because R_ProcessEvents is to be 
called from libR.dylib into the Cocoa app, and --gui=cocoa simply set a flag to conditionalize the 
R_ProcessEvents inside src/unix/aqua.c code. Once the aqua module will be declared "Defunct", --gui=aqua
would be enough

There are several tricks I did and there are several things to take into account. In sparse order, here they are:
1.  after awakefromnib, instead of blocking the main cocoa event loop directly calling  run_Rmainloop, a timer fires 
	once to call this function. At this point the menu bar is correctly built and the GUI can respond to the related 
	events.

2. to test x11/tcltk try the following:
	a)	run the X window server using the X11 icon int he toolbar
	b)	> library(tcltk)
	c)	> demo(tkdensity)

	it works! On the contrary AquaTclTk doesn't work at all, or at least is works as badly as it was for the Carbon RAqua.

Note: to build the R for Mac OS XFaq use the following command form the shell
	makeinfo -D UseExternalXrefs --html --force --no-split RMacOSX-FAQ.texi

For everything else read the NEWS file 

stefano

Milan and Augsburg, 2004-10-10


