var volume;
var stateTimer;
var templates = {};
var jsonSource = 'json.pl';
var playingTimer;
var elapsedTime = 0;
var totalTime = 0;

$(document).ready(function() {
	$("#queue-list").sortable({
		placeholder: "queue-song-placeholder",
		axis: "y",
		handle: ".queue-song-handle"
	});

	// templating
	templates.queueSong = $("li.queue-song").first().clone();
	templates.nowPlayingPanel = $("#now-playing-panel").clone();

	playerStateRequest();
	if (stateTimer) clearInterval(stateTimer);
	stateTimer = setInterval(function() {playerStateRequest();}, 15000)
});

function readableTime(length) {
	if (length < 0) {length = 0;}
	var seconds = length % 60;
	var minutes = Math.floor(length / 60) % 60;
	var hours = Math.floor(length / 3600);
	if (hours) {
		return sprintf("%d:%02d:%02d",hours,minutes,seconds);
	} else {
		return sprintf("%d:%02d",minutes,seconds);
	}
}

function startPlayingTimer() {
	if (playingTimer) clearInterval(playingTimer);
	playingTimer = setInterval(function() { updatePlayingTime() }, 1000);
}

function updatePlayingTime() {
	if(elapsedTime < totalTime) {
		$('#now-playing-time').html(readableTime(++elapsedTime));
	}
}

function playerStateRequest() {
	$.getJSON(
		jsonSource,
		function (json) {handlePlayerStateRequest(json);}
	);
}

function handlePlayerStateRequest(json) {
	// volume
	if (json.player && json.player.volume != undefined) {
		volume = parseInt(json.player.volume);
		$("#controls-volume").html((volume / 10) + 1);
	} else {
		$("#controls-volume").html("-");
	}

	// now playing
	var nowPlaying = json.now_playing;
	var nowPlayingPanel = templates.nowPlayingPanel.clone();
	$("#now-playing-panel").empty();
	if (nowPlaying) {
		$("#now-playing-title", nowPlayingPanel).html(nowPlaying.title);
		$("#now-playing-album", nowPlayingPanel).html(nowPlaying.album);
		$("#now-playing-artist", nowPlayingPanel).html(nowPlaying.artist);
		$("#now-playing-total", nowPlayingPanel).html(readableTime(nowPlaying.length));
		totalTime = nowPlaying.length;
		startPlayingTimer();
		elapsedTime = Math.round(((new Date().getTime())/1000)) - json.player.song_start;
		$("#now-playing-time", nowPlayingPanel).html(readableTime(elapsedTime));
		$("#nothing-playing-info", nowPlayingPanel).remove();
		$("#now-playing-panel").replaceWith(nowPlayingPanel);
	} else {
		$("#now-playing-album-art", nowPlayingPanel).remove();
		$("#now-playing-info", nowPlayingPanel).remove();
		$("#now-playing-panel").replaceWith(nowPlayingPanel);
	}
	$("#now-playing-album-art-img").reflect({height: 16});

	// the queue
	$("#queue-list").empty();
	var total_length = 0;
	for (var i in json.playlist) {
		var song = json.playlist[i];
		var entry = templates.queueSong.clone();
		$(".queue-song-title", entry).html(song.title);
		$(".queue-song-artist", entry).html(song.artist);
		var minutes = '' + Math.floor(song.length / 60);
		var seconds = '' + song.length % 60;
		while (seconds.length < 2) {
			seconds = "0" + seconds;
		}
		$(".queue-song-time", entry).html(minutes + ":" + seconds);
		total_length += song.length;
		entry.appendTo("#queue-list");
	}
	var length = $("#queue-list").contents().length;
	$("#queue-song-count-num").html(length);
	if (length == 1) {
		$("#queue-song-count-plural").html("");
	} else {
		$("#queue-song-count-plural").html("s");
	}
	var days    = Math.floor(total_length / 86400);
	var hours   = Math.floor(total_length / 3600);
	var minutes = Math.floor(total_length / 60);
	var seconds = '' + total_length % 60;
	if (days > 1) {
		$("#queue-length").html(days + " days, " + hours + " hours, " + minutes + " minutes, " + seconds + " seconds.");
	} else if (days == 1) {
		$("#queue-length").html(days + " day, " + hours + " hours, " + minutes + " minutes, " + seconds + " seconds.");
	} else if (hours > 1) {
		$("#queue-length").html(hours + " hours, " + minutes + " minutes, " + seconds + " seconds.");
	} else if (hours == 1) {
		$("#queue-length").html(hours + " hour, " + minutes + " minutes, " + seconds + " seconds.");
	} else if (minutes > 1) {
		$("#queue-length").html(minutes + " minutes, " + seconds + " seconds.");
	} else if (minutes == 1) {
		$("#queue-length").html(minutes + " minute, " + seconds + " seconds.");
	} else {
		$("#queue-length").html(seconds + " seconds.");
	}
}

function controlPlayPause() {
	$.getJSON(
			jsonSource + '?mode=start',
		function (data) {handlePlayerStateRequest(data);}
	);
}

function controlStop() {
	$.getJSON(
		jsonSource + '?mode=stop',
		function (data) {handlePlayerStateRequest(data);}
	);
}

function controlNext() {
	$.getJSON(
		jsonSource + '?mode=skip',
		function (data) {handlePlayerStateRequest(data);}
	);
}

function controlVolumeDown() {
	if (volume != undefined) {
		volume -= 10;
		$.getJSON(
			jsonSource + '?mode=volume;value=' + volume,
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function controlVolumeUp() {
	if (volume != undefined) {
		volume += 10;
		$.getJSON(
			jsonSource + '?mode=volume;value=' + volume,
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}
