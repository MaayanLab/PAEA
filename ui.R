library(shiny)
library(ggvis)

#' Disappearing plot help 
#' https://groups.google.com/forum/#!topic/ggvis/kQQsdn1RYaE
#'
ggvis_bug_message <- paste(
    'If you see this message but the plot is invisible please try to resize it',
    'using small grey triangle at the bottom. Unfortunately it seems to be s a known bug',
    'in ggvis/shiny so we\'ll have to wait for a fix.'
    )

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
        column(4, wellPanel(
            h3('Expression data'),
            uiOutput('datain_container'),
            actionLink('load_example_data', 'Load example expression data'),
            seperator_input
            )),
        column(4, wellPanel(
            h3('Control samples', id='control_samples'),
            uiOutput('sampleclass_container')
            )), 
        column(4, wellPanel(
            h3('Preprocessing', id='datain_preprocessing'),
            checkboxInput(inputId='log2_transform', label='log2 transform' , value = FALSE),
            checkboxInput(inputId='quantile_normalize', label='Quantile normalize', value = FALSE)
            )), 
        column(12, 
            h3('Input preview', id='datain_preview_header'),

            tabsetPanel(
                id='datain_preview',
                tabPanel(
                    'Input data',
                    p(textOutput('upload_message')),
                    dataTableOutput('contents')
                    ),
                tabPanel(
                    "Plots",
                    conditionalPanel(
                        condition = 'output.show_datain_results === true',
                        helpText(ggvis_bug_message),
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
            radioButtons(
                'input_type', 'Input type',
                c('Custom expression data'='upload', 'Disease signature'='disease'),
                ),
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

        column(4, 
            conditionalPanel(
                'input.input_type === "upload"',
                wellPanel(
                    h3('CHDIR parameters', id='chdir_parameters'),
                    sliderInput('chdir_gamma', 'Gamma', 1.0, min = 0, max = 1),
                    helpText('Gamma is the shrinkage parameter used for regularization.'),
                    numericInput('chdir_nnull', 'Nnull', 10, min = 1, max = 1000, step = 1),
                    helpText('Nnull is the number of random directions used to estimate the significance.'),
                    uiOutput('random_seed_container'),
                    checkboxInput('set_random_seed', "Set RNG seed manually", FALSE),
                    helpText(paste(
                        'Significance test is using random number generator.',
                        'If you want to obtain reproducible results you can set',
                        'seed value.'
                        )),
                    uiOutput('run_chdir_container')
                    )
                ),
            conditionalPanel(
                'input.input_type === "disease"',
                wellPanel(
                    selectizeInput(
                        'disease_sigs_choices', 'Choose disease signature', 
                        choices = NULL, options = list(placeholder = 'type disease name')
                        ),
                    actionButton('fetch_disease_sig', 'Fetch signature')
                    )
                )
            ),

column(4, wellPanel(
    h3('Downloads', id='chdir_downloads'),
    uiOutput('ngenes_tokeep_contatiner'),
    tags$dl(
        tags$dt('#{significant upregulated genes}:'),
        tags$dd(textOutput('n_sig_up_genes')),
        tags$dt('#{significant downregulated genes}:'),
        tags$dd(textOutput('n_sig_down_genes'))
        ),
    uiOutput('chdir_downloads_container')
    )),

column(12,
    h3('CHDIR results', id='chdir_results_header'),
    tabsetPanel(
        id='chdir_results',
        tabPanel('Plots',
            p(textOutput('chdir_message')),
            conditionalPanel(
                condition = 'output.show_chdir_results === true',
                helpText(ggvis_bug_message),
                ggvisOutput('chdir_ggvis_plot')
                ) 
            ),
        tabPanel(
            'Upregulated genes',
                    #TODO style with css
                    p(),
                    dataTableOutput('chdir_up_genes_table')
                    ),
        tabPanel(
            'Downregulated genes',
                    #TODO style with css
                    p(),
                    dataTableOutput('chdir_down_genes_table')
                    )
        )
    )
)
)


#' Principal Angle Enrichment Analysis ouput tab
#'
paea_tab <- tabPanel(
    'Principal Angle Enrichment Analysis',
    fluidRow(
        column(12, p('')),
        column(3, 
            wellPanel(
                id='select_gmt',
                h3('Choose gene-set libraries'),
                uiOutput('categories'), # for categories
                uiOutput('libraries') # for gmts
                )
            ),
        column(9, # for results
            h3('PAEA results'),
            tabsetPanel(
                id="paea_results",
                tabPanel('Table',
                    id='paea_table_tab',
                    conditionalPanel(
                        condition="output.show_chdir_results === true",
                        dataTableOutput('paea_table')
                        )
                    ),
                tabPanel('Bar Graph',
                    id='paea_bars_tab',
                    conditionalPanel(
                        condition="output.show_chdir_results === true",
                        ggvisOutput('paea_bars')
                        )                    
                    )

                )
            )
        )
)


#' Data analysis tab
#'
analyze_panel <- tabPanel(
    title='Analyze',
    fluidRow(column(8, 
        textInput('desc', 'Enter a brief description of your dataset (optional)')
        ),
    column(2, actionButton('remove_data', 'Clear loaded data', icon=icon('trash-o'), class='btn-primary')),
    column(2, div(textOutput('counter_value', inline=TRUE), "datasets analyzed!", id="counter_div")
        )
    ),
    tabsetPanel(
        id='workflow_panel',
        upload_tab,
        chdir_tab,
        paea_tab
        )
    )

#' Manual panel
#'
manual_panel <- tabPanel(
    title = 'Manual',
    fluidRow(column(10, 
        div(id='manual', '')
        , offset=1))
    )

#' About tab
#'
about_panel <- tabPanel(
    title = 'About',
    fluidRow(column(10,
        h4('Abstract:'),
        p('Functional analysis of genome-wide differential expression is central to biological investigations. Here we present a new multivariate approach to gene-set enrichment called Principal Angle Enrichment Analysis (PAEA). PAEA uses the geometrical concept of the principal angle to quantify gene-set enrichment. We find that PAEA outperforms a selection of commonly used gene set enrichment methods including GSEA. To benchmark PAEA with other enrichment methods we use real data. We examined the ranking of transcription factors by performing enrichment analysis on gene expression signatures from many studies that knocked-down, knocked-out or over-expressed transcription factors, and performed the enrichment analysis with a library of gene sets created from ChIP-Seq data profiling the same transcription factors. We also found that PAEA was able to rank better aging-related phenotype-terms from a collection of gene expression profiling studies where tissue from young adults was compared to tissue of elderly subjects. PAEA is implemented as a user-friendly R Shiny gene-set enrichment web application with over 70 gene set libraries available for enrichment analysis. Canned enrichment analysis for over 700 disease signatures extracted from GEO is provided with the application which is freely available at: ', a('http://amp.pharm.mssm.edu/PAEA', href='http://amp.pharm.mssm.edu/PAEA'), '.')
        , offset=1)
        ),
    fluidRow(column(10,
        tags$dl(
            tags$dt('External links:'),
            tags$dd(a('NASB Crowdsourcing portal', href='http://maayanlab.net/crowdsourcing/')),
            tags$dd(a('The development version of this app', href='https://zero323.shinyapps.io/nasb-microtask-viewer-dev/')),
            tags$dd(a('GeoDE R package', href='http://cran.r-project.org/web/packages/GeoDE/index.html')),
            tags$dd(a('Enrichr', href='http://amp.pharm.mssm.edu/Enrichr/')),
            tags$dd(a("Ma'ayan Lab", href='http://icahn.mssm.edu/research/labs/maayan-laboratory')),
            tags$dd(a("BD2K-LINCS Data Coordination and Integration Center", href='http://lincs-dcic.org/#/'))
            ) 
        , offset=1)),
    fluidRow(column(10,
        tags$dl(
            tags$dt('Contact:'),
            span("This web application is created by Zichen Wang, Maciej Szymkiewicz and Avi Ma'ayan, PhD from Icahn School of Medicine at Mount Sinai. Feel free to contact us for bug reports and suggestions."),
            tags$dd("Avi Ma'ayan, PhD:", a('avi.maayan {at} mssm.edu', href='mailto:avi.maayan@mssm.edu', target="_top")),
            tags$dd("Zichen Wang:", a('zichen.wang {at} mssm.edu', href='mailto:zichen.wang@mssm.edu', target="_top")),
            tags$dd("Maciej Szymkiewicz:", a('matthew.szymkiewicz {at} gmail.com', href='mailto:matthew.szymkiewicz@gmail.com', target="_top"))
            )
        , offset=1)),    
    fluidRow(column(10,
        tags$dl(
            tags$dt('Last update:'),
            tags$dd(textOutput('last_modified'))
            )
        , offset=1))

    )


#' Complete UI
#'
shinyUI(
    navbarPage(
        title='PAEA: Principal Angle Enrichment Analysis',
        id='navbar',
        # header=div(textOutput('counter_value', inline=TRUE), "datasets analyzed!", id="counter_div"),
        footer=column(12),
        analyze_panel,
        manual_panel,
        about_panel,
        tags$head(
            tags$link(rel='icon', type="image/png", href="favicon.png"),
            includeCSS('www/css/tourist.css'),
            tags$script(src='js/jquery-1.11.2.min.js'),
            tags$script(src='js/underscore-min.js'),
            tags$script(src='js/backbone-min.js'),
            tags$script(src='js/tourist.min.js'),
            includeScript('www/js/analyze-tour.js'),
            includeScript('www/js/ga.js'),
            includeScript('www/js/ga2.js'),
            tags$script(src='js/main.js'),
            tags$script(src='//s7.addthis.com/js/300/addthis_widget.js#pubid=ra-52026ded4b51162b', async="async"),
            includeCSS('www/css/main.css')
            ),
        collapsible=TRUE
        )
    )
