var stateTimer;
var templates = {};
var jsonSource = 'json.pl';

$(document).ready(function() {
	templates.queueSong = $("li.queue-song").clone();
	alert(templates.queueSong.html());

	playerStateRequest();
//	if (stateTimer) clearInterval(stateTimer);
//	stateTimer = setInterval(function() {playerStateRequest();}, 15000)
});

function playerStateRequest() {
	$.getJSON(
		jsonSource,
		function (json) {handlePlayerStateRequest(json);}
	);
}

function handlePlayerStateRequest(json) {
	$("#queue-list").html("");
	for (var i in json.playlist) {
		//alert(i);
		var song = json.playlist[i];
		var entry = $(templates.queueSong).clone();
		$(".queue-song-title", entry).html(song.title);
		//alert(entry.html());
		entry.appendTo("#queue-list");
		//alert(entry);
	}
}
