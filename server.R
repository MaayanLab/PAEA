library(shiny)
library(ggvis)
library(data.table)
library(tidyr)
library(dplyr)
library(preprocessCore)
library(stringi)
library(Matrix)
library(MASS)
library(rjson)
library(RMySQL)
library(httr)

source('dataAccess.R')
source('preprocess.R')
source('datain.R')
source('chdir.R')
source('diseases.R')
source('paea.R')
source('misc.R')
source('stats.R')
source('downloads_handlers.R', local=TRUE)
source('config.R', local=TRUE)

# run the flask server
system(paste('python server.py', config$port), wait=FALSE)

last_modified <- sort(sapply(list.files(), function(x) strftime(file.info(x)$mtime)), decreasing=TRUE)[1]

options(shiny.maxRequestSize=120*1024^2) 

# Meta data of all gmt files from the Enrichr API
meta_gmts <- getGroupedLibraries()
meta_gmts <- as.data.frame(meta_gmts)
# Meta data for disease signatures from file
disease_sigs_choices <- read_disease_meta(config$dz_meta)

shinyServer(function(input, output, session) {
    counter_value <- getCounterValue()
    output$counter_value <- renderText({ counter_value })
    output$last_modified <- renderText({ last_modified })
    
    values <- reactiveValues()
    
    # retrieve chdir from database url_search is available
    observe({
        updateTextInput(session, "desc", value = input$desc)
            if (session$clientData$url_search == "") {
                values$chdir <- NULL
            } else {
                values$chdir <- get_chdir_from_flask(session, config$api_url)
                if (!is.null(values$chdir)) {
                    updateTextInput(session, "desc", value = values$chdir$desc)
                }
            }
        })
    


    values$control_samples <- NULL
    values$treatment_samples <- NULL
    values$last_error <- NULL
    values$paea <- list()
    # Required
    values$paea_running <- FALSE

    #' File upload widget
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

        if (is.null(inFile)) {
            if (input$load_example_data != 0) {
                as.data.table(read.csv(
                    'www/data/expression_example.csv', sep = input$sep
                ))
            } 
        } else { # has file uploaded
            as.data.table(read.csv(
                inFile$datapath, sep = input$sep
            ))
        }
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
        format(datain_preprocessed(), digits=config$digits) # to keep digits to display in the dataTable
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
        else{
            if(!is.null(values$chdir)) { length(values$chdir$results[[1]]) }
        }
    })
    
    
    #' chdir panel - number of genes
    #' 
    output$ngenes <- renderText({
        if(datain_valid()) {
            nlevels(datain()[[1]])
        }
        else{
            if(!is.null(values$chdir)) { length(values$chdir$results[[1]]) }
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

        updateCounterValue()

        # save the list to database `paea`
        chdir <- isolate(values$chdir)
        desc <-input$desc
        response <- post_chdir_to_flask(chdir, desc, config$api_url)
    })
    

    #' chdir panel - disease signature choice
    updateSelectizeInput(
        session, 'disease_sigs_choices',
        choices = disease_sigs_choices, server = TRUE
        )

    #' chdir panel - disease sig observe
    #'
    values$fetch_disease_sig <- isolate(input$fetch_disease_sig)
    observe({
        if(is.null(input$fetch_disease_sig) || input$fetch_disease_sig == values$fetch_disease_sig) { return() }
        else{ # botton clicked
            if (input$disease_sigs_choices != ''){
                values$fetch_disease_sig <- isolate(input$fetch_disease_sig)
                uid <- isolate(input$disease_sigs_choices)
                signature_path <- paste0('data/dz_signatures/', uid, '.json')
                values$chdir <- prepare_disease_signature(signature_path) # load disease signature
                values$paea <- NULL # empty paea results for previously loaded chdir
            }
        }
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
            results <- prepare_results(values$chdir$results[[1]]) # top 40 genes to plot
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
    

    #' paea panel - output a table of active gmt files
    #'
    
    #' radio button for selecting category
    output$categories <- renderUI(
        selectInput('categories','Categories of Gene-set Library', unique(meta_gmts$name), unique(meta_gmts$name)[[1]])
    )
    
    #' select libraries for selected category
    output$libraries <- renderUI({
        selected_category <- input$categories
        libraries <- meta_gmts %>% dplyr::filter(name==selected_category) %>% dplyr::select(libraryName)
        libraries <- sort(as.data.frame(libraries)$libraryName) # names of library within the selected category
        # seems to introduce an error here "Error in eval(substitute(expr), envir, enclos) : incorrect length (0), expecting: 58"
        radioButtons('libraries', 'Gene-set Libraries', libraries)
    })

    #' PAEA results // stable
    #' 
    paea_results <- reactive({
        if(is.null(values$chdir)) {
            # helpText('Before you can run PAEA you have to execute CHDIR analysis.')
            NULL
        } else { # chdir finished
            library <- input$libraries[[1]]
            if(!is.null(values$paea[[library]])) { 
                values$paea[[library]]
            } else {
                values$paea_running <- TRUE
                chdir <- isolate(values$chdir)
                gmtfile <- getTerms(library)
                gmtlen <- length(gmtfile)

                progress <- shiny::Progress$new(max=gmtlen)
                progress$set(message = "Performing PAEA", value = 0)
                on.exit(progress$close())
                
                updateProgress <- function(value = NULL, detail = NULL) {
                  if (is.null(value)) {
                    value <- progress$getValue()
                  }
                  progress$set(value = value, detail = detail)
                }

                values$paea[[library]] <- paea_analysis_wrapper(
                    chdirresults=chdir$chdirprops,
                    gmtfile=gmtfile,
                    casesensitive=FALSE,
                    updateProgress=updateProgress
                )

                values$paea_running <- FALSE
                values$paea[[library]]
            }
        }
    })
    

    #' PAEA output
    #' table
    output$paea_table <- renderDataTable({
        if(!is.null(paea_results())){
            format(paea_to_df(paea_results()), digits=config$digits)
        }
    })
    #' bar graph
    observe({
        if(!is.null(paea_results())) {
            plot_paea_bars(paea_to_df(paea_results()), config$num_paea_bars) %>% bind_shiny('paea_bars')
        }
    })

})
