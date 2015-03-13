#' Download microtask dataset and 
#'
#' @param url character localization of the input file
#' @return data.frame
#'
download_data <- function(url = 'https://localhost/microtask.csv') {
    df <- if(stringi::stri_startswith_fixed(url, 'http')) {
        r <- httr::GET(url)
        if (r$status_code != 200) stop()
        con <- textConnection(httr::content(r, as="text"))
        df <- read.csv(con, header)
        close(con)
        df
    } else {
        read.csv(url)
    }
    as.data.table(df)
}


#' Convert do tbl_dt, add names, and clean strings
#'
#' @param dt data.table
#' @return tbl_dt
#'
preprocess_data <- function(dt) {
    trim_both <- stringi::stri_trim_both
    
    dplyr::tbl_dt(dt) %>% dplyr::rename(
        upregulated=up_genes, downregulated=dn_genes
    ) %>% 
    # Remove weird characters    
    dplyr::mutate(ctrl_ids = stringi::stri_replace_all_fixed(ctrl_ids, '&Acirc;&nbsp;', '')) %>% 
    dplyr::mutate(pert_ids = stringi::stri_replace_all_fixed(pert_ids, '&Acirc;&nbsp;', '')) %>%
    # Remove [ACCN]
    dplyr::mutate(geo_id = factor(
        stringi::stri_trim_both(stringi::stri_replace_all_fixed(geo_id, '[ACCN]', '')))) %>%
    # Strip whitespaces
    dplyr::mutate_each(dplyr::funs(trim_both), -id) %>%
        dplyr::mutate_each(dplyr::funs(factor), geo_id)
}


#' Create tidy table with sample ids
#'
#' @param dt tbl_dt as returned from preprocess_data
#' @return tbl_dt with 3 columns: id, group and sample
#'
extract_samples <- function(dt) {
    dt <- dt %>% dplyr::select(id, ctrl_ids, pert_ids) %>% 
        tidyr::gather('group', 'samples', ctrl_ids:pert_ids)
    dplyr::tbl_dt(as.data.table(do.call(rbind, mapply(
        cbind,
        dt$id,
        as.character(dt$group),
        stringi::stri_split_regex(dt$samples, '[\\.,;\\s]+', omit_empty = TRUE)
    )))) %>% dplyr::rename(id=V1, group=V2, sample=V3) %>%
        dplyr::mutate(id=as.integer(id))
}


#' Create tidy table with gene ids and optional chdir coefficients
#'
#' @param dt tbl_dt as returned from preprocess_data
#' @return tbl_dt with 4 columns: id, category, gene, chdir
#'
extract_genes <- function(dt) {
    split_fields <- function(x) {
        as.data.frame(do.call(rbind, lapply(
            stringi::stri_split_regex(x, ',|\\s+', omit_empty = TRUE),
            function(x) if(length(x) == 1) { c(x[1], "") } else x
        )))
    }
    
    dt <- dt %>% dplyr::select(id, upregulated, downregulated) %>%
        tidyr::gather('category', 'samples', upregulated:downregulated)
    
    dplyr::tbl_dt(as.data.table(do.call(rbind, mapply(
        cbind,
        dt$id,
        as.character(dt$category),
        stringi::stri_split_regex(dt$samples, '\n', omit_empty = TRUE)
    )))) %>%
    dplyr::rename(id=V1, category=V2) %>%
    dplyr::mutate(id=as.numeric(id)) %>%
    dplyr::mutate(gene = stringi::stri_extract_first_regex(V3, '([^\t,]+)')) %>%
    dplyr::mutate(chdir = stringi::stri_extract_first_regex(V3, '(?<=\t|,)([0-9\\.]+)$')) %>%
    dplyr::select(id, category, gene, chdir)
}


#' Extract general information about the dataset
#' 
#' @param dt tbl_dt as returned from preprocess_data
#' @return tbl_dt with columns: geo_id, (gene, pert_type | disease_name, disease_id | drug_name, drug_id ),
#'     organism, cell_type, id
extract_description <- function(dt) {
    dt %>% dplyr::select(-ctrl_ids, -pert_ids, -upregulated, -downregulated, -time)
}


#' Download dataset and extract relevant data
#' 
#' @param url character localization of the input file
#' @param drop_duplicates remove duplicated entries
#' @return list with description, genes and samples dt
#'
preprocess <- function(url='https://localhost/microtask.csv', drop_duplicates=TRUE) {
    dt <- preprocess_data(download_data(url))
    description <- extract_description(dt)
    genes <- extract_genes(dt)
    samples <- extract_samples(dt)
    if (drop_duplicates) {
        unique_submissions <- choose_unique_submissions(samples)
        description <- unique_submissions %>% dplyr::left_join(description, by='id')
        genes <- unique_submissions %>% dplyr::left_join(genes, by='id')
        samples <- unique_submissions %>% dplyr::left_join(samples, by='id')
    }
    
    list(
        description = description,
        genes = genes,
        samples = samples    
    )
}


#' Take genes table and prepare list of the gene sets
#' 
#' @param genes tbl_dt
#' @return list of the character vectors
#'
prepare_gene_sets <- function(genes) {
    genes_grouped <- genes %>% dplyr::group_by(id, category) %>%
        dplyr::summarise(genes=list(gene)) %>%
        dplyr::mutate(id_cat = stringi::stri_join(id, category, sep="_"))
    mapply(c, genes_grouped$id_cat, genes_grouped$genes)
}


#' Select ids of the unique submissions
#'
#' @param samples tbl_df as returned from preprocess$samples
#' @return data.frame with column id
#'
choose_unique_submissions <- function(samples) {
    combined_samples <- samples %>% 
        dplyr::group_by(id, group) %>% 
        dplyr::arrange(sample) %>%
        dplyr::summarise(samples=paste(sample, collapse='\t'))
    
    control_samples <- combined_samples %>% 
        dplyr::filter(group == 'ctrl_ids') %>% 
        dplyr::select(id, samples) %>%
        dplyr::rename(samples_control = samples)
    
    treatment_samples <- combined_samples %>% 
        dplyr::filter(group == 'pert_ids') %>% 
        dplyr::select(id, samples) %>%
        dplyr::rename(samples_treatment = samples)
    
    stopifnot(identical(dim(treatment_samples), dim(control_samples )))
    
    unique_samples <- dplyr::full_join(control_samples, treatment_samples, by='id') %>% 
        dplyr::group_by(samples_control, samples_treatment) %>% 
        dplyr::filter(row_number() == 1) %>%
        dplyr::summarise(id) %>% dplyr::select(id)
    
    data.table(id=unique_samples$id)
}
