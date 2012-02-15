/* vim:tabstop=4 shiftwidth=4 noexpandtab
 */
/* Configuration data */
var acoustics_version = "1.99-beta";
var jsonSource = 'json.pl';
var artSource = 'json.pl?mode=art';
var _logged_in_as = "logged in as";
var themes = ["dark","light","none"];

/* Global State Variables */
var currentUser = '';
var volume;
var stateTimer;
var templates = {};
var playingTimer;
var elapsedTime = 0;
var totalTime = 0;
var queueLocked = false;
var queueHidden = false;
var queueShouldBeHidden = false;
var nowPlaying = {}
var fsControlsHidden = true;
var fresh = true;
var ajax_cf = 0;
var waiting_for = 0;
var player = 0;
var editingPlaylist = false;
var playlistLocked = false;
var playlistsReady = false;
var currentPlaylist = 0;
var currentId = 0;
var _firstLoad = true;
var theme = 0;
var _forcePlayer = false;

window.setPlayer = function(player) {
	_forcePlayer = player;
	playerStateRequest();
}

function getPath(str) {
	if (!_forcePlayer) {
		return jsonSource + "?" + str;
	} else {
		return jsonSource + "?player_id=" + _forcePlayer + "&" + str;
	}
}

function getPath_(str) {
	return jsonSource + "?" + str;
}

function toggleTheme() {
	/* Toggle the theme when the star next to the login button is pressed */
	theme++;
	if (theme == themes.length) {
		theme = 0;
	}
	$("#theme").attr("href","www-data/" + themes[theme] + "-theme.css");
}

function orientationAdjust() {
	if (window.orientation && Math.abs(window.orientation) == 90) {
		/* Landscape */
		hideQueue();
		$("#header-bar").slideDown(200);
		$("#main-content").css("top",'20px');
	} else {
		/* Portrait */
		$("#right-panel").css("width", $(window).width());
		$("#playlist-panel").css("width", $(window).width());
		showQueue();
		$("#header-bar").slideUp(200);
		$("#main-content").css("top",'0px');
		fixNPWidth();
	}
}

function mobilize() {
	/* Mobilize the interface by changing the structural CSS to the Mobile one,
	 * adjusting content widths, moving everything around as nececssary, and being
	 * generally awesome. */
	$("#structure").attr("href","www-data/acoustics-mobile.css");
	/* Disable effects */
	$.fx.off = true;
	/* Simplify the username display */
	_logged_in_as = ":";

	/* Hide the right panel by default */
	$("#toggle-right-panel").hide();

	/* Enable orientation adjustment */
	var supportsOrientationChange = "onorientationchange" in window,
		orientationEvent = supportsOrientationChange ? "orientationchange" : "resize";
	orientationAdjust();
	window.addEventListener(orientationEvent, orientationAdjust, false);

}

function dedupArray(array) {
	array.sort();
	var cnt = array.length;
	var i=0;
	var keepers = new Array();
	while (i < cnt){
		if (array[i] != array[i + 1]){
			keepers.push(array[i]);
			i++;
		} else {
			array.shift();
		}
		cnt = array.length;
	}
	return keepers;
}

$(document).ready(function() {
	unfullscreen();
	clearFullscreen();
	if( navigator.userAgent.match(/Android/i) ||
		navigator.userAgent.match(/webOS/i) ||
		navigator.userAgent.match(/iPhone/i) ||
		navigator.userAgent.match(/iPod/i)
		){
		mobilize();
	}
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
		revert: 200,
		start: function() { queueLocked = true; },
		stop: function(event,ui) {
			if ($(ui.item).is("tr")) {
				var entry = templates.queueSong.clone();
				var song  = $(".search-results-entry-song-id",ui.item).html();
				silentVote(song);
				$("div",entry).addClass("queue-song-voted");
				$(".queue-song-id", entry).html(song);
				$(".queue-song-title a", entry).html($(".search-results-entry-title a",ui.item).html());
				$(".queue-song-artist a", entry).html($(".search-results-entry-artist a",ui.item).html());
				$(".queue-song-artist a img", entry).attr('src',$(".search-results-entry-title a img",ui.item).attr('src'));
				$(entry).insertBefore($(ui.item));
				$(ui.item).remove();
				var block = updateQueueOrder();
				setTimeout(function() {
					updateQueueOrder();
					forceQueueOrder(block);
				}, 200);
			}
			queueLocked = false;
		},
		update: updateQueueOrder
	});



	$("#playlist-list").sortable({
		placeholder: "queue-song-placeholder",
		revert: 200,
		start: function() { playlistLocked = true; },
		stop: function(event,ui) {
			if ($(ui.item).is("tr")) {
				var entry = templates.queueSong.clone();
				var song  = $(".search-results-entry-song-id",ui.item).html();
				silentVote(song);
				$(".queue-song-id", entry).html(song);
				$(".queue-song-title a", entry).html($(".search-results-entry-title a",ui.item).html());
				$(".queue-song-artist a", entry).html($(".search-results-entry-artist a",ui.item).html());
				$(".queue-song-artist a img", entry).attr('src',$(".search-results-entry-title a img",ui.item).attr('src'));
				$(entry).insertBefore($(ui.item));
				$(ui.item).remove();
				var block = updatePlaylistOrder();
				setTimeout(function() {
					updatePlaylistOrder();
					forcePlaylistOrder(block);
				}, 200);
			}
			playlistLocked = false;
		},
		update: updatePlaylistOrder
	});

	$("#search-box").keyup(function () {
		var search_value = $("#search-box").val().toLowerCase();
		currentId += 1;
		var _myid = currentId;
		if (search_value.length < 3) { 
			$("#search-results-suggestions").html("");
			return;
		}
		$.getJSON(
			getPath('mode=quick_search;q=' + search_value),
			function (data) {
				if (currentId != _myid) return;
				var output = Array();
				var replacement = "<b>$1</b>";
				var link = "<a href='#' onClick='quickComplete(this); return false;'>";
				var link_tail = "</a>";
				var regex = new RegExp( '(' + search_value + ')', 'gi' );
				var formatString = "<b><u>$1</u></b>";
				for (id in data) {
					var result = data[id];
					if (result.artist.toLowerCase().indexOf(search_value) != -1) {
						output.push(link + result.artist.replace(regex, formatString) + link_tail);
					}
					if (result.album.toLowerCase().indexOf(search_value) != -1) {
						output.push(link + result.album.replace(regex, formatString) + link_tail);
					}
					if (result.title.toLowerCase().indexOf(search_value) != -1) {
						output.push(link + result.title.replace(regex, formatString) + link_tail);
					}
				}
				$("#search-results-suggestions").html(dedupArray(output).join(" "));
			}
		);
	});

	// templating
	templates.queueSong = $("li.queue-song").first().clone();
	templates.nowPlayingInfo = $("#now-playing-info").clone();
	templates.nowPlayingPanel = $("#now-playing-panel").clone();
	templates.nowPlayingAlbumArt = $("#now-playing-album-art-img").clone();
	templates.searchResultSong = $("#search-results-entry").clone();
	templates.advancedSearchEntry = $("#advanced-search-NUM").clone();
	templates.albumResult = $(".album-icon").clone();
	templates.contentFlow = $("#cf").clone();
	$("#cf").remove();
	$("#advanced-search-NUM").remove();
	$("#search-results-table tbody").empty();
	$(".album-icon").remove();

	playerStateRequest();
	if (stateTimer) clearInterval(stateTimer);
	stateTimer = setInterval('playerStateRequest()', 15000);

	/* Table sorting */
	var table = $("#search-results-table");
	/* String sort */
	$("#sr-title, #sr-artist, #sr-album").wrapInner("<span title='Click to Sort'/>")
		.each(function() {
			var th = $(this),
				thIndex = th.index(),
				inverse = false;
			th.click(function() {
				if (!inverse) {
					clearSortIndicators();
					$(this).addClass("sortDown");
				} else {
					clearSortIndicators();
					$(this).addClass("sortUp");
				}
				table.find('td').filter(function() {
					return $(this).index() === thIndex;
				}).sortElements(function(a, b) {
					return $.text([a]) > $.text([b]) ?
					inverse ? -1 : 1 :
					inverse ? 1 : -1;
				}, function() {
					return this.parentNode;
				});
				inverse = !inverse;
			});
		});
	/* Hidden integer sort */
	$("#sr-length, #sr-track").wrapInner("<span title='Click to Sort'/>")
		.each(function() {
			var th = $(this),
				thIndex = th.index(),
				inverse = false;
			th.click(function() {
				if (!inverse) {
					clearSortIndicators();
					$(this).addClass("sortDown");
				} else {
					clearSortIndicators();
					$(this).addClass("sortUp");
				}
				table.find('td').filter(function() {
					return $(this).index() - 1 === thIndex;
				}).sortElements(function(a, b) {
					return parseInt($(a).text()) > parseInt($(b).text()) ?
					inverse ? -1 : 1 :
					inverse ? 1 : -1;
				}, function() {
					return this.parentNode;
				});
				inverse = !inverse;
			});
		});

	$(".header-bar-menu-root").click(function() {
		$("#"+$(this).attr('id')+"-dropdown").show();
	});
	$('.header-bar-menu-dropdown').click(function() {
		$(this).hide();
	});
	$("#toggle-right-panel").draggable({axis: 'x', snap: "body", snapTolerance: 100, drag: function(event, ui) {
		var width = ($(window).width() - $("#toggle-right-panel").offset().left - $("#toggle-right-panel").width());
		setQueueWidth(width);
	}, stop: function(event, ui) {
		var width = ($(window).width() - $("#toggle-right-panel").offset().left - $("#toggle-right-panel").width());
		$("#toggle-right-panel").css("right",width);
		$("#toggle-right-panel").css("left","-");
	}});
	$("#playlist-select-form").change(function() { loadPlaylist(-1); });
	insertAdvancedSearch(1);
	insertAdvancedSearch(2);

	/* Set the version number in the management console */
	$("#manage-version").html("Web Client v." + acoustics_version);

	/* Disable touch scrolling on elements that shouldn't ever be doing it */
	$("#header-bar, #fullscreen-view, .toolbar, .statusbar, #now-playing-panel, #controls").bind("touchmove", function(event) {
		event.preventDefault();
	});

});

function clearSortIndicators() {
	$("#search-results-table th").removeClass("sortUp");
	$("#search-results-table th").removeClass("sortDown");
}

function setQueueWidth(width) {
	$("#right-panel").css("width", width);
	$("#playlist-panel").css("width", width);
	$(".panel-left").css("right",width);
	fixNPWidth();
}
function fixNPWidth() {
	$("#now-playing-info").css("width",($("#now-playing-panel").width() - $("#now-playing-album-art").width() - 4) + 'px');
}
function fixTabOffset() {
	if ($("#toggle-right-panel").width() != null) {
		$("#toggle-right-panel").offset({top: $("#toggle-right-panel").offset().top, left:($(window).width() - $("#right-panel").width() - $("#toggle-right-panel").width())});
	}
}

function quickComplete(block) {
	var out = block.textContent;
	$("#search-box").val(out);
	formSearch();
}


function insertAdvancedSearch(id) {
	var entry = templates.advancedSearchEntry.clone();
	if (entry.attr("id")) {
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
		$("#advanced-search-submit").before(entry);
	}
}

function _queue_width() {
	if ($("#right-panel").width() != null) {
		return $("#right-panel").width().toString();
	} else {
		return 0;
	}
}

function showQueue() {
	var speed = 400;
	if (_firstLoad) speed = 0;
	$("#right-panel, #playlist-panel").animate({
		right: '0'
	}, speed);
	$(".panel-left").animate({
		right: _queue_width()
	}, speed, function() {
		if (ajax_cf) {
			ajax_cf.resize();
		}
	});
	$("#toggle-right-panel").css("display","block");
	queueHidden = false;
}

function hideQueue() {
	var speed = 400;
	if (_firstLoad) speed = 0;
	$("#right-panel, #playlist-panel").animate({
		right: '-' + _queue_width()
	}, speed);
	$(".panel-left").animate({
		right: '0'
	}, speed, function() {
		if (ajax_cf) {
			ajax_cf.resize();
		}
	});
	$("#toggle-right-panel").css("display","none");
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
	var speed = 600;
	if (_firstLoad) speed = 0;
	$("#playlist-panel").fadeIn(speed);
	showQueue();
	/* Clear the playlist list */
	$("#playlist-select-form").empty();
	$("#playlist-select-form").append("<option value='-' selected='selected'>Playlists...</option>");
	/* Load the list of playlists */
	$.getJSON(
		getPath('mode=playlists;who=' + currentUser),
		function (data) {
			for (id in data) {
				var playlist = data[id];
				$("#playlist-select-form").append($("<option></option>").attr("value", playlist.playlist_id).text(playlist.title));
			}
			playlistsReady = true;
		}
	);
}

function hidePlaylist() {
	var speed = 600;
	if (_firstLoad) speed = 0;
	$("#playlist-panel").fadeOut(speed);
}

function updatePlaylistOrder(event, ui) {
	var block = "";
	$("#playlist-list .queue-song").each(function(index) {
		block += "song_id=" + $(".queue-song-id",this).text() + ";";
	});
	$.getJSON(
		getPath('mode=remove_from_playlist;playlist_id=' + currentPlaylist + ';' + block),
		function (data) {
			$.getJSON(
				getPath('mode=add_to_playlist;playlist_id=' + currentPlaylist + ';' + block),
				function (data) {
					loadPlaylist(currentPlaylist);
				}
			);
		}
	);
}

function loadPlaylist(pl) {
	if (pl == -1) {
		pl = $("#playlist-select-form").val();
		if (pl == '-') {
			return ;
		}
		window.location.hash = "Playlists/" + pl;
	}
	if (pl == 0) {
		return;
	}
	currentPlaylist = pl;
	$.getJSON(
		getPath('mode=playlist_contents;playlist_id=' + pl),
		function (data) {
			$("#playlist-list").empty();
			var total_length = 0;
			if (!playlistLocked) {
				for (var i in data) {
					var song = data[i];
					var entry = templates.queueSong.clone();
					$(".queue-song-id", entry).html(song.song_id);
					$(".queue-song-title a", entry).html(titleOrPath(song));
					$(".queue-song-title a", entry).attr('href',
						'#SongDetails/' + song.song_id);

					album_art = $("<img />").attr("width","16").attr("class","mini-album-art").attr("src",getAlbumArtUrl(song.artist,song.album,song.title,16));

					$(".queue-song-artist a", entry).empty();
					$(".queue-song-artist a", entry).append(album_art)
					$(".queue-song-artist a", entry).append(song.artist);
					$(".queue-song-artist a", entry).attr('href',
						'#SelectRequest/artist/' + uriencode(song.artist));

					$(".queue-song-vote-link", entry).remove();
					$(".queue-song-unvote-link", entry).attr("href",
							"javascript:unvoteSong("+ song.song_id +")");
					$(".queue-song-vote-count", entry).html(parseInt(i) + 1);

					$(".queue-song-time", entry).html(readableTime(song.length));
					total_length += parseInt(song.length);
					entry.appendTo("#playlist-list");
				}
			}
			var length = $("#playlist-list").contents().length;
			if (length == 1) {
				$("#playlist-status").html("One song");
			} else {
				$("#playlist-status").html(length + " songs");
			}
			$("#playlist-length").html(readableTime(total_length));
			$("#playlist-select-form").val(pl);
		}
	);
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

function updatePlayingTime() {
	if (elapsedTime < totalTime) {
		$('#now-playing-time').html(readableTime(++elapsedTime));
		$('#now-playing-progress').progressbar({value: 100 * (elapsedTime/totalTime)});
		$('#fullscreen-progress').progressbar({value: 100 * (elapsedTime/totalTime)});
	} else if (elapsedTime >= totalTime && totalTime > 0) {
		playerStateRequest();
	}
}

function startPlayingTimer() {
	if (playingTimer) clearInterval(playingTimer);
	playingTimer = setInterval('updatePlayingTime()', 1000);
}

function playerStateRequest() {
	$.getJSON(
		getPath('mode=status'),
		function (json) {handlePlayerStateRequest(json);}
	);
}

function doStats(who) {
	$("#info-status").html("Getting statistics...");
	$.getJSON(
		getPath("mode=stats;who=" + who),
		function (json) {
			$("#info-status").html("Thank you for using Acoustics, the Social Music Player!");
			$("#info-song-count").html(json.total_songs);
			$("#info-top-artist").html(json.top_artists[0].artist);
		}
	);
	$.getJSON(
		getPath("mode=top_voted;limit=1"),
		function (json) {
			$("#info-top-voted").html(json[0].title);
		}
	);
}

function doSearch(field, value) {
	$("#search-results-status").html("Searching for '" + value + "'...");
	$("#search-results-dim").show();
	$.getJSON(getPath("mode=search;field=" + field + ";value=" + value),
		function (data) {
			$("#search-results-status").html("Processing " + data.length + " results.");
			if (data.length > 1000) {
				if (!confirm("Your search returned a lot of results (" + data.length +"). Do you still want to continue?")) {
					return false;
				}
			}
			fillResultTable(data);
			$("#search-results-status").html("Search results for '" + value + "'.");
			$("#search-results-dim").hide();
	});
	return false;
}

function selectRequest(field, value) {
	$("#search-results-status").html("Searching for '" + value + "'...");
	$("#search-results-dim").show();
	$.getJSON(getPath("mode=select;field=" + field + ";value=" + value),
		function (data) {
			$("#search-results-status").html("Processing " + data.length + " results.");
			fillResultTable(data);
			$("#search-results-status").html("Songs where " + field + " is '"
				+ value + "'.");
			$("#search-results-dim").hide();
	});
}

function loadRandomSongs(amount, seed) {
	$("#search-results-dim").show();
	$.getJSON(
		getPath("mode=random;amount=" + amount + ";seed=" + seed),
		function (data) {
			$('#search-results-random a').attr('href',
				'#RandomSongs/20/' + (Math.floor(Math.random()*1e9)));
			fillResultTable(data);
			$("#search-results-status").html(amount + " Random Songs");
			$("#search-results-dim").hide();
		}
	);
}

function loadRecentSongs(amount) {
	$("#search-results-dim").show();
	$.getJSON(
		getPath('mode=recent;amount=' + amount),
		function (data) {
			fillResultTable(data);
			$("#search-results-status").html(amount + " Recently Added Songs");
			$("#search-results-dim").hide();
		}
	);
}

function loadPlayHistory(amount, who) {
	$("#search-results-dim").show();
	$.getJSON(
		getPath('mode=history;amount=' + amount + ";who=" + who),
		function (data) {
			fillResultTable(data);
			var bywho = "";
			if (who) bywho = " By " + who;
			$("#search-results-status").html(amount + " Recently Played Songs"
				+ bywho);
			$("#search-results-dim").hide();
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
	clearSortIndicators();
	if (json.length < 1) {
		$("#search-results-table tbody").append("<tr><td colspan=\"6\"><center><i>No results.</i></center></td></tr>");
		$("#search-results-time").html("0 seconds");
		$("#search-results-count").html("0 songs");
		return false;
	}
	var total_length = 0;
	$("#search-results-table tbody").empty();
	var votedSongs = Array();
	$("#queue-list li").each(function(index) {
		if ($(".queue-song-id",this).hasClass("queue-song-voted")) {
			votedSongs[votedSongs.length] = $(".queue-song-id", this).text();
		}
	});
	for (i in json) {
		var song = json[i];
		var entry = templates.searchResultSong.clone();
		$(".search-results-entry-song-id", entry).html(song.song_id);
		$(".search-results-entry-track", entry).html(song.track);
		$(".search-results-entry-track-sort", entry).html(parseInt(song.track) + parseInt(song.disc) * 1000);
		$(".search-results-entry-length", entry).html(readableTime(song.length));
		$(".search-results-entry-length-internal", entry).html(song.length);

		$(".search-results-entry-vote", entry).attr('href',
			'javascript:voteSongSearch(' + song.song_id + ')');
		if ($.inArray(song.song_id.toString(), votedSongs) > -1) {
			$(".search-results-entry-vote", entry).addClass("search-results-entry-voted");
		}

		album_art = $("<img />").attr("width","16").attr("class","mini-album-art").attr("src",getAlbumArtUrl(song.artist,song.album,song.title,16));
		$(".search-results-entry-title a", entry).empty();
		$(".search-results-entry-title a", entry).append(album_art)
		$(".search-results-entry-title a", entry).append(song.title);
		$(".search-results-entry-title a", entry).attr('href',
			'#SongDetails/' + song.song_id);
		$(".search-results-entry-title a", entry).attr('title', song.title);

		$(".search-results-entry-album a", entry).html(song.album);
		$(".search-results-entry-album a", entry).attr('href',
			'#SelectRequest/album/' + uriencode(song.album));
		$(".search-reuslts-entry-album a", entry).attr('title', song.album);

		$(".search-results-entry-artist a", entry).html(song.artist);
		$(".search-results-entry-artist a", entry).attr('href',
			'#SelectRequest/artist/' + uriencode(song.artist));
		$(".search-results-entry-artist a", entry).attr('title', song.artist);

		$("#search-results-table tbody").append(entry);
		$(entry).draggable({revert: "invalid", cursorAt: { top: 20, left: 100 }, appendTo: 'body', helper: 'clone', connectToSortable: "ul#queue-list"});

		total_length += parseInt(song.length);
	}
	$("#search-results-time").html(readableTime(total_length));
	if (json.length == 1) {
		$("#search-results-count").html("One song");
	} else {
		$("#search-results-count").html(json.length +" songs");
	}
}

function updateQueueOrder(event, ui) {
	$("#search-results-status").html("The queue was reordered.");
	var block = "";
	$("#queue-list li").each(function(index) {
		block += "song_id=" + $(".queue-song-id",this).text() + ";";
	});
	$.getJSON(
		getPath('mode=reorder_queue;' + block),
		function (data) {handlePlayerStateRequest(data);}
	);
	return block;
}

function forceQueueOrder(queue_order) {
	$("#search-results-status").html("The queue was reordered.");
	$.getJSON(
		getPath('mode=reorder_queue;' + queue_order),
		function (data) {handlePlayerStateRequest(data);}
	);
}

/*
 * Jonas Raoni Soares Silva
 * http://jsfromhell.com/array/shuffle [v1.0]
 */
function shuffleArray(o) { //v1.0
	for(var j, x, i = o.length; i; j = parseInt(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x);
		return o;
}

function shuffleQueue() {
	var _queue = Array();
	$("#queue-list li").each(function(index) {
		_queue.push($(".queue-song-id",this).text())
	});
	_queue = shuffleArray(_queue);
	var block = "";
	for (i in _queue) {
		block += "song_id=" + _queue[i] + ";";
	}
	$.getJSON(
		getPath('mode=reorder_queue;' + block),
		function (data) {handlePlayerStateRequest(data);}
	);
}

function voteSong(song_id) {
	if (editingPlaylist) {
		$.getJSON(
			getPath('mode=add_to_playlist;playlist_id=' + currentPlaylist + ';song_id=' + song_id),
			function (data) { loadPlaylist(currentPlaylist); }
		);
	} else {
		$.getJSON(
			getPath('mode=vote;song_id=' + song_id),
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function voteSongSearch(song_id) {
	voteSong(song_id);
	$("#search-results-table tbody tr").each(function(index) {
		if ( $(".search-results-entry-song-id",this).text() == song_id) {
			$(".search-results-entry-vote", this).addClass("search-results-entry-voted");
		}
	});
}

function silentVote(song_id) {
	if (editingPlaylist) {
		$.getJSON(getPath('mode=add_to_playlist;playlist_id=' + currentPlaylist + ';song_id=' + song_id));
	} else {
		$.getJSON(getPath('mode=vote;song_id=' + song_id));
	}

}

function playlistPlay() {
	var block = "";
	$("#playlist-list .queue-song").each(function(index) {
		block += "song_id=" + $(".queue-song-id",this).text() + ";";
	});
	var command = "mode=vote;";
	$.getJSON(
			getPath(command + block),
			function(data){
				handlePlayerStateRequest(data);
				window.location.hash = "#";
			}
	);
}

function playlistNew() {
	var title = prompt(
		"Playlist name:",
		"experiment " + Math.floor(Math.random()*10000)
	);
	if (title) $.getJSON(
		getPath('mode=create_playlist;title=' + title),
		function() {
			showPlaylist();
		}
	);
}

function playlistDelete() {
	var answer = confirm("Really delete this playlist?");
	if (answer) {
		$.getJSON(
			getPath('mode=delete_playlist;playlist_id=' + currentPlaylist),
			function() { showPlaylist(); }
		);
	}
}

function unvoteSong(song_id) {
	if (editingPlaylist) {
		$.getJSON(
			getPath('mode=remove_from_playlist;playlist_id=' + currentPlaylist + ';song_id=' + song_id),
			function (data) { loadPlaylist(currentPlaylist); }
		);
	} else {
		$.getJSON(
			getPath('mode=unvote;song_id=' + song_id),
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function changePlayer(player_id) {
	$.getJSON(
		getPath_("mode=change_player;player_id="+player_id),
		function(data) { handlePlayerStateRequest(data);}
	);
}

function migrateToPlayer(player_id) {
	block = "";
	$("#queue-list li").each(function(index) {
		if ($(".queue-song-id",this).hasClass("queue-song-voted")) {
			block += "song_id=" + $(".queue-song-id",this).text() + ";";
		}
	});
	var command = "mode=unvote;";
	$.getJSON(
		getPath(command + block),
		function (data) {
			$.getJSON(
				getPath("mode=change_player;player_id=" + player_id),
				function(data) {
					command = "mode=vote;" + block;
					$.getJSON(
						getPath(command),
						function(data) {
							handlePlayerStateRequest(data);
						}
					);
				}
			);
		}
	);

}

function voteAll() {
	var block = "";
	$("#search-results-table tbody tr").each(function(index) {
		block += "song_id=" + $(".search-results-entry-song-id",this).text() + ";";
	});
	var command;
	if (editingPlaylist) {
		command = "mode=add_to_playlist;playlist_id=" + currentPlaylist + ";";
	} else {
		command = "mode=vote;";
	}
	$.getJSON(
			getPath(command + block),
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
	var command;
	if (editingPlaylist) {
		command = "mode=add_to_playlist;playlist_id=" + currentPlaylist + ";";
	} else {
		command = "mode=vote;";
	}
	$.getJSON(
			getPath(command + block),
			function(data){handlePlayerStateRequest(data);}
	);
}

function clearQueue() {
	block = "";
	$("#queue-list li").each(function(index) {
		block += "song_id=" + $(".queue-song-id",this).text() + ";";
	});
	var command = "mode=unvote;";
	$.getJSON(
			getPath(command + block),
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
	player = json.selected_player;

	fixTabOffset();


	// user
	if (json.who) {
		$("#header-bar-user-message").html(_logged_in_as);
		$("#user-name").html(json.who);
		currentUser = json.who;
		$("#header-bar-menu-playlists").show();
	} else {
		$("#header-bar-menu-playlists").hide();
	}

	// admin
	if (!json.who || !json.is_admin) {
		$("#header-bar-menu-manage").hide();
	} else if (json.who && json.is_admin) {
		$("#header-bar-menu-manage").show();
	}

	// players
	if (json.players.length > 1) {
		$("#header-bar-menu-players-dropdown li").remove();
		$("#header-bar-menu-players-dropdown").append("<li class='header-bar-menu-title'>Players</li>");
		for (i in json.players) {
			if (json.players[i] == json.selected_player) {
				$("#header-bar-menu-players-dropdown").append("<li><b><a href=\"javascript:changePlayer('" + json.players[i] + "');\" style='color: #FFF;'>" + json.players[i] + "</a></b></li>\n");
			} else {
				$("#header-bar-menu-players-dropdown").append("<li><a href=\"javascript:changePlayer('" + json.players[i] + "');\">" + json.players[i] + "</a> <a href=\"javascript:migrateToPlayer('" + json.players[i] + "');\"><img src='www-data/images/ui2/arrow-left.svg' alt='&lt;'/></a></li>\n");

			}
		}
		$("#header-bar-menu-players").html("[" + json.selected_player + "]");
	} else {
		$("#header-bar-menu-players").remove();
	}

	// now playing
	nowPlaying = json.now_playing;
	if (nowPlaying) {
		var nowPlayingPanel = templates.nowPlayingInfo.clone();
		$("#now-playing-album-art").show();
		$("#now-playing-info").show();
		$("#nothing-playing-info").hide();
		if (nowPlaying.title.length > 0) {
			$("#now-playing-title a", nowPlayingPanel).html(nowPlaying.title);
		} else {
			$("#now-playing-title a", nowPlayingPanel).html('[untitled]');
		}
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
		if (nowPlaying.who.length == 0) {
			$("#now-playing-shuffle").show();
		} else {
			$("#now-playing-shuffle").hide();
		}
		$("#nothing-playing-info", nowPlayingPanel).remove();
		$("#now-playing-info").replaceWith(nowPlayingPanel);
		$("#now-playing-album-art").empty();
		album_art = $("<img />").attr("id","now-playing-album-art-img").attr("src",getAlbumArtUrl(nowPlaying.artist,nowPlaying.album,nowPlaying.title,64)).attr("width","64");
		$("#now-playing-album-art").append(album_art);

		$("#now-playing-album-art-img").reflect({height: 16});
		$("#now-playing-progress").progressbar({value: 100 * (elapsedTime/totalTime)});
		fixNPWidth();
		$("#fullscreen-progress").progressbar({value: 100 * (elapsedTime/totalTime)});
		/* Full screen view */
		$("#fullscreen-title").html(nowPlaying.title);
		$("#fullscreen-artist").html(nowPlaying.artist);
		$("#fullscreen-album").html(nowPlaying.album);
		$("#fullscreen-album-art").empty();
		album_art = $("<img />").attr("id","fullscreen-album-art-img").attr("src",getAlbumArtUrl(nowPlaying.artist,nowPlaying.album,nowPlaying.title,300)).attr("width","300");
		$("#fullscreen-album-art").append(album_art);
		if (!$.browser.webkit) {
			$("#fullscreen-album-art-img").reflect({height: 100});
		}
		/* And here's the fun part */
		jQuery.favicon(getAlbumArtUrl(nowPlaying.artist,nowPlaying.album,nowPlaying.title,20));
		/* Title Bar */
		document.title = nowPlaying.title + " - " + nowPlaying.artist + " [Acoustics]";
		/* Play / Pause */
		$("#controls-play-pause img").attr("src","www-data/images/ui2/buttons/pause.svg");
		/*
		if (nowPlaying.state == 'paused') {
			$("#controls-play-pause img").attr("src","www-data/images/ui2/buttons/play.svg");
		}
		*/
	} else {
		var nowPlayingPanel = templates.nowPlayingPanel.clone();
		$("#now-playing-album-art", nowPlayingPanel).hide();
		$("#now-playing-info", nowPlayingPanel).hide();
		$("#now-playing-panel").replaceWith(nowPlayingPanel);
		$("#nothing-playing-info").show();
		clearFullscreen();
		$("#now-playing-shuffle").hide();
		jQuery.favicon("www-data/images/ui2/favicon.ico");
		document.title = "Acoustics";
		totalTime = -1;
		$("#controls-play-pause img").attr("src","www-data/images/ui2/buttons/play.svg");
	}

	if (!queueLocked) {
		// the queue
		$("#queue-list .queue-song").remove();
		var total_length = 0;
		var userList = Array();
		for (var i in json.playlist) {
			var song = json.playlist[i];
			var entry = templates.queueSong.clone();
			$(".queue-song-id", entry).html(song.song_id);
			$(".queue-song-title a", entry).html(titleOrPath(song));
			$(".queue-song-title a", entry).attr('href',
				'#SongDetails/' + song.song_id);

			album_art = $("<img />").attr("width","16").attr("class","mini-album-art").attr("src",getAlbumArtUrl(song.artist,song.album,song.title,16));

			$(".queue-song-artist a", entry).empty();
			$(".queue-song-artist a", entry).append(album_art)
			$(".queue-song-artist a", entry).append(song.artist);
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
			for (i in song.who) {
				if ($.inArray(song.who[i],userList) < 0) {
					userList.push(song.who[i]);
				}
			}
			$(".queue-song-vote-count", entry).html(song.who.length);
			total_length += parseInt(song.length);
			entry.appendTo("#queue-list");
		}
		var userList_html = Array();
		for (var i in userList) {
			userList_html.push("<a href='#' class='control-button button-link' onClick='managePurgeUser(this.textContent); return false;'>" + userList[i] + "</a>");
		}
		$("#manage-purge").html(userList_html.join("<br />"));
		var length = json.playlist.length;
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
	var command = 'start';
	if (nowPlaying) {
		command = 'pause';
	}
	$.getJSON(
			getPath('mode=' + command),
		function (data) {handlePlayerStateRequest(data);}
	);
}

function controlStop() {
	$.getJSON(
		getPath('mode=stop'),
		function (data) {handlePlayerStateRequest(data);}
	);
}

function controlNext() {
	$.getJSON(
		getPath('mode=skip'),
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
			getPath('mode=volume;value=' + volume),
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function controlVolumeUp() {
	if (volume != undefined) {
		volume += 10;
		if (volume > 100) { volume = 100; }
		$.getJSON(
			getPath('mode=volume;value=' + volume),
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function toggleAdvancedSearch() {
	$("#search-results-advanced-container").slideToggle();
}

function songDetails(id) {
	$.getJSON(
		getPath('mode=get_details;song_id='+id),
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
			$("#song-details-edit-album-art").attr("href","javascript:fixArt(\"" + jsencode(json.artist) + "\",\"" + jsencode(json.album) + "\",\"" + jsencode(json.title) + "\")");
			album_art = $("<img />").attr("id","fullscreen-album-art-img").attr("src",getAlbumArtUrl(json.artist,json.album,json.title,128)).attr("width","128");
			$("#song-details-album-art").append(album_art);
			$("#search-results-song-details").slideDown(300, function() {
				$("#song-details-album-art img").reflect({height: 40});
			});
			if (json.who.length > 0) {
				$("#song-details-voters").html(htmlForVoters(json.who));
			} else {
				$("#song-detaititlevoters").html("");
			}
			if (json.who.indexOf(currentUser) != -1) {
				$("#song-details-vote").attr("href","javascript:unvoteSong(" + id + ")");
				$("#song-details-vote").html("unvote");
			} else {
				$("#song-details-vote").attr("href","javascript:voteSong(" + id + ")");
				$("#song-details-vote").html("vote");
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
			showMessageImportant("Communication Error", xhr.responseText);
		}
	});
});

function showMessage(title, message) {
	$("#message-box-title").empty();
	$("#message-box-message").empty();
	$("#message-box-title").html(title);
	$("#message-box-message").html(message);
	$("#message-box").slideDown(300, function() {
		var h = $("#message-box-inner").height() + 20;
		$("#message-box").height(h);
	});
}

function showMessageImportant(title, message) {
	$("#message-box-dimmer").fadeIn();
	showMessage(title, message);
}

function closeMessageBox() {
	$("#message-box-dimmer").fadeOut();
	$("#message-box").slideUp();
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

	$.getJSON(getPath("mode=search;query=" + JSON.stringify(conditions)),
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
	str = str.replace(/\'/g, '%27');
	str = str.replace(/\"/g, '%22');
	return str;
}

function pageLoadChange(hash) {
	hash = hash.replace(/^\//, '');
	var args = hash.split('/');
	var action = args.shift();
	if (!args[0]) args[0] = '';
	if (!args[1]) args[1] = '';
	hideSongDetails();
	if (action == 'Player') {
		_forcePlayer = args.shift();
		action = args.shift();
	}
	if (action == '' && fresh) {
		loadRandomSongs(20, (new Date()).getTime());
		fresh = false;
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
	if (action == 'SetPlayer') {
		changePlayer(args[0]);
	} else if (action == 'Info') {
		hideQueue();
		setLeftPanel("info");
		setMenuItem("info");
		editingPlaylist = false;
		doStats(args[0]);
		hidePlaylist();
	} else if (action == 'Playlists') {
		setLeftPanel("search-results");
		setMenuItem("playlists");
		showPlaylist();
		editingPlaylist = true;
		if (args.length > 0) {
			loadPlaylist(args[0]);
		}
	} else if (action == 'Albums') {
		restoreQueue();
		setLeftPanel("album-search");
		setMenuItem("albums");
		editingPlaylist = false;
		hidePlaylist();
		albumSearch(args[0]);
	} else if (action == 'Manage') {
		restoreQueue();
		setLeftPanel("manage");
		setMenuItem("manage");
		editingPlaylist = false;
		hidePlaylist();
	} else if (action == '') {
		restoreQueue();
		setLeftPanel("search-results");
		setMenuItem("songs");
		editingPlaylist = false;
		hidePlaylist();
	} else {
		restoreQueue();
		setLeftPanel("search-results");
		if (editingPlaylist) {
			setMenuItem("playlists");
			showPlaylist();
		} else {
			setMenuItem("songs");
			editingPlaylist = false;
			hidePlaylist();
		}
	}
	_firstLoad = false;
}

function setLeftPanel(panel) {
	var speed = 600;
	if (_firstLoad) speed = 0;
	$(".panel-left").not("#"+panel).fadeOut(speed);
	$("#"+panel).fadeIn(speed);
}

function setMenuItem(item) {
	var speed = 100;
	if (_firstLoad) speed = 0;
	$("#header-bar-menu-list li a").not("#header-bar-menu-"+item).removeClass("header-bar-menu-selected", speed);
	$("#header-bar-menu-" + item).addClass("header-bar-menu-selected", speed);
}

function fixArt(artist, album, title) {
	newArt = prompt("Correct album art for " + title + " by " + artist + ":", "http://example.com/some_image.jpg");
	if (newArt) {
		$.get(getAlbumArtUrl(artist,album,title,0) + "&set=yes&image=" + newArt);
	}
}

function getAlbumArtUrl(artist, album, title, size) {
	return artSource + "&artist=" + moreencode(artist) + "&album=" + moreencode(album) + "&title=" + moreencode(title) + "&size=" + size
}

function unfullscreen() {
	$("#fullscreen-view").fadeOut(300);
}

function fullscreen() {
	$("#fullscreen-view").fadeIn(300);
}

function clearFullscreen() {
	$("#fullscreen-title").html("Nothing Playing");
	$("#fullscreen-artist").html("-");
	$("#fullscreen-album").html("-");
	$("#fullscreen-album-art").empty();
	$("#fullscreen-album-art").html("<img id=\"fullscreen-album-art-img\" width=\"300\" src=\"www-data/icons/cd_case.svg\" />");
	if (!$.browser.webkit) {
		$("#fullscreen-album-art-img").reflect({height: 100});
	}
}

function albumSearch(title) {
	if (title == "_none_") {
		title = nowPlaying.album;
	}
	$("#album-search-status").html("Searching for '" + title + "'...");
	$.getJSON(getPath("mode=album_search;album=" + title),
		function (data) {
			$("#album-search-albums").empty();
			$(".cf-container").empty();
			if (data.length == 0) {
				$("#album-search-albums").html("<center><i>No results</i></center>");
				$("#album-search-status").html("No results.");
				$("#album-search-count").html("0 albums");
				return;
			}
			var _cf = templates.contentFlow.clone();
			var count = 0;
			var imgs = new Array();
			for (var album in data) {
				var entry = templates.albumResult.clone();
				var title = data[album].album;
				if (!title) { title = "<i>No Album</i>"; }
				$("span", entry).html(title);
				$("img", entry).attr("src", getAlbumArtUrl("", data[album].album, "", 64));
				$("a", entry).attr("href", "#SelectRequest/album/" + uriencode(data[album].album));
				entry.appendTo("#album-search-albums");
				imgs[album] = new Image(200,200);
			}
			waiting_for = imgs.length;
			for (var album in data) {
				imgs[album].onload = function() {
					waiting_for--;
					console.log("Waiting for: " + waiting_for);
					if (waiting_for == 0) {
						$("#cf-loading").remove();
						ajax_cf.init();
					}
				}
				var title = data[album].album;
				if (!title) { title = "<i>No Album</i>"; }
				imgs[album].src = getAlbumArtUrl("",data[album].album,"",200);
				album_art = $("<a class=\"item\"></a>").attr("href","#SelectRequest/album/" + uriencode(data[album].album)).append($("<img class=\"content\" />").attr("src",imgs[album].src)).append($("<span class=\"caption\"></span>").html(title));
				$(".flow", _cf).append(album_art);
				count++;
			}
			_cf.appendTo(".cf-container");
			ajax_cf = new ContentFlow('cf',{maxItemHeight: 200});
			$("#album-search-status").html("Showing Albums matching '" + title + "'");
			if (count == 1) {
				$("#album-search-count").html("One album");
			} else {
				$("#album-search-count").html(count + " albums");
			}
		}
	);
}

function doAlbumSearch() {
	$.address.value("Albums/" + formencode($("#album-search-box").val()));
	return false;
}

function toggleCF() {
	$(".cf-container").slideToggle(300);
	$("#cf-padding").slideToggle(300);
}

/* Management Console */

function manageZapPlayer() {
	if (player){
		$.getJSON(
			getPath('mode=zap;value=' + player),
			function(data) { handlePlayerStateRequest(data); }
		);
	}
}

function managePurgeUser(user) {
	$.getJSON(
		getPath('mode=purge;who=' + user),
		function(data) { handlePlayerStateRequest(data); }
	);
}

function manageScanDirectory() {
	var path = $("#manage-scan-directory").val();
	$.getJSON(
		getPath('mode=scan;path=' + path),
		function(data) {
			showMessage("Scan Complete","Directory scanning of '" + path + "' has finished.");
		}
	);
}

$.address.change(function(e) {pageLoadChange(e.value);});
