var currentUser = '';
var volume;
var stateTimer;
var templates = {};
var jsonSource = 'json.pl';
var artSource = 'json.pl?mode=art';
var playingTimer;
var elapsedTime = 0;
var totalTime = 0;
var queueLocked = false;
var queueHidden = false;
var queueShouldBeHidden = false;
var nowPlaying = {}
var fsControlsHidden = true;

$(document).ready(function() {
	unfullscreen();
	clearFullscreen();
	$("#fullscreen-controls").hover(function() {
		if (fsControlsHidden) {
			fsControlsHidden = false;
			$(this).animate({bottom: 0, opacity: 1.0}, 'fast');
		}
	}, function() {
		if (!fsControlsHidden) {
			fsControlsHidden = true;
			$(this).animate({bottom: -50, opacity: 0.1}, 'fast');
		}
	});


	$("#queue-list").sortable({
		placeholder: "queue-song-placeholder",
		axis: "y",
		start: function() { queueLocked = true; },
		stop: function() { queueLocked = false; },
		update: updateQueueOrder
	});

	// templating
	templates.queueSong = $("li.queue-song").first().clone();
	templates.nowPlayingInfo = $("#now-playing-info").clone();
	templates.nowPlayingPanel = $("#now-playing-panel").clone();
	templates.nowPlayingAlbumArt = $("#now-playing-album-art-img").clone();
	templates.searchResultSong = $("#search-results-entry").clone();
	templates.advancedSearchEntry = $("#advanced-search-NUM").clone();
	templates.albumResult = $(".album-icon").clone();
	$("#advanced-search-NUM").remove();
	$("#search-results-table tbody").empty();
	$(".album-icon").remove();

	playerStateRequest();
	if (stateTimer) clearInterval(stateTimer);
	stateTimer = setInterval(function() {playerStateRequest();}, 15000)
	$("#search-results-table").tablesorter({widgets: ['zebra']});
	$(".header-bar-menu-root").hover(function() {
		$("#"+$(this).attr('id')+"-dropdown").show();
	});
	$('.header-bar-menu-dropdown').hover(function() {
	}, function() {
		$(this).hide();
	});
	$("#toggle-right-panel").click(function() { toggleQueueExplicit(); });
	insertAdvancedSearch(1);
	insertAdvancedSearch(2);
	document.addEventListener('touchmove', function(e){ e.preventDefault(); });

	/* XXX REMOVE THIS IN FINAL RELEASE XXX */
	/* If they haven't seen it, present users with the
	 * "Welcome to Acoustics Beta" dialog, which appears
	 * in a warning box. */

	function setCookie(name, value, expires) {
		var exdate = new Date();
		exdate.setDate(exdate.getDate() + expires);
		var value = escape(value) + ((expires == null) ? "" : "; expires=" + exdate.toUTCString());
		document.cookie = name + "=" + value;
	}
	function getCookie(name) {
		var i, x, y, cookies = document.cookie.split(";");
		for (i = 0; i < cookies.length; i++) {
			x = cookies[i].substr(0, cookies[i].indexOf("="));
			y = cookies[i].substr(cookies[i].indexOf("=")+1);
			x = x.replace(/^\s+|\s+$/g,"");
			if (x == name) {
				return unescape(y);
			}
		}
		return null;
	}

	if (getCookie("_seen_beta") != "yes") {
		showMessage("Wecome to Acoustics Beta!",
			"You are using the Beta release of Acoustics 2.0, "+
			"a massive new release featuring a brand new interface. "+
			"This release is not finished, and as such may have bugs "+
			"or general usability issues or missing features.<br /><br />"+
			"Thank you for taking the time to test the Beta.");
		setCookie("_seen_beta","yes",10000);
	}


	/* XXX REMOVE THE ABOVE IN FINAL RELEASE XXX */

});


function insertAdvancedSearch(id) {
	var entry = templates.advancedSearchEntry.clone();
	if (id == 1) {
		$("#adv-search-and-NUM",entry).remove();
		$("#adv-search-or-NUM",entry).remove();
		$("#adv-label-and-NUM",entry).remove();
		$("#adv-label-or-NUM",entry).remove();
	} else {
		$("#adv-search-if-NUM",entry).remove();
		$("#adv-label-if-NUM",entry).remove();
	}
	$("label",entry).addClass("expanded");
	entry.attr("id",entry.attr("id").replace("-NUM","-"+id));
	entry.html(entry.html().replace(/-NUM/g,"-"+id));
	// Do stuff here
	$("#advanced-search-submit").before(entry);
}

function toggleQueueExplicit() {
	toggleQueue();
	queueShouldBeHidden = queueHidden;
}

function showQueue() {
	$("#right-panel").animate({
		right: '0'
	}, 400);
	$(".panel-left").animate({
		right: '300'
	}, 400);
	$("#toggle-right-panel").animate({
		right: '300'
	}, 400);
	queueHidden = false;
}

function hideQueue() {
	$("#right-panel").animate({
		right: '-300'
	}, 400);
	$(".panel-left").animate({
		right: '0'
	}, 400);
	$("#toggle-right-panel").animate({
		right: '0'
	}, 400);
	queueHidden = true;
}

function toggleQueue() {
	if (queueHidden) {
		showQueue();
	} else {
		hideQueue();
	}
}

function restoreQueue() {
	if (queueShouldBeHidden) {
		hideQueue();
	} else {
		showQueue();
	}
}

function showPlaylist() {
	showQueue();
	$("#playlist-panel").animate({
		right: '0'
	}, 300);
}

function hidePlaylist() {
	$("#playlist-panel").animate({
		right: '-500'
	}, 400);
}


function titleOrPath(json) {
	if (json.title) {
		return json.title;
	} else {
		var shortname = /^.*\/(.*)$/.exec(json.path);
		if (shortname) {
			return shortname[1];
		} else {
			return json.path;
		}
	}
}

function readableTime(length) {
	length = Math.max(length,0);
	var seconds = Math.floor(length % 60), minutes = Math.floor(length / 60) % 60, hours = Math.floor(length / 3600);
	seconds = (seconds < 10 ? "0" : "") + seconds;
	minutes = (minutes < 10 ? "0" : "") + minutes;
	length = minutes + ":" + seconds;
	if (hours) {
		length = hours + ":" + length;
	}
	return length;
}

function startPlayingTimer() {
	if (playingTimer) clearInterval(playingTimer);
	playingTimer = setInterval(function() { updatePlayingTime() }, 1000);
}

function updatePlayingTime() {
	if (elapsedTime < totalTime) {
		$('#now-playing-time').html(readableTime(++elapsedTime));
		$('#now-playing-progress').progressbar({value: Math.floor(100 * (elapsedTime/totalTime))});
	} else if (elapsedTime >= totalTime) {
		playerStateRequest();
	}
}

function playerStateRequest() {
	$.getJSON(
		jsonSource + '?mode=status',
		function (json) {handlePlayerStateRequest(json);}
	);
}

function doStats(who) {
	$("#statistics-status").html("Getting statistics...");
	$.getJSON(jsonSource + "?mode=stats;who=" + who,
		function (json) {
			$("#statistics-status").html("Thank you for using Acoustics, the Social Music Player!");
			$("#statistics-song-count").html(json.total_songs);
			$("#statistics-top-artist").html(json.top_artists[0].artist);
		}
	);
}

function doSearch(field, value) {
	$("#search-results-status").html("Searching for '" + value + "'...");
	$.getJSON(jsonSource + "?mode=search;field=" + field + ";value=" + value,
		function (data) {
			$("#search-results-status").html("Processing " + data.length + " results.");
			if (data.length > 1000) {
				if (!confirm("Your search returned a lot of results (" + data.length +"). Do you still want to continue?")) {
					return false;
				}
			}
			fillResultTable(data);
			$("#search-results-status").html("Search results for '" + value + "'.");
	});
	return false;
}

function selectRequest(field, value) {
	$("#search-results-status").html("Searching for '" + value + "'...");
	$.getJSON(jsonSource + "?mode=select;field=" + field + ";value=" + value,
		function (data) {
			$("#search-results-status").html("Processing " + data.length + " results.");
			fillResultTable(data);
			$("#search-results-status").html("Songs where " + field + " is '"
				+ value + "'.");
	});
}

function loadRandomSongs(amount, seed) {
	$.getJSON(
		jsonSource + "?mode=random;amount=" + amount + ";seed=" + seed,
		function (data) {
			$('#search-results-random a').attr('href',
				'#RandomSongs/20/' + (Math.floor(Math.random()*1e9)));
			fillResultTable(data);
			$("#search-results-status").html(amount + " Random Songs");
		}
	);
}

function loadRecentSongs(amount) {
	$.getJSON(
		jsonSource + '?mode=recent;amount=' + amount,
		function (data) {
			fillResultTable(data);
			$("#search-results-status").html(amount + " Recently Added Songs");
		}
	);
}

function loadPlayHistory(amount, who) {
	$.getJSON(
		jsonSource + '?mode=history;amount=' + amount + ";who=" + who,
		function (data) {
			fillResultTable(data);
			var bywho = "";
			if (who) bywho = " By " + who;
			$("#search-results-status").html(amount + " Recently Played Songs"
				+ bywho);
		}
	);
}

function hideShow(what) {
	$("#"+what).toggle();
}

function hideShowSlide(what) {
	$("#"+what).slideToggle(300);
}

function fillResultTable(json) {
	$("#search-results-table tbody tr").remove();
	$("#search-results-table").trigger("update");
	if (json.length < 1) {
		$("#search-results-table tbody").append("<tr><td colspan=\"6\"><center><i>No results.</i></center></td></tr>");
		$("#search-results-time").html("0 seconds");
		$("#search-results-count").html("0 songs");
		return false;
	}
	var total_length = 0;
	$("#search-results-table tbody").empty();
	for (i in json) {
		var song = json[i];
		var entry = templates.searchResultSong.clone();
		$(".search-results-entry-song-id", entry).html(song.song_id);
		$(".search-results-entry-track", entry).html(song.track);
		$(".search-results-entry-length", entry).html(readableTime(song.length));

		$(".search-results-entry-vote", entry).attr('href',
			'javascript:voteSong(' + song.song_id + ')');

		$(".search-results-entry-title a", entry).html("<img class='mini-album-art' src='" + getAlbumArtUrl(song.artist,song.album,song.title,16) + "' width=16 />" + song.title);
		$(".search-results-entry-title a", entry).attr('href',
			'#SongDetails/' + song.song_id);

		$(".search-results-entry-album a", entry).html(song.album);
		$(".search-results-entry-album a", entry).attr('href',
			'#SelectRequest/album/' + uriencode(song.album));

		$(".search-results-entry-artist a", entry).html(song.artist);
		$(".search-results-entry-artist a", entry).attr('href',
			'#SelectRequest/artist/' + uriencode(song.artist));
		$("#search-results-table tbody").append(entry);

		total_length += parseInt(song.length);
	}
	$("#search-results-table").trigger("update");
	$("#search-results-table").trigger("applyWidgets");
	$("#search-results-time").html(readableTime(total_length));
	if (json.length == 1) {
		$("#search-results-count").html("One song");
	} else {
		$("#search-results-count").html(json.length +" songs");
	}
	/* iOS scroll fix */
	new iScroll('search-results-table');
}

function updateQueueOrder(event, ui) {
	$("#search-results-status").html("The queue was reordered.");
	var block = "";
	$("#queue-list .queue-song").each(function(index) {
		block += "song_id=" + $(".queue-song-id",this).text() + ";";
	});
	$.getJSON(
		jsonSource + '?mode=reorder_queue;' + block,
		function (data) {handlePlayerStateRequest(data);}
	);
}

function voteSong(song_id) {
	$.getJSON(
		jsonSource + '?mode=vote;song_id=' + song_id,
		function (data) {handlePlayerStateRequest(data);}
	);
}

function unvoteSong(song_id) {
	$.getJSON(
		jsonSource + '?mode=unvote;song_id=' + song_id,
		function (data) {handlePlayerStateRequest(data);}
	);
}

function changePlayer(player_id) {
	$.getJSON(
		jsonSource + "?mode=change_player;player_id="+player_id,
		function(data) { handlePlayerStateRequest(data);}
	);
}

function voteAll() {
	var block = "";
	$("#search-results-table tbody tr").each(function(index) {
		block += "song_id=" + $(".search-results-entry-song-id",this).text() + ";";
	});
	var command = "?mode=vote;";
	$.getJSON(
			jsonSource + command + block,
			function(data){handlePlayerStateRequest(data);}
	);
}

function voteOne() {
	var block = "";
	var length = $("#search-results-table tbody tr").length;
	var randomSelection = Math.floor(Math.random() * length);
	// FIXME: I have no idea what I'm doing here.
	//        Can I index these guys?
	$("#search-results-table tbody tr").each(function(index) {
		if (index == randomSelection) {
			block += "song_id=" + $(".search-results-entry-song-id",this).text() + ";";
		}
	});
	var command = "?mode=vote;";
	$.getJSON(
			jsonSource + command + block,
			function(data){handlePlayerStateRequest(data);}
	);
}

function clearQueue() {
	block = "";
	$("#queue-list .queue-song").each(function(index) {
		block += "song_id=" + $(".queue-song-id",this).text() + ";";
	});
	var command = "?mode=unvote;";
	$.getJSON(
			jsonSource + command + block,
			function(data){handlePlayerStateRequest(data);}
	);
}

function handlePlayerStateRequest(json) {
	// volume
	if (json.player && json.player.volume != undefined) {
		volume = parseInt(json.player.volume);
		$(".disp-volume").html((volume / 10) + 1);
	} else {
		$(".disp-volume").html("-");
	}

	// user
	if (json.who) {
		$("#header-bar-user-message").html("logged in as");
		$("#user-name").html(json.who);
		currentUser = json.who;
	}

	// players
	if (json.players.length > 1) {
		$("#header-bar-menu-players-dropdown li").remove();
		$("#header-bar-menu-players-dropdown").append("<li><a href='#'>Players</a></li>");
		for (i in json.players) {
			if (json.players[i] == json.selected_player) {
				$("#header-bar-menu-players-dropdown").append("<li><b><a href=\"javascript:changePlayer('" + json.players[i] + "');\">" + json.players[i] + "</a></b></li>\n");
			} else {
				$("#header-bar-menu-players-dropdown").append("<li><a href=\"javascript:changePlayer('" + json.players[i] + "');\">" + json.players[i] + "</a></li>\n");

			}
		}
	} else {
		$("#header-bar-menu-players").hide();
	}

	// now playing
	nowPlaying = json.now_playing;
	if (nowPlaying) {
		var nowPlayingPanel = templates.nowPlayingInfo.clone();
		$("#now-playing-album-art").show();
		$("#now-playing-info").show();
		$("#nothing-playing-info").hide();
		$("#now-playing-title a", nowPlayingPanel).html(nowPlaying.title);
		$("#now-playing-title a", nowPlayingPanel).attr('href',
			'#SongDetails/' + nowPlaying.song_id);
		$("#now-playing-title a", nowPlayingPanel).attr('title',
			nowPlaying.title);
		$("#now-playing-artist a", nowPlayingPanel).html(nowPlaying.artist);
		$("#now-playing-artist a", nowPlayingPanel).attr('href',
			'#SelectRequest/artist/' + uriencode(nowPlaying.artist));
		$("#now-playing-artist a", nowPlayingPanel).attr('title',
			nowPlaying.artist);
		$("#now-playing-album a", nowPlayingPanel).html(nowPlaying.album);
		$("#now-playing-album a", nowPlayingPanel).attr('href',
			'#SelectRequest/album/' + uriencode(nowPlaying.album));
		$("#now-playing-album a", nowPlayingPanel).attr('title',
			nowPlaying.album);
		$("#now-playing-total", nowPlayingPanel).html(readableTime(nowPlaying.length));
		totalTime = nowPlaying.length;
		startPlayingTimer();
		elapsedTime = nowPlaying.now - json.player.song_start;
		// kludge to prevent time from going too high
		if (elapsedTime <= totalTime) {
			$("#now-playing-time", nowPlayingPanel).html(readableTime(elapsedTime));
		} else {
			$("#now-playing-time", nowPlayingPanel).html(readableTime(totalTime));
		}
		$("#nothing-playing-info", nowPlayingPanel).remove();
		$("#now-playing-info").replaceWith(nowPlayingPanel);
		$("#now-playing-album-art").empty();
		$("#now-playing-album-art").append("<a href='javascript:fixArt(\"" + jsencode(nowPlaying.artist) + "\",\"" +
				jsencode(nowPlaying.album) + "\",\"" + jsencode(nowPlaying.title) + "\")'>" + 
				"<img id='now-playing-album-art-img' src='" + getAlbumArtUrl(nowPlaying.artist,nowPlaying.album,nowPlaying.title,64) + "' width='64'/></a>");
		$("#now-playing-album-art-img").reflect({height: 16});
		$("#now-playing-progress").progressbar({value: Math.floor(100 * (elapsedTime/totalTime))});
		/* Full screen view */
		$("#fullscreen-title").html(nowPlaying.title);
		$("#fullscreen-artist").html(nowPlaying.artist);
		$("#fullscreen-album").html(nowPlaying.album);
		$("#fullscreen-album-art").empty();
		$("#fullscreen-album-art").append("<a href='javascript:fixArt(\"" + jsencode(nowPlaying.artist) + "\",\"" +
				jsencode(nowPlaying.album) + "\",\"" + jsencode(nowPlaying.title) + "\")'>" + 
				"<img id='fullscreen-album-art-img' src='" + getAlbumArtUrl(nowPlaying.artist,nowPlaying.album,nowPlaying.title,300) + "' width='300'/></a>");
		if (!$.browser.webkit) {
			$("#fullscreen-album-art-img").reflect({height: 100});
		}
		/* And here's the fun part */
		jQuery.favicon(getAlbumArtUrl(nowPlaying.artist,nowPlaying.album,nowPlaying.title,20));
		/* Title Bar */
		document.title = nowPlaying.title + " - " + nowPlaying.artist + " [Acoustics]";
	} else {
		var nowPlayingPanel = templates.nowPlayingPanel.clone();
		$("#now-playing-album-art", nowPlayingPanel).hide();
		$("#now-playing-info", nowPlayingPanel).hide();
		$("#now-playing-panel").replaceWith(nowPlayingPanel);
		$("#nothing-playing-info").show();
		clearFullscreen();
		jQuery.favicon("www-data/images/ui2/favicon.ico");
		document.title = "Acoustics";
		totalTime = -1;
	}

	if (!queueLocked) {
		// the queue
		$("#queue-list").empty();
		var total_length = 0;
		for (var i in json.playlist) {
			var song = json.playlist[i];
			var entry = templates.queueSong.clone();
			$(".queue-song-id", entry).html(song.song_id);
			$(".queue-song-title a", entry).html(titleOrPath(song));
			$(".queue-song-title a", entry).attr('href',
				'#SongDetails/' + song.song_id);

			$(".queue-song-artist a", entry).html(song.artist);
			$(".queue-song-artist a", entry).attr('href',
				'#SelectRequest/artist/' + uriencode(song.artist));

			$(".queue-song-time", entry).html(readableTime(song.length));
			if (song.who.indexOf(currentUser) != -1) {
				$(".queue-song-vote-link", entry).remove();
				$(".queue-song-unvote-link", entry).attr("href",
						"javascript:unvoteSong("+ song.song_id +")");
				$("div",entry).addClass("queue-song-voted");
			} else {
				$(".queue-song-vote-link", entry).attr("href",
						"javascript:voteSong("+ song.song_id +")");
				$(".queue-song-unvote-link", entry).remove();
			}
			$(".queue-song-vote-count", entry).html(song.who.length);
			total_length += parseInt(song.length);
			entry.appendTo("#queue-list");
		}
		var length = $("#queue-list").contents().length;
		if (length == 1) {
			$("#queue-song-count").html("One song");
		} else {
			$("#queue-song-count").html(length + " songs");
		}
		$("#queue-length").html(readableTime(total_length));
	}
}

function login() {
	$.get(
		'www-data/auth',
		function () {playerStateRequest();}
	);
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

function expandSplitDropdown(field) {
	if ($("label",field.parentNode).hasClass("expanded")) {
		$("label",field.parentNode).removeClass("expanded");
	} else {
		$("label",field.parentNode).addClass("expanded");
	}
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

function toggleAdvancedSearch() {
	$("#search-results-advanced-container").slideToggle();
}

function songDetails(id) {
	$.getJSON(
		jsonSource + '?mode=get_details;song_id='+id,
		function(json) {
			json = json.song;
			$("#song-details-title a").html(json.title);
			$("#song-details-title a").attr('title', json.title);
			$("#song-details-title a").attr('href',
				'#SelectRequest/title/' + uriencode(json.title));

			$("#song-details-artist a").html(json.artist);
			$("#song-details-artist a").attr('title', json.artist);
			$("#song-details-artist a").attr('href',
				'#SelectRequest/artist/' + uriencode(json.artist));

			$("#song-details-album a").html(json.album);
			$("#song-details-album a").attr('title', json.album);
			$("#song-details-album a").attr('href',
				'#SelectRequest/album/' + uriencode(json.album));

			$("#song-details-file a").html(json.path);
			$("#song-details-file a").attr('title', json.path);
			$("#song-details-file a").attr('href',
				'#SelectRequest/path/' + uriencode(json.path));
			$("#song-details-album-art").empty();
			$("#song-details-album-art").append("<a href='javascript:fixArt(\"" + jsencode(json.artist) + "\",\"" +
					jsencode(json.album) + "\",\"" + jsencode(json.title) + "\")'>" + 
					"<img id='song-details-album-art-img' src='" + getAlbumArtUrl(json.artist,json.album,json.title,128) + "' width='128'/></a>");
			$("#search-results-song-details").slideDown(300, function() {
				$("#song-details-album-art img").reflect({height: 40});
			});
			if (json.who.length > 0) {
				$("#song-details-voters").html(htmlForVoters(json.who));
			} else {
				$("#song-details-voters").html("");
			}
		}
	);
}

function htmlForVoters(who) {
	var output = "Voters: ";
	for (voter in who) {
		output += who[voter];
		if (voter < who.length - 1) {
			output += ", ";
		}
	}
	return output;
}

function hideSongDetails() {
	$("#song-details-album-art").empty();
	$("#search-results-song-details").slideUp(300);
}

$("#message-box").ready(function() {
	$("#message-box").ajaxError(function (e, xhr, opts, err) {
		/* If there's no message to show, let's not bother */
		if (xhr.responseText.length > 10) {
			showMessage("Communication Error", xhr.responseText);
		}
	});
});

function showMessage(title, message) {
	$("#message-box-title").empty();
	$("#message-box-message").empty();
	$("#message-box-title").html(title);
	$("#message-box-message").html(message);
	$("#message-box").show(100, function() {
		var h = $("#message-box-inner").height() + 10;
		$("#message-box").height(h);
		$("#message-box").css("margin-top", (-h / 2) + "px");
	});
}

function closeMessageBox() {
	$("#message-box").hide(300);
}

function advancedSearchFormSubmit() {
	var conditions = ["OR"];
	var inner = ["AND"];
	$(".advanced-search-row").each(function(index) {
		// TODO: check if this is an OR row instead
		// if (this_is_OR_row) {
		// conditions.push(inner.join('/AND/'));
		// inner = [];
		// etc
		// }

		inner.push($(".adv-search-type input:checked", this).val(),
			//+ "/" + $(".adv-search-compare input:checked", this).val()
			$(".adv-search-value", this).val());
	});
	conditions.push(inner); // handle the last one
	JSON.stringify(conditions);

	$.getJSON(jsonSource + "?mode=search;query=" + JSON.stringify(conditions),
		function (data) {
			$("#search-results-status").html("Processing " + data.length + " results.");
			if (data.length > 1000) {
				if (!confirm("Your search returned a lot of results (" + data.length +"). Do you still want to continue?")) {
					return false;
				}
			}
			fillResultTable(data);
			$("#search-results-status").html("Search results for '" + value + "'.");
		}
	);
	return false;
}

function formSearch() {
	$.address.value("SearchRequest/any/" + formencode($("#search-box").val()));
	return false;
}

function uriencode(str) {
	return encodeURIComponent(formencode(str));
}

function formencode(str) {
	str = new String(str);
	str = str.replace(/\&/g, '%26');
	str = str.replace(/\+/g, '%2b');
	str = str.replace(/\#/g, '%23');
	str = str.replace(/\//g, '%2f');

	return str;
}

function jsencode(str) {
	str = new String(str);
	str = str.replace(/\'/g, '&apos;');
	str = str.replace(/\"/g, '\\\"');
	return str;
}

function moreencode(str) {
	str = uriencode(str);
	str = str.replace(/\'/g, '&apos;');
	str = str.replace(/\"/g, '&quot;');
	return str;
}

function pageLoadChange(hash) {
	hash = hash.replace(/^\//, '');
	var args = hash.split('/');
	var action = args.shift();
	if (!args[0]) args[0] = '';
	if (!args[1]) args[1] = '';
	hideSongDetails();
	if (action == '') {
		loadRandomSongs(20, (new Date()).getTime());
	} else if (action == 'RandomSongs') {
		loadRandomSongs(args[0], args[1]);
	} else if (action == 'RecentSongs') {
		loadRecentSongs(args[0]);
	} else if (action == 'PlayHistory') {
		loadPlayHistory(args[0], args[1]);
	} else if (action == 'SelectRequest') {
		selectRequest(args[0], args[1]);
	} else if (action == 'SearchRequest') {
		doSearch(args[0], args[1]);
	} else if (action == 'SongDetails') {
		songDetails(args[0]);
	}
	if (action == 'Statistics') {
		setLeftPanel("statistics");
		setMenuItem("statistics");
		doStats(args[0]);
		hidePlaylist();
		hideQueue();
	} else if (action == 'Playlists') {
		setLeftPanel("search-results");
		setMenuItem("playlists");
		showPlaylist();
	} else if (action == 'Albums') {
		setLeftPanel("album-search");
		setMenuItem("albums");
		hidePlaylist();
		restoreQueue();
		albumSearch(args[0]);
	} else {
		setLeftPanel("search-results");
		setMenuItem("now-playing");
		hidePlaylist();
		restoreQueue();
	}
}

function setLeftPanel(panel) {
	$(".panel-left").not("#"+panel).hide();
	$("#"+panel).show();
}

function setMenuItem(item) {
	$("#header-bar-menu-list li a").not("#header-bar-menu-"+item).removeClass("header-bar-menu-selected", 100);
	$("#header-bar-menu-" + item).addClass("header-bar-menu-selected", 100);
}

function fixArt(artist, album, title) {
	newArt = prompt("Correct album art for " + title + " by " + artist + ":", "http://example.com/some_image.jpg");
	$.get(getAlbumArtUrl(artist,album,title,0) + "&set=yes&image=" + newArt);
}

function getAlbumArtUrl(artist, album, title, size) {
	return artSource + "&artist=" + moreencode(artist) + "&album=" + moreencode(album) + "&title=" + moreencode(title) + "&size=" + size
}

function unfullscreen() {
	$("#fullscreen-view").fadeOut(300);
}

function fullscreen() {
	$("#fullscreen-view").fadeIn(300, function() {
		});
}

function clearFullscreen() {
	$("#fullscreen-title").html("Nothing Playing");
	$("#fullscreen-artist").html("-");
	$("#fullscreen-album").html("-");
	$("#fullscreen-album-art").empty();
	$("#fullscreen-album-art").html("<img id=\"fullscreen-album-art-img\" width=\"300\" src=\"www-data/icons/big_a.png\" />");
	if (!$.browser.webkit) {
		$("#fullscreen-album-art-img").reflect({height: 100});
	}
}

function albumSearch(title) {
	$.getJSON(jsonSource + "?mode=album_search;album=" + title,
		function (data) {
			$("#album-search-container").empty();
			for (var album in data) {
				var entry = templates.albumResult.clone();
				$("span", entry).html(data[album].album);
				$("img", entry).attr("src", getAlbumArtUrl("", data[album].album, "", 64));
				entry.appendTo("#album-search-container");
			}
		}
	);
}

$.address.change(function(e) {pageLoadChange(e.value);});
