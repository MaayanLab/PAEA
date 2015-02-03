library(shiny)
library(ggvis)
library(data.table)
library(dplyr)
library(nasbMicrotaskViewerHelpers)

source('downloads_handlers.R', local=TRUE)

last_modified <- sort(sapply(list.files(), function(x) strftime(file.info(x)$mtime)), decreasing=TRUE)[1]

options(shiny.maxRequestSize=120*1024^2) 

data <- if(file.exists('data/microtask.csv')) {
        dt <- nasbMicrotaskViewerHelpers::preprocess_data(read.csv('data/microtask.csv', header = FALSE))
        list(
            description = nasbMicrotaskViewerHelpers::extract_description(dt),
            genes = nasbMicrotaskViewerHelpers::extract_genes(dt),
            samples = nasbMicrotaskViewerHelpers::extract_samples(dt)
        )
    } else {
        nasbMicrotaskViewerHelpers::preprocess('http://localhost/microtask.1.24.2015.csv')
}

shinyServer(function(input, output, session) {
    
    output$last_modified <- renderText({ last_modified })
    
    values <- reactiveValues()
    # Not required. Just to remind myself what is stored inside
    values$chdir <- NULL
    values$control_samples <- NULL
    values$treatment_samples <- NULL
    values$last_error <- NULL
    
    
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
        
        if (is.null(inFile)) return(NULL)
        # Not optimal but read.csv is easier to handle
        as.data.table(read.csv(
            inFile$datapath, sep = input$sep
        ))
    })
    
    
    #' Input data preview
    #'
    output$contents <- renderDataTable({
        datain()
    })
    
    
    #' control/treatment samples checboxes
    #'
    output$sampleclass_container <- renderUI({
        if (!is.null(datain()) && ncol(datain()) > 1 ) {
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
        }
    })
    
    
    #' Update lists of control/treatment samples
    #'
    observe({
        datain <- datain()
        if(!is.null(datain)) {
            samples_mask <- colnames(datain)[-1] %in%  input$sampleclass
            values$control_samples <- colnames(datain)[-1][samples_mask]
            values$treatment_samples <- colnames(datain)[-1][!samples_mask]
        } else {
            values$control_samples <- NULL
            values$treatment_samples <- NULL
        }
    })
    
    
    output$run_chdir_container <- renderUI({
        button <- actionButton(inputId = 'run_chdir', label = 'Run Characteristic Direction Analysis', icon = NULL)
        if(is.null(datain()) | length(values$control_samples) < 2 | length(values$treatment_samples) < 2) {
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
    
    
    #' chdir panel - number of probes
    #'
    output$nprobes <- renderText({
        if(!is.null(datain())) {
            nrow(datain())
        }
    })
    
    
    #' chdir panel - number of genes
    #' 
    output$ngenes <- renderText({
        if(!is.null(datain())) {
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
        datain <- isolate(datain())
        nnull <- min(as.integer(isolate(input$chdir_nnull)), 1000)
        gamma <- isolate(input$chdir_gamma)
        sampleclass <- factor(ifelse(colnames(datain)[-1] %in% isolate(input$sampleclass), '1', '2'))
        
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
        if(!is.null(values$chdir)) {
            results <- prepare_results(values$chdir$results[[1]])
            plot_top_genes(results) %>% bind_shiny('chdir_ggvis_plot')
        }
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
    

    #' chdir panel - number of significant genes
    #'
    output$n_sig_genes <- renderText({
        if(!is.null(values$chdir)) {
            values$chdir$chdirprops$number_sig_genes[[1]]
        }
    })

    
    #' chdir panel - chdir download
    #'
    output$download_chdir <- downloadHandler(
        filename = 'chdir.tsv',
        content = chdir_download_handler(prepare_results(values$chdir$chdirprops$chdir[[1]][, 1]))
    )
    
    
    #' chdir panel - chdir download
    #'
    output$download_chdir_up <- downloadHandler(
        filename = 'chdir_up_genes.tsv',
        content = chdir_download_handler(prepare_up_genes(values$chdir$results[[1]]))

    )
    
    #' chdir panel - chdir download
    #'
    output$download_chdir_down <- downloadHandler(
        filename = 'chdir_up_genes.tsv',
        content = chdir_download_handler(prepare_down_genes(values$chdir$results[[1]]))
    )
    
    #' paea panel - run button
    #'
    output$run_paea_container <- renderUI({
        button <- actionButton(inputId = 'run_paea', label = 'Run Principle Angle Enrichment', icon = NULL)
        if(is.null(values$chdir)) {
            button$attribs$disabled <- 'true'
            list(
                button,
                helpText('Before you can run PAEA you have to execute CHDIR analysis.')
            )
        } else {
            list(button)
        }
    })
    
    #' See coment for run_chdir_container
    #'
    outputOptions(output, 'run_paea_container', suspendWhenHidden = FALSE)

        
    #' Run Principle Angle Enrichment Analysis
    #'
    observe({
        if(is.null(input$run_paea)) { return() } else if(input$run_paea == 0) { return() }
        chdir <- isolate(values$chdir)
        casesensitive <- isolate(input$paea_casesensitive)

        if(!(is.null(chdir))) {
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
        }
    })
    
    
    #' PAEA output
    #'
    output$pae_results <- renderDataTable({
        if(!is.null(values$paea)) {
            prepare_paea_results(values$paea$p_values, data$description)
        }
    })

})
