#' Prepare input for Enrichr form
#'
#' @param chdir_results data.frame as returned from prepare_results
#' @return character 
#'
prepare_enrichr_input <- function(chdir_results) {
    paste(apply(chdir_results %>% dplyr::mutate(v = abs(v)), 1, paste, collapse=','), collapse = '\n')
}
