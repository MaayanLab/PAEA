$(document).ready(function() {
	// make the #desc input longer
	$("#desc").parent().removeClass("shiny-input-container")
	// load the manual
	$("#manual").load("html/manual.html")
	// disable the button if no data is loaded
	Shiny.addCustomMessageHandler('remove_data', function(message){
		if (message === true) {
			$("#remove_data").prop("disabled", false)
		} else{
			$("#remove_data").prop("disabled", true)
		};
	})
	// refresh the page when button clicked
	$("#remove_data").click(function(){
		var currentUrl = window.location.href;
		var baseUrl = currentUrl.split('?')[0].split('#')[0];
		window.location.href = baseUrl;
	})

});
