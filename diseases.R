#' Prepare disease signature from file
#' @param filename name of the file that contain the disease signature of interest
#' @return a nested list that has the same structure with the output of GeoDE::chdirAnalysis 
#'
prepare_disease_signature <- function(filename) {
	geneset <- rjson::fromJSON(file=filename)
	b <- matrix(geneset$vals, dimnames=list(geneset$genes))
	b <- list(b)
	results <- lapply(b, function(x) {x[sort.list(x^2,decreasing=TRUE),]})
	chdir_ouput <- list(results=results, chdirprops=list(chdir=b, pca2d=NULL, chdir_pca2d=NULL))
	chdir_ouput
}

#' Read meta data for disease signature from file
#' @param filename name of the file that contain the meta-data of disease signature
#' @return a list of meta info for all the disease signatures
#'
read_disease_meta <- function(filename) {
	meta <- data.table::fread(filename)
	choices <- setNames(
		meta$uid,
		paste(meta$disease_name, meta$cell_type, meta$geo_id, sep = ' | ')
		)
	choices
}
