library(Rook)
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



s <- Rhttpd$new()
s$start(listen='127.0.0.1',port=13373)

my.app <- function(env){
  ## Start with a table and allow the user to upload a CSV-file
  req <- Request$new(env)
  res <- Response$new()
  res$header("Access-Control-Allow-Origin","*")
  res$header("Access-Control-Allow-Methods","GET,PUT,POST,DELETE")

  print(req$POST())
  ## trying to make the POST payload to be the same with Enrichr API 
  # preprocess POST payload
  ids <- strsplit(req$POST()$ids, ',')[[1]]
  library_name <- req$POST()$backgroundType

  print(ids)
  print(library_name)

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

  ptm <- proc.time()
  res$write(toJSON(results))
  print(proc.time()-ptm)
  res$finish()
}

s$add(app=my.app, name='PAEA')

## serve forever
while(TRUE) Sys.sleep(.Machine$integer.max)
