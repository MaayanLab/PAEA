source('GeoDE.R')
#' Prepare chdir results for plotting
#' @param results numeric vector extracted from pchdir results
#' @param n numeric max number of genes to keep
#' @return data.frame
#'
prepare_results <- function(results, n=40) {
    results <- head(results, n)
    data.frame(
        g = factor(
            names(results),
            names(results)[order(abs(results), decreasing=TRUE)]
        ),
        v = results
    )
}

#' Extract downregulated genes from results
#' @param results numeric vector extracted from pchdir results
#' @return data.frame
#'
prepare_down_genes <- function(results) {
    prepare_results(results, length(results)) %>% dplyr::filter(v < 0)
}

#' Extract upregulated genes from results
#' @param results numeric vector extracted from pchdir results
#' @return data.frame
#'
prepare_up_genes <- function(results) {
    prepare_results(results, length(results)) %>% dplyr::filter(v > 0)
}


#' Plot top genes from chdirAnalysis
#' @param results data frame returned from prepare_results 
#' @return ggvis plot
#'
plot_top_genes <- function(results) {

    properties_x <- ggvis::axis_props(
        axis=list(stroke=NULL), 
        ticks = list(stroke = NULL),
        labels=list(angle=-90, fontSize = 12, align='right'),
        title=list(fontSize=14, dx=-35)
    )
    
    properties_y <- ggvis::axis_props(
        labels=list(fontSize=12), title=list(fontSize=14, dy=-35)
    )
    
    ggvis(results, ~g, ~v) %>% 
        ggvis::layer_bars(width = 0.75) %>%
        ggvis::scale_numeric('y', domain = c(min(results$v), max(results$v))) %>%
        ggvis::add_axis('y', grid=FALSE, title = 'Coefficient', properties = properties_y) %>%
        ggvis::add_axis('x', grid=FALSE, offset = 10, title = '', properties = properties_x) %>%
        ggvis::add_tooltip(function(df) df$x_)
}


#' Preprocess input to chdirAnalysis
#'
#' @param datain see GeoDE::chdirAnalysis
#' @return data.frame
#'
preprocess_chdir_input <- function(datain) {
    datain %>%
        dplyr::rename_(IDENTIFIER=as.symbol(colnames(datain)[1])) %>%
        dplyr::group_by(IDENTIFIER) %>%
        dplyr::summarise_each(dplyr::funs(mean))
}


#' chdirAnalysis wrapper. Redirects plots to /dev/null and handles data aggregation
#'
#' @param datain see GeoDE::chdirAnalysis
#' @param sampleclass see GeoDE::chdirAnalysis
#' @param gammas see GeoDE::chdirAnalysis
#' @param nnull see GeoDE::chdirAnalysis
#'
chdir_analysis_wrapper <- function(datain, sampleclass, gammas, nnull) {

    datain <- preprocess_chdir_input(datain)
    datain <- dplyr::tbl_df(datain)
    chdir <- chdirAnalysis(
        # Group by gene label and compute mean
        datain,
        sampleclass=sampleclass,
        CalculateSig=FALSE,
        gammas=gammas,
        nnull=nnull
    )
    chdir
}

#' send POST request to Enrichr API to save a gene list
# @param chdir: the output from chdir_analysis_wrapper function
# @param desc: description of the signature
post_chdir_to_enrichr <- function(chdir, desc) {
    res <- chdir$results[[1]]
    genes <- names(res)
    inputList <- paste(genes, res, sep=',')
    response <- httr::POST("http://amp.pharm.mssm.edu/Enrichr/addList", encode="multipart", body = list(
        list = paste(inputList, collapse='\n'),
        inputMethod = "PAEA",
        description=desc
    ))
    response
}

#' send GET request to the enrichr API server to retrieve a gene list
# @param session: session from shinyServer
get_chdir_from_enrichr <- function(session) {
    url_query <- shiny::parseQueryString(session$clientData$url_search)
    userListId <- url_query$id
    response <- httr::GET("http://amp.pharm.mssm.edu/Enrichr/getList", query=list(userListId=userListId))
    if (response$status_code == 200) {
        response_text <- httr::content(response, 'text')
        geneset <- rjson::fromJSON(response_text)
        desc <- geneset$description
        s <- strsplit(geneset$genes, ',')
        genes <- sapply(s, function(x) {x[1]})
        coefs <- as.numeric(sapply(s, function(x) {x[2]}))
        b <- matrix(coefs, dimnames=list(genes))
        b <- list(b)
        results <- lapply(b, function(x) {x[sort.list(x^2,decreasing=TRUE),]})
        chdir_ouput <- list(results=results, chdirprops=list(chdir=b, pca2d=NULL, chdir_pca2d=NULL), desc=desc)
        chdir_ouput        
        } else {
            NULL
        }
}

#' send POST request to the flask server to save a gene list
# @param chdir: the output from chdir_analysis_wrapper function
# @param desc: description for the chdir signature
post_chdir_to_flask <- function(chdir, desc, api_url) {
    res <- chdir$results[[1]]
    genes <- names(res)
    coefs <- c()
    for (i in 1:length(res)) {
        coefs <- c(coefs, res[[i]])
    }
    response <- httr::POST(api_url, body = list(
        genes = genes,
        coefs = coefs,
        desc=desc
        ),
    encode='json'
    )
    response
}

#' send GET request to the flask server to retrieve a gene list
# @param session: session from shinyServer
get_chdir_from_flask <- function(session, api_url) {
    url_query <- shiny::parseQueryString(session$clientData$url_search)
    hash_str <- url_query$id
    response <- httr::GET(api_url, query=list(id=hash_str))
    if (response$status_code == 200) {
        response_text <- httr::content(response, 'text')
        geneset <- rjson::fromJSON(response_text)
        b <- matrix(geneset$coefs, dimnames=list(geneset$genes))
        b <- list(b)
        results <- lapply(b, function(x) {x[sort.list(x^2,decreasing=TRUE),]})
        chdir_ouput <- list(results=results, chdirprops=list(chdir=b, pca2d=NULL, chdir_pca2d=NULL), desc=geneset$desc)
        chdir_ouput        
        } else {
            NULL
        }
}

#' for running asynconized process
# @ param expr: expression to run asynconized fashion
# ref: https://www.rforge.net/doc/packages/background/async.html
future <- function(expr) {
  p = parallel::mcparallel(expr)
  async.add(p$fd[1], function(h, p) {
     async.rm(h)
     print(parallel::mccollect(p)[[1]])
  }, p)
  invisible(p)
}
