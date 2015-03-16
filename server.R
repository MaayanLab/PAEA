library(shiny)
library(ggvis)
library(data.table)

library(tidyr)
library(dplyr)
library(preprocessCore)
# library(nasbMicrotaskViewerHelpers)
library(stringi)
# library(GeoDE)
library(Matrix)
library(MASS)


source('preprocess.R')
source('datain.R')
source('chdir.R')
source('paea.R')
source('misc.R')
source('stats.R')
source('downloads_handlers.R', local=TRUE)
source('config.R', local=TRUE)

last_modified <- sort(sapply(list.files(), function(x) strftime(file.info(x)$mtime)), decreasing=TRUE)[1]

options(shiny.maxRequestSize=120*1024^2) 

data <- if(file.exists('data/microtask.csv')) {
        dt <- preprocess_data(read.csv('data/microtask.csv', header = TRUE))
        list(
            description = extract_description(dt),
            genes = extract_genes(dt),
            samples = extract_samples(dt)
        )
    } else {
        preprocess('http://localhost/microtask.1.24.2015.csv')
}

shinyServer(function(input, output, session) {
    
    output$last_modified <- renderText({ last_modified })
    
    values <- reactiveValues()
    # Not required. Just to remind myself what is stored inside
    values$chdir <- NULL
    values$control_samples <- NULL
    values$treatment_samples <- NULL
    values$last_error <- NULL
    # Required
    values$paea_running <- FALSE
    
    
    #' Ugly hack to be able to clear upload widget
    #' 
    output$datain_container <- renderUI({
        fileInput(
            'datain', 'Choose file to upload',
            accept = c(
                'text/csv', 'text/comma-separated-values',
                'text/tab-separated-values', 'text/plain',
                '.csv', '.tsv'
            )
        )
    })
    
    
    #' Read input data
    #'
    datain <- reactive({
        inFile <- input$datain
        values$chdir <- NULL
        values$paea <- NULL
        
        if (is.null(inFile)) return(NULL)
        # Not optimal but read.csv is easier to handle
        as.data.table(read.csv(
            inFile$datapath, sep = input$sep
        ))
    })
    
    
    #' Is input valid?
    #'
    datain_valid <- reactive({ datain_is_valid(datain())$valid })
    
    
    #' Apply preprocessing steps to datain
    #'
    #'
    datain_preprocessed <- reactive({
        if(datain_valid()) {
            datain_preprocess(
                datain=datain(),
                log2_transform=input$log2_transform,
                quantile_normalize=input$quantile_normalize
            )
        } else {
            datain()
        }
    })
    
    #' Input data preview
    #'
    output$contents <- renderDataTable({
        datain_preprocessed()
    })
    
    
    #' control/treatment samples checboxes
    #'
    output$sampleclass_container <- renderUI({
        if (datain_valid()) {
            checkboxGroupInput(
                'sampleclass',
                'Choose control samples',
                colnames(datain())[-1]
            )
        } else if (is.null(datain())) {
            helpText('To select samples you have to upload your dataset.')
        } else if (ncol(datain()) == 1) {
            helpText('No experimental data detected. Please check separator and/or uploaded file')
        } else if (ncol(datain()) < 5) {
            helpText('You need at least four samples to run Characteristic Direction Analysis')
        } else {
            helpText('It looks like your dataset is invalid')
        }
    })
    
    
    #' Update lists of control/treatment samples
    #'
    observe({
        if(datain_valid()) {
            datain <- datain()
            samples_mask <- colnames(datain)[-1] %in%  input$sampleclass
            values$control_samples <- colnames(datain)[-1][samples_mask]
            values$treatment_samples <- colnames(datain)[-1][!samples_mask]
        } else {
            values$control_samples <- NULL
            values$treatment_samples <- NULL
        }
    })
    
    #' upload panel - status message
    #'
    output$upload_message <- renderText({
        if(is.null(datain())) {
            'preview not available...'
        }
    })
    
    
    #' datain tab - set plots visibility
    #'
    output$show_datain_results <- reactive({ datain_is_valid(datain())$valid })
    outputOptions(output, 'show_datain_results', suspendWhenHidden = FALSE)
    
    #' datain tab - density plot
    #'
    observe({
        if(datain_valid()) {
            plot_density(datain_preprocessed()) %>% bind_shiny('datain_density_ggvis')
        }
    })
    
    
    #' chdir panel - run button
    #'
    #'
    output$run_chdir_container <- renderUI({
        button <- actionButton(inputId = 'run_chdir', label = 'Run Characteristic Direction Analysis', icon = NULL)
        if(!datain_valid() | length(values$control_samples) < 2 | length(values$treatment_samples) < 2) {
             button$attribs$disabled <- 'true'
             list(
                button,
                if (is.null(datain())) {
                    helpText('Upload your dataset and select control samples first.')
                } else {
                    helpText('You need at least two control and two treatment samples to run chdir.')
                }
             )
            
        } else {
            button
        }
    })
    
    #' Not the best solution, but we want to render buttons even if we switch tabs using tourist
    #'
    outputOptions(output, 'run_chdir_container', suspendWhenHidden = FALSE)
    
    
    #' chdir panel - random number generator seed 
    #'
    output$random_seed_container <- renderUI({
        rng_seed_input <- numericInput('random_seed', 'Random  number generator seed', as.integer(Sys.time()))
        if(!input$set_random_seed) {
            rng_seed_input$children[[2]]$attribs$disabled <- 'true'
        }
        rng_seed_input
    })
    
    #' chdir panel - number of probes
    #'
    output$nprobes <- renderText({
        if(datain_valid()) {
            nrow(datain())
        }
    })
    
    
    #' chdir panel - number of genes
    #' 
    output$ngenes <- renderText({
        if(datain_valid()) {
            nlevels(datain()[[1]])
        }
    })

    
    #' chdir panel - control samples
    #'
    output$control_samples <- renderText({
        paste(values$control_samples, collapse = ', ')
    })
    
    
    #' chdir panel - treatment samples
    #'
    output$treatment_samples <- renderText({
        paste(values$treatment_samples, collapse = ', ')
    })
    
 
    #' Run Characteristic Direction Analysis
    #'
    observe({
        if(is.null(input$run_chdir)) { return() } else if(input$run_chdir == 0) { return() }
        datain <- isolate(datain_preprocessed())
        nnull <- min(as.integer(isolate(input$chdir_nnull)), 1000)
        gamma <- isolate(input$chdir_gamma)
        sampleclass <- factor(ifelse(colnames(datain)[-1] %in% isolate(input$sampleclass), '1', '2'))
        
        set.seed(isolate(input$random_seed))
        
        values$chdir <- tryCatch(
            chdir_analysis_wrapper(datain, sampleclass, gamma, nnull),
            error = function(e) {
                values$last_error <- e
                NULL
            }
        )

    })
    
    
    #' chdir tab - set plots visibility
    #'
    output$show_chdir_results <- reactive({ !is.null(values$chdir) })
    outputOptions(output, 'show_chdir_results', suspendWhenHidden = FALSE)

    
    #' Plot top genes from Characteristic Direction Analysis
    #'
    observe({
        # Not as reactive as it should be
        # https://groups.google.com/forum/#!topic/ggvis/kQQsdn1RYaE
        if(!is.null(values$chdir)) {
            results <- prepare_results(values$chdir$results[[1]])
            plot_top_genes(results) %>% bind_shiny('chdir_ggvis_plot')
        }
    })
    
    #' chdir panel number of significant genes to keep
    #' 
    output$ngenes_tokeep_contatiner <- renderUI({
        slider <- sliderInput(
            'ngenes_tokeep', label='Limit number of genes to return',
            min=1, max=config$max_ngenes_tokeep, step=1, value=100, round=TRUE
        )
        
        if(!is.null(values$chdir)) {
            ngenes <- length(values$chdir$results[[1]])
            limit <- min(config$max_fgenes_tokeep * ngenes, min(config$max_ngenes_tokeep, ngenes))
            slider$children[[2]]$attribs['data-max'] <- limit
            slider$children[[2]]$attribs['data-from'] <- ceiling(limit / 2)
        }
        slider
    })
    
    
    #' chdir panel - download block
    #'
    output$chdir_downloads_container <- renderUI({
        buttons <- list(
            downloadButton('download_chdir', 'Download chdir'),
            downloadButton('download_chdir_up', 'Download up genes'),
            downloadButton('download_chdir_down', 'Download down genes')
        ) 
        if (is.null(values$chdir)) {
            append(
                lapply(buttons, function(x) { x$attribs$disabled <- 'true'; x }),
                list(helpText('No data available. Did you run CHDIR analysis?'))
            )
        } else {
            buttons
        }
    })
    
    #' See coment for run_chdir_container
    #'
    outputOptions(output, 'chdir_downloads_container', suspendWhenHidden = FALSE)
    

    #' chdir panel - number of significant upregulated genes
    #'
    output$n_sig_up_genes <- renderText({
        if(!is.null(values$chdir)) {
            nrow(chdir_up_genes())
        }
    })
    
    #' chdir panel - number of significant downregulated genes
    #'
    output$n_sig_down_genes <- renderText({
        if(!is.null(values$chdir)) {
            nrow(chdir_down_genes())
        }
    })

    
    #' chdir panel - chdir download
    #'
    output$download_chdir <- downloadHandler(
        filename = 'chdir.tsv',
        content = chdir_download_handler(prepare_results(values$chdir$chdirprops$chdir[[1]][, 1]))
    )
    
    
    #' chdir panel - prepare down genes
    #'
    chdir_up_genes <- reactive({
        if(!is.null(values$chdir)) {
            prepare_up_genes(head(values$chdir$results[[1]], input$ngenes_tokeep))
        }
    })
    
    
    #' chdir panel - prepare up genes
    #'
    chdir_down_genes <- reactive({
        if(!is.null(values$chdir)) {
            prepare_down_genes(head(values$chdir$results[[1]], input$ngenes_tokeep))
        }
    })
    
    
    #' chdir panel - chdir download
    #'
    output$download_chdir_up <- downloadHandler(
        filename = 'chdir_up_genes.tsv',
        content = chdir_download_handler(chdir_up_genes())

    )
    
    #' chdir panel - chdir download
    #'
    output$download_chdir_down <- downloadHandler(
        filename = 'chdir_up_genes.tsv',
        content = chdir_download_handler(chdir_down_genes())
    )
    
    #' chdir panel - up genes table
    #'
    output$chdir_up_genes_table <- renderDataTable({
        if(!is.null(values$chdir)) {
            chdir_up_genes() %>%  rename(Gene = g, 'Characteristic Direction Coefficient' = v)
        }
    })
    
    
    #' chdir panel - down genes table
    #'
    output$chdir_down_genes_table <- renderDataTable({
        if(!is.null(values$chdir)) {
            chdir_down_genes() %>% rename(Gene = g, 'Characteristic Direction Coefficient' = v)
        }
    })
    
    
    #' paea panel - run button
    #'
    output$run_paea_container <- renderUI({
        button <- actionButton(inputId = 'run_paea', label = 'Run Principle Angle Enrichment', icon = NULL)
        if (values$paea_running) {
           list(
                {button$attribs$disabled <- 'true'; button}
            )
        } else if(is.null(values$chdir)) {
            list(
                {button$attribs$disabled <- 'true'; button},
                helpText('Before you can run PAEA you have to execute CHDIR analysis.')
            )
        } else {
            list(button)
        }
    })
    
    #' See coment for run_chdir_container
    #'
    outputOptions(output, 'run_paea_container', suspendWhenHidden = FALSE)
    
    #' chdir panel - status message
    #'
    output$chdir_message <- renderText({
        if(is.null(values$chdir)) {
            'results not available...'
        }
    })

        
    #' Run Principle Angle Enrichment Analysis
    #'
    observe({
        if(is.null(input$run_paea)) { return() } else if(input$run_paea == 0) { return() }
        chdir <- isolate(values$chdir)
        casesensitive <- isolate(input$paea_casesensitive)

        if(!(is.null(chdir))) {
            values$paea_running <- TRUE
            values$paea <- tryCatch(
                paea_analysis_wrapper(
                    chdirresults=chdir$chdirprops,
                    gmtfile=prepare_gene_sets(data$genes),
                    casesensitive=casesensitive
                ),
                error = function(e) {
                    print(e)
                    values$last_error <- e
                    NULL
                }
            )
            values$paea_running <- FALSE
        }
    })
    
    #' PAEA results
    #' 
    paea_results <- reactive({
        if(!is.null(values$paea)) {
            prepare_paea_results(values$paea$p_values, data$description)
        }
    })
    
    
    #' PAEA output
    #'
    output$pae_results <- renderDataTable({
        paea_results()
    })
    
    
    #' paea panel - download block
    #'
    output$paea_downloads_container <- renderUI({
        button <- downloadButton('download_paea', 'Download PAEA results')

        if (is.null(values$paea)) {
            list(
                {button$attribs$disabled <- 'true'; button},
                helpText('No data available. Did you run PAEA analysis?')
            )
        } else {
            button
        }
    })
    
    
    #' See coment for run_chdir_container
    #'
    outputOptions(output, 'paea_downloads_container', suspendWhenHidden = FALSE)
    
    
    #' paea panel - downloads handler
    #'
    output$download_paea <- downloadHandler(
        filename = 'paea.tsv',
        content = paea_download_handler(paea_results())
    )
    
    #' paea panel - status message
    #'
    output$paea_message <- renderText({
        if(is.null(values$paea)) {
            'results not available...'
        }
    })

})
