#' 
#' @param chdir list
#' @return function
#'
chdir_download_handler <- function(chdir) {
    function(file) {
        write.table(
            data.frame(chdir),
            file=file,
            quote = FALSE,
            col.names=FALSE
        )
    }
}