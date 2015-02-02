library(shiny)
library(ggvis)
library(data.table)
library(dplyr)
library(nasbMicrotaskViewerHelpers)

source('downloads_handlers.R', local=TRUE)

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
        if (!is.null(datain()) && ncol(datain()) != 1 ) {
            checkboxGroupInput(
                'sampleclass',
                'Choose control samples',
                colnames(datain())[-1]
            )
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
        if(input$run_chdir == 0) return()
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
    
    
    #' Plot top genes from Characteristic Direction Analysis
    #'
    observe({
        if(!is.null(values$chdir)) {
            results <- prepare_results(values$chdir$results[[1]])
            plot_top_genes(results) %>% bind_shiny("ggvis")
        }
    })
    

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

        
    #' Run Principle Angle Enrichment Analysis
    #'
    observe({
        if(input$run_paea == 0) return()
        chdir <- isolate(values$chdir)
        if(!(is.null(chdir))) {
            values$paea <- tryCatch(
                paea_analysis_wrapper(chdir$chdirprops, prepare_gene_sets(data$genes)),
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
