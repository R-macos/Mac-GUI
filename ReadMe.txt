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

=== Note to developers ===
If you intend to work on the source code of R.app, please adjust your editor to use tabs. Each indentation level
should be exactly one tab. The preferred setting in Xcode is (in Preferences -> TextEditing)
  [X] Editor uses tabs
  Tab width: [4] Indent width: [4]
This will give you the proper indenting behavior and fairly well readable code. You can replace the "4" in both fields by
any positive value you find pleasant, just make sure both entries are identical. Use Xcode-style indentation whenever possible.
The strict use of tabs as indentation marks makes it possible for everyone to view the code with the spacing s/he prefers.

Note: to build the R for Mac OS XFaq manually use the following command from the shell
	makeinfo -D UseExternalXrefs --html --force --no-split RMacOSX-FAQ.texi

For everything else read the NEWS file 

stefano

Milan and Augsburg, 2004-10-10
