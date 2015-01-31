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
            h3('Control samples'),
            uiOutput('sampleclass_container')
        )),
        column(12, dataTableOutput('contents'))
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
        column(12, ggvisOutput("ggvis"))
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
        column(12, dataTableOutput('pae_results'))
    )
)


#' Data analysis tab
#'
analyze_panel <- tabPanel(
    title = 'Analyze',
    tabsetPanel(
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
        'NASB Microtask Viewer',
        analyze_panel,
        about_panel
    )
)