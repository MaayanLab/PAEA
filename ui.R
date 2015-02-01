library(shiny)
library(ggvis)

#' Input separator choice
#'
seperator_input <- radioButtons(
    'sep', 'Separator',
    c(Comma=',', Semicolon=';', Tab='\t'),
)

#' Dataset download 
#'
upload_tab <- tabPanel(
    'Upload dataset',
    fluidRow(
        column(12, p('')),
        column(6, wellPanel(
            h3('Expression data'),
            uiOutput('datain_container'),
            seperator_input        
        )),
        column(6, wellPanel(
            h3('Control samples', id='control_samples'),
            uiOutput('sampleclass_container')
        )),
        column(12, 
            h3('Input preview', id='datain_preview'),
            dataTableOutput('contents')
        )
    )
)

#' Characteristic Direction Analysis ouput tab
#'
chdir_tab <- tabPanel(
    'Characteristic Direction Analysis',
    fluidRow(
        column(12, p('')),
        column(12, wellPanel(
            tags$dl(
                tags$dt('#genes:'),
                tags$dd(textOutput('ngenes')),
                tags$dt('#probes:'),
                tags$dd(textOutput('nprobes')),
                tags$dt('Control samples:'),
                tags$dd(textOutput('control_samples')),
                tags$dt('Treatment samples:'),
                tags$dd(textOutput('treatment_samples'))
            ),
            actionButton(inputId = 'run_chdir', label = 'Run Characteristic Direction Analysis', icon = NULL)
        )),
        column(6, ggvisOutput("ggvis")),
        column(6, wellPanel())
    )
)


#' Principle Angle Enrichment Analysis ouput tab
#'
paea_tab <- tabPanel(
    'Principle Angle Enrichment Analysis',
    fluidRow(
        column(12, p('')),
        column(12, wellPanel(
            actionButton(inputId = 'run_paea', label = 'Run Principle Angle Enrichment', icon = NULL)
        )),
        column(6, dataTableOutput('pae_results')),
        column(6)
    )
)


#' Data analysis tab
#'
analyze_panel <- tabPanel(
    title='Analyze',
    tabsetPanel(
        id='workflow_panel',
        upload_tab,
        chdir_tab,
        paea_tab
    )
)

#' About tab
#'
about_panel <- tabPanel(
    title = 'About',
    fluidRow(column(12))
)


#' Complete UI
#'
shinyUI(
    navbarPage(
        title='NASB Microtask Viewer',
        analyze_panel,
        about_panel,
        includeCSS('www/css/tourist.css'),
        tags$script(src='js/underscore-min.js'),
        tags$script(src='js/backbone-min.js'),
        includeScript('www/js/tourist.js'),
        includeScript('www/js/tour.js')
    )
)