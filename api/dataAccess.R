## Script to connect to the database behind Enrichr
## Authors: Matthew Jones, Zichen Wang

# databaseConn <- dplyr::src_mysql(dbname = 'enrichr', host = 'amp.pharm.mssm.edu', user = 'paea', password = 'systemsbiology')
pool <- pool::dbPool(
  drv = RMySQL::MySQL(),
  dbname = "enrichr",
  host = "amp.pharm.mssm.edu",
  username = "paea",
  password = "systemsbiology",
  idleTimeout = Inf
  )
databaseConn <- pool::src_pool(pool)
# conn <- RMySQL::dbConnect(RMySQL::MySQL(), dbname = 'enrichr', host = 'amp.pharm.mssm.edu', user = 'paea', password = 'systemsbiology')

subVars <- function(strexpr, vars){
  for(i in range(length(vars))){
    strexpr <- sub(x = strexpr, pattern = names(vars)[i], replacement = paste0('"',vars[i], '"'))
  }
  eval((parse(text = strexpr)), envir = parent.frame())
}

getCategories <- function(){
  libraryTable <- dplyr::tbl(src = databaseConn, "category")
  dplyr::select(libraryTable, categoryId, name)
}

getActiveLibraries <- function(){
  libraryTable <- dplyr::tbl(src = databaseConn, "geneSetLibrary")
  dplyr::filter(libraryTable, isActive == 1)
}

getGroupedLibraries <- function(){
  meta_gmts <- getActiveLibraries()
  cate <- getCategories()
  meta_gmts <- dplyr::inner_join(cate, meta_gmts, by="categoryId")
  meta_gmts %>% dplyr::arrange(categoryId) %>%
    dplyr::select(name, libraryName, numTerms, geneCoverage)
}

getGeneSetLibrary_ <- function(libName){
  # conn <- pool::src_pool(databaseConn)
  libraryTable <- dplyr::tbl(src = databaseConn, "geneSetLibrary")
  termTable <- dplyr::tbl(databaseConn, "term")
  termTable <- dplyr::rename(termTable, term.name = name)
  termGenesTable <- dplyr::tbl(databaseConn, "termGenes")
  genesTable <- dplyr::tbl(databaseConn, "genes")
  genesTable <- dplyr::rename(genesTable, gene.name = name)
  
  a <- dplyr::inner_join(libraryTable, termTable, by = "libraryId")
  b <- dplyr::inner_join(a, termGenesTable, by="termId")
  allTables <- dplyr::inner_join(b, genesTable, by="geneId")
  
  subVars(strexpr = "dplyr::filter(allTables, libraryName == x_)", vars = list(x_ = libName))
}

getTerms <- function(libName){
  gsl <- getGeneSetLibrary_(libName)
  terms <- dplyr::select(gsl, term.name, gene.name)
  terms <- dplyr::arrange(terms, term.name)
  terms <- as.data.frame(terms)
  starts <- which(!duplicated(terms$term.name))
  start_ <<- 1
  raggedArray <- lapply(starts[-1], function(x) {ret <- c(terms$term.name[start_], terms$gene.name[start_:x])
                                  start_ <<- x
                                  ret})
  raggedArray
}

getCounterValue <- function(){
  countTable <- dplyr::tbl(src = databaseConn, "counters")
  as.data.frame(countTable)$count[3]
}

updateCounterValue <- function(){
  # dplyr doesn't seem to be able to update MySQL table
  conn <- pool::poolCheckout(pool)
  RMySQL::dbSendQuery(conn, "UPDATE counters SET count=count+1 WHERE name='paea'")
  RMySQL::dbDisconnect(conn)
}
