library('dplyr')

databaseConn <- src_mysql(dbname = 'enrichr', host = 'master', user = 'root', password = '4reYuXuhuz')

subVars <- function(strexpr, vars){
  for(i in range(length(vars))){
    strexpr <- sub(x = strexpr, pattern = names(vars)[i], replacement = paste0('"',vars[i], '"'))
  }
  eval((parse(text = strexpr)), envir = parent.frame())
}

getActiveLibraries <- function(){
  libraryTable <- tbl(src = databaseConn, "geneSetLibrary")
  filter(libraryTable, isActive == 1)
}

getGeneSetLibrary_ <- function(libName){
  libraryTable <- tbl(src = databaseConn, "geneSetLibrary")
  termTable <- tbl(databaseConn, "term")
  termTable <- rename(termTable, term.name = name)
  termGenesTable <- tbl(databaseConn, "termGenes")
  genesTable <- tbl(databaseConn, "genes")
  genesTable <- rename(genesTable, gene.name = name)
  
  a <- inner_join(libraryTable, termTable, by = "libraryId")
  b <- inner_join(a, termGenesTable, by="termId")
  allTables <- inner_join(b, genesTable, by="geneId")
  
  subVars(strexpr = "filter(allTables, libraryName == x_)", vars = list(x_ = libName))
}

getTerms <- function(libName){
  gsl <- getGeneSetLibrary_(libName)
  terms <- select(gsl, term.name, gene.name)
  terms <- arrange(terms, term.name)
  terms <- as.data.frame(terms, n=-1)
  starts <- which(!duplicated(terms$term.name))
  start_ <<- 1
  raggedArray <- lapply(starts[-1], function(x) {ret <- terms$gene.name[start_:x]
                                  start_ <<- x
                                  ret})
  raggedArray
}