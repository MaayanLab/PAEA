library(shiny)
library(ggvis)
library(data.table)
library(dplyr)

options(shiny.maxRequestSize=120*1024^2) 

library(nasbMicrotaskViewerHelpers)

data <- nasbMicrotaskViewerHelpers::preprocess('http://localhost/microtask.1.24.2015.csv')

shinyServer(function(input, output, session) {
    
    values <- reactiveValues()
    # Not required. Just to remind myself what is stored inside
    values$chdir <- NULL
    values$control_samples <- NULL
    values$treatment_samples <- NULL
    
    
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
    
 
    #' Handle 
    #'
    observe({
        if(input$run_chdir == 0) return()
        datain <- isolate(datain())
        sampleclass <- factor(ifelse(colnames(datain)[-1] %in% isolate(input$sampleclass), '1', '2'))
        values$chdir <- try(
            GeoDE::chdirAnalysis(datain, sampleclass = sampleclass)
        )
    })
    
    
    output$nprobes <- renderText({
        if(!is.null(datain())) {
            nrow(datain())
        }
    })
    
    output$ngenes <- renderText({
        if(!is.null(datain())) {
            nlevels(datain()[[1]])
        }
    })
    
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

    output$control_samples <- renderText({
        paste(values$control_samples, collapse = ', ')
    })
    
    output$treatment_samples <- renderText({
        paste(values$treatment_samples, collapse = ', ')
    })
    
    output$contents <- renderDataTable({
        datain()
    })
    
    output$sampleclass_container <- renderUI({
        if (!is.null(datain()) && ncol(datain()) != 1 ) {
            checkboxGroupInput(
                'sampleclass',
                'Choose control samples',
                colnames(datain())[-1]
            )
        } 
    })
    
    datain <- reactive({
        inFile <- input$datain
        values$chdir <- NULL
        
        if (is.null(inFile)) return(NULL)
        # Not optimal but read.csv is easier to handle
        as.data.table(read.csv(
            inFile$datapath, sep = input$sep
        ))
    })
})
