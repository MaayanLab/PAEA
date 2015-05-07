$(document).ready(function() {
	$("#desc").parent().removeClass("shiny-input-container")

	$("#manual").load("html/manual.html")

	$("#remove_data").click(function(){
		var currentUrl = window.location.href;
		var baseUrl = currentUrl.split('?')[0];
		window.location.href = baseUrl;
	})

});
