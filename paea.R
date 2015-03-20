source('GeoDE.R')
#' Take PAEA results and return data.frame with
#' gene set information and pvalue
#'
#' @param paea_results GeoDE::PAEAAnalysis output
#' @return tbl_df
#'
paea_to_df <- function(paea_results) {
    dplyr::tbl_df(data.frame(
        Index=c(1:length(paea_results$p_value)),
        Term=colnames(paea_results$p_value),
        Principal_Angle=as.vector(paea_results$principal_angles),
        p_value=as.vector(paea_results$p_value)
    ))
}

#' Take PAEA results and plot the
#' -log10(p_value) of top n enriched terms
#'
#' @param paea_results paea_analysis_wrapper output
#' @param n number of terms to plot
#' @return 
#'
plot_paea_bars <- function(paea_results, n) {
    # properties_x <- ggvis::axis_props(
    #     labels=list(fontSize=12), title=list(fontSize=14, dy=-35)
    # )
    paea_results %>%
        dplyr::mutate(logp=-log10(p_value)) %>%
        dplyr::top_n(n, logp) %>%
        ggvis(y=~factor(Term, Term[order(logp, decreasing=TRUE)]),x=~logp,x2=0, height=ggvis::band()) %>%
        ggvis::layer_rects() %>%
        # ggvis::scale_numeric('y', domain = c(min(paea_results$logp), max(paea_results$logp))) %>%
        ggvis::add_axis('x', grid=FALSE, title = '-log10(p-value)') %>%
        ggvis::add_axis('y', grid=FALSE, title = '') %>%
        # ggvis::hide_axis("y") %>%
        ggvis::add_tooltip(function(df) df[[1]])
}

#' Join PAEA results with data description
#' @param paea data frame as returned from paea_to_df
#' @param data_description tbl_df as returned from extract_description
#' @return tbl_df 
#'
prepare_paea_results <- function(paea, data_description) {
    paea %>%
        dplyr::mutate(id=as.numeric(id)) %>%
        dplyr::left_join(data_description, by='id') %>%
        dplyr::select(id, starts_with('category'), geo_id:cell_type, starts_with('pvalue'))
}

#' PAEAAnalysis wrapper. Redirects plots to /dev/null 
#'
#' @param chdirresults see GeoDE::PAEAAnalysis 
#' @param gmtfile see GeoDE::PAEAAnalysis 
#' @param gammas see GeoDE::PAEAAnalysis 
#' @param casesensitive see GeoDE::PAEAAnalysis 
#' @return paea results
#'

paea_analysis_wrapper <- function(chdirresults, gmtfile, gammas = c(1), casesensitive = FALSE, updateProgress = updateProgress){
    if(length(gmtfile) > 0 & length(chdirresults) > 0) {
        paea <- PAEAAnalysis(chdirresults, gmtfile, gammas, casesensitive, updateProgress)
        paea
    } else {
        warning('Cannot run paea with on empty input.')
        NULL
    }
}


#' Split chdir vector into negative and postive (plus zero) subvectors
#' 
#' @param chdirresults see GeoDE::PAEAAnalysis 
#' @return list with up and down fields
#'
split_chdirresults <- function(chdirresults) {
    # Split chdir results into up and down
    chdirresults_mask <- chdirresults[[1]][[1]][, 1] < 0
    chdirresults_up <-  list(list(chdirresults[[1]][[1]][!chdirresults_mask, , drop=FALSE]))
    chdirresults_down <- list(list(chdirresults[[1]][[1]][chdirresults_mask, , drop=FALSE]))
    list(up=chdirresults_up, down=chdirresults_down)
}


#' Split gmt file into up and down based on _downregulated suffix
#' 
#' @param gmtfile see GeoDE::chdirAnalysis
#' @return list with up and down sets 
#' 
split_gmtfile <- function(gmtfile) {
    gmtfile_mask <- unlist(lapply(gmtfile, function(x) { stringi::stri_endswith_fixed(x[1], '_downregulated') }))
    gmtfile_up <- gmtfile[!gmtfile_mask]
    gmtfile_down <- gmtfile[gmtfile_mask]
    list(up=gmtfile_up, down=gmtfile_down)
}


#' PAEAAnalysis dispatch function. Should handle separating chdirresults into up and down
#' and in future some filtering steps
#' 
#' @param chdirresults see GeoDE::PAEAAnalysis 
#' @param gmtfile see GeoDE::PAEAAnalysis 
#' @param gammas see GeoDE::PAEAAnalysis 
#' @param casesensitive see GeoDE::PAEAAnalysis 
#' @param strategy character 
#' @param with_progress boolean increment shiny progress bar
#' @return list with paea results
#'
paea_analysis_dispatch <- function(
        chdirresults, gmtfile, gammas = c(1),
        casesensitive = FALSE, strategy='up_up+down_down+up_down+down_up', with_progress=FALSE){    
    
    #' Split strategy string into individual components.
    #' Each component represents single paea run.
    #' 
    tasks <- unlist(stringi::stri_split_regex(strategy, '[+-]'))
    
    #' Increment progress bar
    #'
    if(with_progress) {
        try(
            shiny::incProgress(1 / (length(tasks) + 2), detail = 'Init'),
            silent=TRUE
        )
    }
    
    #' Preprocess query and background
    #'
    chdirresults_splitted <- split_chdirresults(chdirresults)
    gmtfile_splitted <- split_gmtfile(gmtfile)
    
    
    #' Run paea
    #'
    lapply(stringi::stri_split_fixed(tasks, '_'), function(task) {
        stopifnot(length(task) == 2)
        
        paea <- paea_analysis_wrapper(
            chdirresults=chdirresults_splitted[[task[1]]],
            gmtfile=gmtfile_splitted[[task[2]]],
            gammas=gammas,
            casesensitive=casesensitive
        )
        
        #' Increment progress bar
        #'
        if(with_progress) {
            try(
                shiny::incProgress(1 / (length(tasks) + 1), detail = paste(task, collapse = '_')),
                silent=TRUE
            )
        }
        
        paea 
        
    }) %>% setNames(tasks)
    
    
}

#' Take multiple paea results and join by gmt
#'
#' @param paea_results list of data.frames as returned from paea_analysis_dispatch
#' @param strategy character 
#' @param pvalue_threshold numeric
#' @return data.frame
#'
combine_results <- function(paea_results, strategy, pvalue_threshold=5e-2){
 
    filters <- list(
        '+' = function(x) dplyr::filter(x, pvalue < pvalue_threshold),
        '-' = function(x) dplyr::filter(x, pvalue > pvalue_threshold)
    )

    process_part <- function(part) {
        op <- stringi::stri_sub(part, to=1)
        name <- stringi::stri_sub(part, from=2)
        
        paea_results[[name]] %>% 
            dplyr::select(id, pvalue) %>%
            filters[[op]]() %>%
            setNames(c('id', paste('pvalue', name, sep='_')))
    }

    #' We need by argument and this cannot be 
    #' passed directly to Reduce 
    #'
    join_pair <- function(x, y) {
        x %>% dplyr::inner_join(y, by='id')
    }
    
    #' Extract parts of the workflow
    #'
    parts <- unlist(stringi::stri_extract_all_regex(
        strategy, '[+-](up|down)_(up|down)'
    ))
    
    Reduce(join_pair, lapply(parts, process_part))
}
