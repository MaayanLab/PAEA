#' Count number of submissions per user
#' 
#' @param list of dataframes as returned from preprocess
#' @return data.frame with curator and n
#'
submissions_per_user <- function(dataset) {
    dataset$description %>% dplyr::group_by(curator) %>% dplyr::summarise(n=n())
}

#' Count number of submissions per cell type
#' 
#' @param list of dataframes as returned from preprocess
#' @return data.frame with cell_type and n
#'
submissions_per_cell_type <- function(dataset) {
    dataset$description %>% dplyr::group_by(cell_type) %>% dplyr::summarise(n=n())
}


#' Count number of submissions per organism
#' 
#' @param list of dataframes as returned from preprocess
#' @return data.frame with organism and n
#'
submissions_per_organism <- function(dataset) {
    dataset$description %>% dplyr::group_by(organism) %>% dplyr::summarise(n=n())
}


#' Count number of sets covering given gene
#' 
#' @param list of dataframes as returned from preprocess
#' @return data.frame with gene and n
#'
genes_coverage <- function(dataset) {
     dataset$genes %>% dplyr::group_by(gene) %>% dplyr::summarise(n=n())   
}