## R GUI supplementary code and tools (loaded since R 2.9.0)

## target environment for all this
e<-attach(NULL,name="tools:RGUI")

add.fn <- function(name, FN) { assign(name, FN, e); environment(e[[name]]) <- e }

## quartz.save
add.fn("quartz.save", function(file, type='png', device=dev.cur(), dpi=100, ...) {
 # modified version of dev.copy2pdf
 dev.set(device)
 current.device <- dev.cur()
 nm <- names(current.device)[1]
 if (nm == 'null device') stop('no device to print from')
 oc <- match.call()
 oc[[1]] <- as.name('dev.copy')
 oc$file <- NULL
 oc$device <- quartz
 oc$type <- type
 oc$file <- file
 oc$dpi <- dpi
 din <- dev.size('in')
 w <- din[1]
 h <- din[2]
 if (is.null(oc$width))
   oc$width <- if (!is.null(oc$height)) w/h * eval.parent(oc$height) else w
 if (is.null(oc$height))
   oc$height <- if (!is.null(oc$width)) h/w * eval.parent(oc$width) else h
 dev.off(eval.parent(oc))
 dev.set(current.device)
})

## print.hsearch is our way to display search results internally
add.fn("print.hsearch", function (x, ...) 
{
    if (.Platform$GUI == "AQUA") {
        db <- x$matches
        rows <- NROW(db)
        if (rows == 0) {
            writeLines(strwrap(paste("No help files found matching", 
                sQuote(x$pattern), "using", x$type, "matching\n\n")))
        }
        else {
            url = character(rows)
            for (i in 1:rows) {
                tmp <- as.character(help(db[i, "topic"], package = db[i, 
                  "Package"], htmlhelp = TRUE))
                if (length(tmp) > 0) 
                  url[i] <- tmp
            }
            wtitle <- paste("Help topics matching", sQuote(x$pattern))
            showhelp <- which(.Internal(hsbrowser(db[, "topic"], 
                db[, "Package"], db[, "title"], wtitle, url)))
            for (i in showhelp) print(help(db[i, "topic"], package = db[i, 
                "Package"]))
        }
        invisible(x)
    }
    else utils:::printhsearchInternal(x, ...)
})

## --- the following functions are compatibility functions that wil go away very soon!

add.fn("browse.pkgs", function (repos = getOption("repos"), contriburl = contrib.url(repos, type), type = getOption("pkgType")) 
{
    if (.Platform$GUI != "AQUA") 
        stop("this function is intended to work with the Aqua GUI")
    x <- installed.packages()
    i.pkgs <- as.character(x[, 1])
    i.vers <- as.character(x[, 3])
    label <- paste("(", type, ") @", contriburl)
    y <- available.packages(contriburl = contriburl)
    c.pkgs <- as.character(y[, 1])
    c.vers <- as.character(y[, 2])
    idx <- match(i.pkgs, c.pkgs)
    vers2 <- character(length(c.pkgs))
    xx <- idx[which(!is.na(idx))]
    vers2[xx] <- i.vers[which(!is.na(idx))]
    i.vers <- vers2
    want.update <- rep(FALSE, length(i.vers))
    .Internal(pkgbrowser(c.pkgs, c.vers, i.vers, label, want.update))
})

add.fn("Rapp.updates", function () 
{
    if (.Platform$GUI != "AQUA") 
        stop("this function is intended to work with the Aqua GUI")
    cran.ver <- readLines("http://cran.r-project.org/bin/macosx/VERSION")
    ver <- strsplit(cran.ver, "\\.")
    cran.ver <- as.numeric(ver[[1]])
    rapp.ver <- paste(R.Version()$major, ".", R.version$minor, 
        sep = "")
    ver <- strsplit(rapp.ver, "\\.")
    rapp.ver <- as.numeric(ver[[1]])
    this.ver <- sum(rapp.ver * c(10000, 100, 1))
    new.ver <- sum(cran.ver * c(10000, 100, 1))
    if (new.ver > this.ver) {
        cat("\nThis version of R is", paste(rapp.ver, collapse = "."))
        cat("\nThere is a newer version of R on CRAN which is", 
            paste(cran.ver, collapse = "."), "\n")
        action <- readline("Do you want to visit CRAN now? ")
        if (substr(action, 1, 1) == "y") 
            system("open http://cran.r-project.org/bin/macosx/")
    }
    else {
        cat("\nYour version of R is up to date\n")
    }
})

add.fn("package.manager", function () 
{
    if (.Platform$GUI != "AQUA") 
        stop("this function is intended to work with the Aqua GUI")
    loaded.pkgs <- .packages()
    x <- library()
    x <- x$results[x$results[, 1] != "base", ]
    pkgs <- x[, 1]
    pkgs.desc <- x[, 3]
    is.loaded <- !is.na(match(pkgs, loaded.pkgs))
    pkgs.status <- character(length(is.loaded))
    pkgs.status[which(is.loaded)] <- "loaded"
    pkgs.status[which(!is.loaded)] <- " "
    pkgs.url <- file.path(.find.package(pkgs), "html", "00Index.html")
    load.idx <- .Internal(package.manager(is.loaded, pkgs, pkgs.desc, 
        pkgs.url))
    toload <- which(load.idx & !is.loaded)
    tounload <- which(is.loaded & !load.idx)
    for (i in tounload) {
        cat("unloading package:", pkgs[i], "\n")
        do.call("detach", list(paste("package", pkgs[i], sep = ":")))
    }
    for (i in toload) {
        cat("loading package:", pkgs[i], "\n")
        library(pkgs[i], character.only = TRUE)
    }
})

add.fn("data.manager", function () 
{
    if (.Platform$GUI != "AQUA") 
        stop("this function is intended to work with the Aqua GUI")
    data.by.name <- function(datanames) {
        aliases <- sub("^.+ +\\((.+)\\)$", "\\1", datanames)
        data(list = ifelse(aliases == "", datanames, aliases))
    }
    x <- data(package = .packages(all.available = TRUE))
    dt <- x$results[, 3]
    pkg <- x$results[, 1]
    desc <- x$results[, 4]
    len <- NROW(dt)
    url <- character(len)
    for (i in 1:len) {
        tmp <- as.character(help(dt[i], package = pkg[i], htmlhelp = TRUE))
        if (length(tmp) > 0) 
            url[i] <- tmp
    }
    as.character(help("BOD", package = "datasets", htmlhelp = T))
    load.idx <- which(.Internal(data.manager(dt, pkg, desc, url)))
    for (i in load.idx) {
        cat("loading dataset:", dt[i], "\n")
        data.by.name(dt[i])
    }
})

cat("[R.app GUI ",Sys.getenv("R_GUI_APP_VERSION")," (",Sys.getenv("R_GUI_APP_REVISION"),") ",R.version$platform,"]\n\n",sep='')
