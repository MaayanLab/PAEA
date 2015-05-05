// to load manual html into the tab
$(document).ready(function() { 
	$("#manual").load("html/manual.html")

	$("#remove_data").click(function(){
		var currentUrl = window.location.href;
		var baseUrl = currentUrl.split('?')[0];
		window.location.href = baseUrl;
	})

});
