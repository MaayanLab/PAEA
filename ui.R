library(shiny)

shinyUI(fluidPage(

  titlePanel(''),

  sidebarLayout(
    sidebarPanel(
      sliderInput('bins',
                  'Number of bins:',
                  min = 1,
                  max = 50,
                  value = 30)
    ),

    mainPanel(
      plotOutput('distPlot')
    )
  )
))
