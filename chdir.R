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
        ggvis::add_axis('x', grid=FALSE, offset = 10, title = '', properties = properties_x)
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

    png('/dev/null')
    chdir <- GeoDE::chdirAnalysis(
        # Group by gene label and compute mean
        datain,
        sampleclass=sampleclass,
        CalculateSig=TRUE,
        gammas=gammas,
        nnull=nnull
    )
    dev.off()
    chdir
}

