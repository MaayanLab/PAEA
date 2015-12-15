library(Matrix)
library(dplyr)
library(RMySQL)
library(rjson)

source('dataAccess.R')
source('GeoDE.R')
## helper functions
get_chdir_from_g2e <- function(extract_id) {
	base_url <- "http://amp.pharm.mssm.edu/g2e/api/extract/"
	url <- paste0(base_url, extract_id)
	response <- httr::GET(url)
  print('response from G2E API got')
	if (response$status_code == 200) {
		response <- httr::content(response)
		gene_vals <- unlist(response$gene_lists[[3]]$ranked_genes)
		genes <- gene_vals[seq(1, length(gene_vals), 2)]
		vals <- as.numeric(gene_vals[seq(2, length(gene_vals), 2)])
		## convert to a object mocking the format of GeoDE::chdirAnalysis
		b <- matrix(vals, dimnames=list(genes))
		b <- list(b)
		chdir_ouput <- list(results=NULL, chdirprops=list(chdir=b, pca2d=NULL, chdir_pca2d=NULL))
		chdir_ouput
	} else {
		NULL
	}
}

api_paea <- function(ids, library_name) {
	## wrapper function for the API
	# retrieve gmt file from Enrichr
	gmtfile <- getTerms(library_name)
	print(length(gmtfile))
	# calculate PAEA for each extract_id
	results <- list()
	for (extract_id in ids) {
		chdirresults <- get_chdir_from_g2e(extract_id)
		paea <- PAEAAnalysis(chdirresults$chdirprops, gmtfile, gammas=c(1.0), casesensitive=FALSE, updateProgress=NULL)
	paea$terms <- colnames(paea$p_values)
		results[[extract_id]] <- paea
	}  
	toJSON(results)
}
