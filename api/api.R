## a Rook server handling POST request
library(Rook)
source('api_funcs.R')

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

  results <- api_paea(ids, library_name)

  res$write(results)
  res$finish()
}

s$add(app=my.app, name='PAEA')

## serve forever
while(TRUE) Sys.sleep(.Machine$integer.max)
