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
           
            tabsetPanel(
                tabPanel(
                    "Input data",
                    p(textOutput('upload_message')),
                    dataTableOutput('contents')
                ),
                tabPanel(
                    "Plots",
                    conditionalPanel(
                        condition = 'output.show_datain_results === true',
                        ggvisOutput('datain_density_ggvis')
                    )
                )
            )
        )
    )
)

#' Characteristic Direction Analysis ouput tab
#'
chdir_tab <- tabPanel(
    'Characteristic Direction Analysis',
    fluidRow(
        column(12, p('')), 
        column(4, wellPanel(
            h3('Input summary', id='chdir_input_summary'),
            tags$dl(
                tags$dt('#genes:'),
                tags$dd(textOutput('ngenes')),
                tags$dt('#probes:'),
                tags$dd(textOutput('nprobes')),
                tags$dt('Control samples:'),
                tags$dd(textOutput('control_samples')),
                tags$dt('Treatment samples:'),
                tags$dd(textOutput('treatment_samples'))
            )
        )),
   
        column(4, wellPanel(
            h3('CHDIR parameters', id='chdir_parameters'),
            numericInput('chdir_gamma', 'Gamma', 1.0, min = NA, max = NA, step = 1),
            numericInput('chdir_nnull', 'Nnull', 10, min = 1, max = 1000, step = 1),
            uiOutput('run_chdir_container')
        )),
        
        column(4, wellPanel(
            h3('Downloads', id='chdir_downloads'),
            tags$dl(
                tags$dt('#{significant genes}:'),
                tags$dd(textOutput('n_sig_genes'))
            ),
            uiOutput('chdir_downloads_container')
        )),
       
        column(12,
            h3('CHDIR results', id='chdir_results'),
            textOutput('chdir_message'),
            conditionalPanel(
                condition = 'output.show_chdir_results === true',
                ggvisOutput('chdir_ggvis_plot')
            ) 
        )
    )
)


#' Principle Angle Enrichment Analysis ouput tab
#'
paea_tab <- tabPanel(
    'Principle Angle Enrichment Analysis',
    fluidRow(
        column(12, p('')),
        column(6, wellPanel(
            h3('PAEA parameters', id='paea_parameters'),
            checkboxInput('paea_casesensitive', "Casesensitive", FALSE),
            uiOutput('run_paea_container')
        )),
        column(6, wellPanel(
            h3('Downloads', id='paea_downloads'),
            uiOutput('paea_downloads_container')
        )),
        column(12, h3('PAEA results'), textOutput('paea_message')),
        
        column(12, dataTableOutput('pae_results'))
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
    fluidRow(column(12,
        tags$dl(
            tags$dt('Last update:'),
            tags$dd(textOutput('last_modified'))
        )
    ))
)


#' Complete UI
#'
shinyUI(
    navbarPage(
        title='NASB Microtask Viewer',
        footer=column(12),
        analyze_panel,
        about_panel,
        includeCSS('www/css/tourist.css'),
        tags$script(src='js/underscore-min.js'),
        tags$script(src='js/backbone-min.js'),
        includeScript('www/js/tourist.min.js'),
        includeScript('www/js/analyze-tour.js')
    )
)