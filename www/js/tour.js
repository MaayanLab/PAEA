function initTour() {
    
    var steps = [{
        content: '',
        highlightTarget: true,
        nextButton: true,
        target: $('#'),
        my: 'bottom center',
        at: 'top center'
    }, {
        content: '',
        highlightTarget: true,
        nextButton: true,
        target: $('#'),
        my: 'bottom center',
    at: 'top center'
    }]

    var tour = new Tourist.Tour({
        steps: steps,
        tipClass: 'Bootstrap',
        tipOptions:{ showEffect: 'slidein' }
    });
    tour.start();
}