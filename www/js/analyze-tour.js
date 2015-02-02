// See: https://gist.github.com/xiaodaigh/6445698
// TODO Change to more selective solution
var swichTab = function(i) {
    tabs = $('.tabbable .nav.nav-tabs li');
    tabs.each(function() {
        $(this).removeClass('active')
    });
    $(tabs[i]).addClass('active');
    tabsContents = $('.tabbable .tab-content .tab-pane')
    tabsContents.each(function() {
        $(this).removeClass('active')
    });
    $(tabsContents[i]).addClass('active');
}

function initTour() {
    
    var steps = [{
            content: '<p>Welcome...</p>',
            target: [50, 120],
            nextButton: true,
            my: 'bottom left'
    }, {
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
        at: 'top center',
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
        at: 'bottom center',
        teardown: function(tour, options) {
            swichTab(1);
        }
    }, {
        content: [
            '<p>Check parameters and chdir</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#run_chdir'),
        my: 'bottom center',
        at: 'bottom center'
    }, {
        content: [
            '<p>When chdir analysis is finished',
            'you can download the results...</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#chdir_results'),
        my: 'bottom center',
        at: 'bottom center'
    }, {
        content: [
            '<p>... and start PAE analysis</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#workflow_panel'),
        my: 'bottom center',
        at: 'bottom center',
        teardown: function(tour, options) {
            swichTab(2);
        }
    }, {
        content: [
            '<p>To run PAEA click Run Principle Angle Enrichment</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#run_paea'),
        my: 'bottom center',
        at: 'bottom center'
    }, {
        content: [
            '<p>When PAEA is ready results will be shown below</p>'
        ].join(''),
        highlightTarget: true,
        nextButton: true,
        closeButton: true,
        target: $('#pae_results'),
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