var stateTimer;
var templates = {};
var jsonSource = 'json.pl';

$(document).ready(function() {
	$("#queue-list").sortable({
		placeholder: "queue-song-placeholder",
		axis: "y",
		handle: ".queue-song-handle"
	});
	templates.queueSong = $("li.queue-song").first().clone();
	templates.nowPlayingPanel = $("#now-playing-panel").clone();
	playerStateRequest();
	handlePlayerStateRequest({playlist:[
		{
			title: "bacon is delicious",
			artist: "the redditors"
		},
		{
			title: "bacon is deliciousasdf",
			artist: "the redditors"
		},
		{
			title: "lol",
			artist: "this is fun"
		}
		]});
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
	// now playing
	var nowPlaying = json.now_playing;
	var nowPlayingPanel = templates.nowPlayingPanel.clone();
	$("#now-playing-panel").empty();
	if (nowPlaying) {
		$("#now-playing-title", nowPlayingPanel).html(nowPlaying.title);
		$("#now-playing-album", nowPlayingPanel).html(nowPlaying.album);
		$("#now-playing-artist", nowPlayingPanel).html(nowPlaying.artist);
		$("#now-playing-total", nowPlayingPanel).html(nowPlaying.length);
		var elapsedTime = Math.round(((new Date().getTime())/1000)) - json.player.song_start;
		$("#now-playing-time", nowPlayingPanel).html(elapsedTime);
		$("#nothing-playing-info", nowPlayingPanel).remove();
		nowPlayingPanel.appendTo("#now-playing-panel");
	} else {
		$("#now-playing-album-art", nowPlayingPanel).remove();
		$("#now-playing-info", nowPlayingPanel).remove();
		nowPlayingPanel.appendTo("#now-playing-panel");
	}

	// the queue
	$("#queue-list").empty();
	for (var i in json.playlist) {
		var song = json.playlist[i];
		var entry = templates.queueSong.clone();
		$(".queue-song-title", entry).html(song.title);
		$(".queue-song-artist", entry).html(song.artist);
		entry.appendTo("#queue-list");
	}
}
