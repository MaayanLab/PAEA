library(shiny)
library(dplyr)
library(nasbMicrotaskViewerHelpers)

data <- nasbMicrotaskViewerHelpers::preprocess()

shinyServer(function(input, output, session) {
    
    counts <- data$genes %>% group_by(gene) %>% summarise(n=n())
    output$distPlot <- renderPlot({
        bins <- seq(min(counts$n), max(counts$n), length.out = input$bins + 1)
        
        hist(
            counts$n,
            breaks = bins, col = 'darkgray', border = 'white'
        )
    })
})
