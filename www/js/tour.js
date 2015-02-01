function initTour() {
    
    var steps = [{
        content: [
            '<p>Choose expression dataset to upload.</p>',
            '<p>It should contain a sinlge column with gene names ',
            'followed by the  expression profiles.</p>',
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#datain'),
        my: 'bottom center',
        at: 'top center'
    }, {
        content: [
            '<p>Select input file separator</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#sep'),
        my: 'bottom center',
        at: 'top center'
    }, {
        content: [
            '<p>Check if file has been loaded as expected.</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#datain_preview'),
        my: 'bottom center',
        at: 'top center'
    }, {
        content: [
            '<p>Choose control samples</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#control_samples'),
        my: 'bottom center',
        at: 'top center'
    }, {
        content: [
            '<p>Switch to the Characteristic Direction Analysis</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#workflow_panel'),
        my: 'bottom center',
        at: 'bottom center'
    }];

    var tour = new Tourist.Tour({
        steps: steps,
        tipClass: 'Bootstrap',
        tipOptions:{ showEffect: 'slidein' }
    });
    tour.start();
}

$(document).ready(function() {
    window.setTimeout(initTour, 1000);
})