playlist_pane = 0;
vc_modifiable = false;
currentUser = '';
rem_time = 0;
stateTimer = 0;
playingTimer = 0;
jsonSource = '/acoustics/json.pl';

function readableTime(length)
{
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

function sendPlayerCommand(mode) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	$.getJSON(
			jsonSource + '?mode=' + mode,
			function (data) {handlePlayerStateRequest(data);}
	);
}

function zapPlayer(player) {
	if (player){
		$.getJSON(
			jsonSource + '?mode=zap;value=' + '"' + player +'"',
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function login() {
	$.getJSON(
		'www-data/auth',
		function () {playerStateRequest();}
	);
}

function setVolume(value) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	$.getJSON(
			jsonSource + '?mode=volume;value=' + value,
			function (data) {handlePlayerStateRequest(data);}
	);
}

function searchRequest(field, value)
{
	if (field == "stats"){
		statsRequest(value);
	} else if (field == "playlist") {
		playlistRequest(value);
	} else if (field == "history") {
		loadPlayHistory(25, value);
	} else {
		$.getJSON(
				jsonSource + '?mode=search;field='+field+';value='+value,
				function (data) {
					$('#result_title').html('Search for "' + value + '" in ' + field);
					fillResultTable(data);
					showVoting();
				}
		);
	}
}

function selectRequest(field, value)
{
	$.getJSON(
			jsonSource + '?mode=select;field='+field+';value='+value,
			function (data) {
				$('#result_title').html('Select on ' + field);
				fillResultTable(data);
				showVoting();
			}
	);
}

function startPlayingTimer() {
	if (playingTimer) clearInterval(playingTimer);
	playingTimer = setInterval(function() { updatePlayingTime() }, 1000);
}

function statsRequest(who)
{
	this.songIDs = [];
	$.getJSON(
			jsonSource+'?mode=stats;who='+who,
			function(data) {
				$('#result_title').html('A bit of statistics for ' + (who === '' ? "everyone" : who) + "...");
				fillStatsTable(data);
				hideVoting();
			}
	);
}

function updatePlayingTime()
{
	if(rem_time > 0) $('#playingTime').html(readableTime(--rem_time));
}

function startPlayerStateTimer () {
	playerStateRequest();
	if (stateTimer) clearInterval(stateTimer);
	stateTimer = setInterval(function() { playerStateRequest() }, 15000);
}

function playerStateRequest () {
	$.getJSON(
		jsonSource,
		function (data) {handlePlayerStateRequest(data);}
	);
}

function handlePlayerStateRequest (json) {
	if (json.who) updateCurrentUser(json.who);

	// skip link
	if (json.can_skip) $('#skip_link').show();
	else $('#skip_link').hide();
	// Admin Dequeue && zap
	if (json.is_admin) {
		$('#purgeuser').show();
		$('#zap').show();
	}
	else {
		$('#purgeuser').hide();
		$('#zap').hide();
	}

	updateNowPlaying(json.now_playing, json.player, json.selected_player, json.players);
	if (json.player) updateVolumeScale(json.player.volume);
	if (json.playlist && playlist_pane == 0) updatePlaylist(json.playlist);
}

function updateCurrentUser (who) {
	if (who) {
		// update the playlist selector on the first time we have a valid user
		if (!currentUser) updatePlaylistSelector(who);
		currentUser = who;
		$('#loginbox').html('welcome ' + who);
	} else $('#loginbox').html('<a href="www-data/auth">Log in</a>');
}

function updatePlaylist(json)
{
	var totalTime = 0;
	var dropdown = [];
	var json_items = [];
	for (var item in json)
	{
		json_items.push({
			voted:(json[item].who && json[item].who.indexOf(currentUser) != -1),
			song_id : json[item].song_id,
			coded_song_id : qsencode(json[item].song_id),
			title: titleOrPath(json[item]),
			artist: json[item].artist,
			coded_artist: qsencode(json[item].artist),
			time: readableTime(json[item].length),
			voters: json[item].who.length
		});
		totalTime = totalTime + parseInt(json[item].length);
		var voters = [];
		for (var voter in json[item].who)
		{
			var index = json[item].who[voter];
			if (dropdown.indexOf(index) == -1)
			{
				dropdown.push(index);
			}
		}
	}
	var list_template =
	'<li>{{#voted}}<a title="Remove your vote for this" href="javascript:unvoteSong({{song_id}})">'
	+'<img src="www-data/icons/delete.png" alt="unvote"/></a>&nbsp;'
	+ '<a title="Vote To Top" href="javascript:voteToTop({{song_id}})">'
	+ '<img src="www-data/icons/lightning_go.png" alt="vote to top"/></a>{{/voted}}'
	+ '{{^voted}}<a title="Vote for this" href="javascript:voteSong({{song_id}})"><img src="www-data/icons/add.png" alt="vote"/></a>{{/voted}}'
	+ '&nbsp;<a title="See who voted for this" href="javascript:getSongDetails({{{coded_song_id}}})">{{title}}</a> by '
	+ '<a href="javascript:selectRequest(\'artist\',\'{{{coded_artist}}}\')">{{artist}}</a>'
	+ '&nbsp;({{time}}) ({{voters}})</li>';
	var whole_template = '<ul>{{#items}}{{{.}}}{{/items}}</ul>';
	var time = 'Total Time: '+readableTime(totalTime);
	$('#playlist').html(tableBuilder(whole_template, list_template, json_items) + time);
	fillPurgeDropDown(dropdown);
}

function fillPurgeDropDown(options)
{
	var purgelist = document.getElementById('user');
	purgelist.options.length = 0;
	purgelist.options.add(new Option("Pick one",''));
	for (var i in options)
	{
		purgelist.options.add(new Option(options[i],options[i]));
	}
}

function updatePlaylistSelector(who) {
	if (who) $.getJSON(
		jsonSource + '?mode=playlists;who='+who,
		function(json) {
			var selector = document.getElementById('playlistchooser');
			selector.options.length = 0;
			selector.options.add(new Option('Queue', 0));
			selector.options.add(new Option('New playlist...', -1));
			selector.options.add(new Option('---', 0));
			for (var i in json) {
				selector.options.add(
					new Option(json[i].title, json[i].playlist_id)
				);
			}
		}
	);
}

function selectPlaylist(playlist) {
	if (playlist == -1) { // make a new playlist
		var title = prompt(
			"Name your playlist!",
			"experiment " + Math.floor(Math.random()*10000)
		);
		if (title) $.getJSON(
			jsonSource + '?mode=create_playlist;title=' + title,
			function() {
				updatePlaylistSelector(currentUser);
			}
		);
		else updatePlaylistSelector(currentUser);
	} else if (playlist != 0) { // show a playlist
		playerStateRequest();
		$.getJSON(
			jsonSource + '?mode=playlist_contents;playlist_id=' + playlist,
			function(data) {
				playlist_pane = playlist;
				$('#playlist_action').html('<a href="javascript:enqueuePlaylist()"><img src="www-data/icons/add.png" alt="" /> enqueue playlist</a> <br /> <a href="javascript:enqueuePlaylistShuffled(10)"><img src="www-data/icons/sport_8ball.png" alt="" /> enqueue 10 random songs</a>');
				$('#playlist_remove').html('<a href="javascript:deletePlaylist()"><img src="www-data/icons/bomb.png" alt="" /> delete playlist</a>');
				showPlaylist(data);
			}
		);
	} else { // show the queue
		playlist_pane = 0;
		playerStateRequest();
		// reset the dropdown to "Queue"
		document.getElementById('playlistchooser').selectedIndex = 0;
		$('#playlist_action').html('<a href="javascript:shuffleVotes()"><img src="www-data/icons/sport_8ball.png" alt="" /> shuffle my votes</a>');
		$('#playlist_remove').html('<a href="javascript:purgeSongs(currentUser)"><img src="www-data/icons/disconnect.png" alt="" /> clear my votes</a>');
	}
}

function playlistRequest (who) {
	$.getJSON(
		jsonSource + '?mode=playlists;who=' + who,
		function(json) {
			hideVoting();
			$('#result_title').html((who === "" ? "All" : who + "'s") + " playlists");
			var list_template = '<ul>{{#items}}{{{.}}}{{/items}}</ul>';
			var item_template = '<li><a href="javascript:playlistTableRequest({{playlist_id}},\'{{{codedtitle}}}\')">{{title}}</a> by {{who}}</li>';
			_.each(json, function(item) { item.codedtitle = qsencode(item.title) });
			$('#songresults').html(tableBuilder(list_template, item_template, json));
		}
	);
}

function playlistTableRequest(playlist_id,title,who) {
	$.getJSON(
		jsonSource + '?mode=playlist_contents;playlist_id=' + playlist_id,
		function(data) {
			showVoting();
			$('#result_title').html('Contents of playlist "' + title + '"');
			fillResultTable(data);
		}
	);
}

function deletePlaylist () {
	var answer = confirm("Really delete this playlist?");
	if (answer) {
		$.getJSON(
			jsonSource + '?mode=delete_playlist;playlist_id=' + playlist_pane,
			function() {
				updatePlaylistSelector(currentUser);
				selectPlaylist(0);
			}
		);
	}
}

function enqueuePlaylistShuffled (amount) {
	if (playlist_pane != 0) {
		$.getJSON(
			jsonSource + '?mode=playlist_contents;playlist_id=' + playlist_pane,
			function(json) {
				json = shuffle(json);
				var block = "";
				for (var i = 0; i < json.length && i < amount; i++) {
					block += "song_id=" + json[i].song_id + ";";
				}
				if (block != ""){
					$.getJSON(
							jsonSource + '?mode=vote;' + block,
							function(data) {handlePlayerStateRequest(data);selectPlaylist(0);}
					);
				}
			}
		);
	} else {
		alert('should not happen (enqueuePlaylistShuffled)!');
	}

}

function enqueuePlaylist () {
	if (playlist_pane != 0) {
		$.getJSON(
			jsonSource + '?mode=playlist_contents;playlist_id=' + playlist_pane,
			function(json) {
				var block = "";
				for (var i in json) {
					block += "song_id=" + json[i].song_id + ";";
				}
				if (block != ""){
					$.getJSON(
							jsonSource + '?mode=vote;' + block,
							function(data) {handlePlayerStateRequest(data);}
					);
				}
				// go back to the queue
				selectPlaylist(0);
			}
		);
	} else {
		alert('should not happen (enqueuePlaylist)!');
	}
}

function showPlaylist(json) {
	var totalTime = 0;
	var playlist_template = '<ul>{{#items}}{{{.}}}{{/items}}</ul>';
	var item_template =
	'<li><a title="Remove from your playlist" href="javascript:unvoteSong({{song_id}})">'
	+ '<img src="www-data/icons/delete.png" alt="unvote" /></a> '
	+ '<a title="View Song Details" href="javascript:getSongDetails({{coded_song_id}})">{{title}}</a> by '
	+ '<a href="javascript:selectRequest(\'artist\', \'{{{coded_artist}}}\')">{{artist}}</a>&nbsp;({{time}})';
	var json_items = [];
	for (var item in json) {
		json_items.push({
			title: titleOrPath(json[item]),
			song_id: json[item].song_id,
			coded_song_id: qsencode(json[item].song_id),
			artist: json[item].artist,
			coded_artist: qsencode(json[item].artist),
			time: readableTime(json[item].length)
		});
		totalTime += parseInt(json[item].length);
	}
	var time = 'Total Time: '+readableTime(totalTime);
	$('#playlist').html(tableBuilder(playlist_template, item_template, json_items) + time);
}

function updateNowPlaying(json, player, selected_player, players_list) {
	rem_time = json && parseInt(player.song_start) + parseInt(json.length) - Math.round(((new Date().getTime())/1000));
	if (rem_time < 0) rem_time = 0;
	var json_item = {
		exist: !!json,
		song_id: json && json.song_id,
		voted: json && (json.who && json.who.indexOf(currentUser) != -1 && playlist_pane == 0),
		title: json && titleOrPath(json),
		artist: json && json.artist,
		coded_artist: json && qsencode(json.artist),
		album: json && json.album,
		coded_album: json && qsencode(json.album),
		length: json && readableTime(json.length),
		remaining: readableTime(rem_time)
	};

	var player_model = {
		pane: (playlist_pane == 0),
		players: _.map(players_list,function(item){ return { player: item, selected: (selected_player == item) } })
	};

	var now_template =
	'{{#exist}}{{#voted}}<a href="javascript:unvoteSong({{song_id}})"><img src="www-data/icons/delete.png" alt="unvote" /></a>{{/voted}}'
	+ '{{^voted}}<a href="javascript:voteSong({{song_id}})"><img src="www-data/icons/add.png" alt="vote" /></a>{{/voted}}'
	+ ' <a href="javascript:getSongDetails({{song_id}})">{{title}}</a> by <a href="javascript:selectRequest(\'artist\'\'{{{coded_artist}}}\')">{{artist}}</a>'
	+ '{{#album}} (from <a href="javascript:selectRequest(\'album\',\'{{{coded_album}}}\')">{{album}}</a>){{/album}}'
	+ '&nbsp;({{length}})&nbsp;(<span id="playingTime">{{remaining}}</span> remaining){{/exist}}{{^exist}}nothing playing{{/exist}}';

	var pane_template =
	'{{#pane}}<div><br /><form id="player" action=""> Player: <select onChange="javascript:changePlayer(this.value); return false;" id="player">'
	+ '{{#players}}<option value="{{player}}" {{#selected}}selected="selected"{{/selected}}>{{player}}</option>{{/players}}'
	+ '</select></form></div>{{/pane}}';

	$('#currentsong').html(Mustache.to_html(now_template, json_item) + Mustache.to_html(pane_template,player_model));
	$('#zap').html('<a href="javascript:zapPlayer(\'' + selected_player + '\')"><img src="www-data/icons/wrench_orange.png" alt="zap"/> Zap The Player</a>');
}

function changePlayer(player_id) {
	$.getJSON(
		jsonSource + '?mode=change_player;player_id=' + player_id,
		function(data) {
			handlePlayerStateRequest(data);
		}
	);
}

function lastLinkSong(artist, title)
{
	return '<a href="http://last.fm/music/'+artist+'/_/'+title+'" target="_new"><img class="icon" src="www-data/icons/as.png"></a>';
}

function lastLinkAlbum(artist, album)
{
	return '<a href="http://last.fm/music/'+artist+'/'+album+'" target="_new"><img class="icon" src="www-data/icons/as.png"></a>';
}

function lastLinkArtist(artist)
{
	return '<a href="http://last.fm/music/'+artist+'" target="_new"><img class="icon" src="www-data/icons/as.png"></a>';
}

function wikiLinkArtist(artist)
{
	return '<a href="http://en.wikipedia.org/wiki/'+artist+'_(band)" target="_new"><img class="icon" src="www-data/icons/wiki.png"></a>';
}

function wikiLinkAlbum(album)
{
	return '<a href="http://en.wikipedia.org/wiki/'+album+'_(album)" target="_new"><img class="icon" src="www-data/icons/wiki.png"></a>';
}

function wikiLinkSong(title)
{
	return '<a href="http://en.wikipedia.org/wiki/'+title+'_(song)" target="_new"><img class="icon" src="www-data/icons/wiki.png"></a>';
}

function loadPlayHistory(amount, who) {
	$.getJSON(
		jsonSource + '?mode=history;amount='+amount+';who='+who,
		function(data) {
			var text = amount + ' previously played songs';
			if (who) text += ' by ' + who;
			$('#result_title').html(text);
			// TODO: make me mighty
			fillResultTable(data);
			showVoting();
		}
	);
}

function loadRecentSongs(amount) {
	$.getJSON(
		jsonSource + '?mode=recent;amount=' + amount,
		function (data) {
			$('#result_title').html(amount + ' Recently Added Songs');
			fillResultTable(data);
			showVoting();
		}
	);
}

function loadRandomSongs(amount) {
	$.getJSON(
		jsonSource + '?mode=random;amount=' + amount,
		function (data) {
			$('#result_title').html(amount + ' Random Songs');
			fillResultTable(data);
			showVoting();
		}
	);
}

function loadVotesFromVoter(voter){
	$.getJSON(
		jsonSource + '?mode=byvoter;voter=' + voter,
		function(data){
			$('#result_title').html(voter + "'s Songs");
			fillResultTable(data);
			$('#userstats').html('<a href="javascript:statsRequest(\'' + voter + '\')">' + voter + '\'s stats</a>');
			showVoting();
		}
	);
}

function getSongDetails(song_id) {
	this.songIDs = [song_id];
	$.getJSON(
		jsonSource + '?mode=get_details;song_id='+song_id,
		function(json) {
			json = json.song;
			var table_template =
			'<table id="result_table"><thead><tr><th>Vote</th><th>Track</th><th>Title</th><th>Album</th>'
			+ '<th>Artist</th><th>Length</th></tr></thead><tbody>{{#items}}{{{.}}}{{/items}}</tbody></table>';
			var row_template =
			'<tr><td style="text-align: center"><a href="javascript:voteSong({{song_id}})"><img src="www-data/icons/add.png" alt="vote"/></a></td>'
			+ '<td>{{track}}</td><td><a href="javascript:selectRequest(\'title\',\'{{{coded_title}}}\')">{{title}}</a>{{{last_song}}}{{{wiki_song}}}</td>'
			+ '<td><a href="javascript:selectRequest(\'album\',\'{{{coded_album}}}\')">{{album}}</a>{{{last_album}}}{{{wiki_album}}}</td>'
			+ '<td><a href="javascript:selectRequest(\'artist\',\'{{{coded_artist}}}\')">{{artist}}</a>{{{last_artist}}}{{{wiki_artist}}}</td>'
			+ '<td>{{time}}</td></tr><tr><th colspan=2>Path:</th><td colspan=4>{{path}}</td></tr>'
			+ '<tr><th colspan=2>Voters:</th><td colspan=4>{{#voters}}<a href=javascript:loadVotesFromVoter("{{.}}")>{{.}}</a>&nbsp;{{/voters}}{{^voters}}no one{{/voters}}</td></tr>';
			var json_item = {
				track: json.track,
				song_id: json.song_id,
				title: json.title,
				coded_title: qsencode(json.title),
				last_song: lastLinkSong(json.artist, json.title),
				wiki_song: wikiLinkSong(json.title),
				album: json.album,
				coded_album: qsencode(json.album),
				last_album: lastLinkAlbum(json.artist, json.album),
				wiki_album: wikiLinkAlbum(json.album),
				artist: json.artist,
				coded_artist: qsencode(json.artist),
				last_artist: lastLinkArtist(json.artist),
				wiki_artist: wikiLinkArtist(json.artist),
				time: readableTime(json.length),
				path: json.path,
				voters: json.who
			};
			$('#songresults').html(tableBuilder(table_template, row_template, [json_item]));
			$('#result_title').html("Details for this song");
			hideVoting();
		}
	);
}

function fillHistoryTable(json) {
	this.songIDs = [];
	var json_items = [];
	var table_template = '<table id="result_table"><thead><tr><th>Vote</th><th>Name</th><th>Played at</th></tr></thead><tbody>{{#items}}{{{.}}}{{/items}}</tbody></table>';
	var row_template =
	'<tr><td style="text-align: center"><a href="javascript:voteSong({{song_id}})"><img src="www-data/icons/add.png alt=""/></a></td>'
	+ '<td><a href="javascript:getSongDetails({{song_id}})">{{pretty_name}}</a></td><td>{{time}}</td></tr>';
	for (var item in json)
	{
		json_items.push({
			song_id: json[item].song_id,
			pretty_name: json[item].pretty_name,
			time: json[item].time
		});
		this.songIDs.push(json[item].song_id);
	}
	$('#songresults').html(tableBuilder(table_template, row_template, json_items));
}

function fillStatsTable(json) {
	var table_template = '<table id="result_table">'
			+'<tr><th>Total Songs</th><td>{{total_songs}}</td></tr>'
			+'<tr><th colspan=2>Most Played Artists:</th></tr>{{#items}}{{{.}}}{{/items}}</table>';
	var row_template = '<tr><td><a href="javascript:selectRequest(\'artist\',{{{artist}}})">{{artist}}</a></td><td>{{count}}</td><tr>';
	var json_items = [];
	for(var item in json.top_artists)
	{
		json_items.push({
			artist: json.top_artists[item].artist,
			count: json.top_artists[item].count
		});
	}
	$('#songresults').html(tableBuilder(table_template, row_template, json_items));
	$('#userstats').html("");
}

function fillResultTable(json) {
	this.songIDs = [];
	var json_items = [];
	var table_template =
	'<table id="result_table" class="tablesorter"><thead><tr><th>vote</th>'
	+ '<th>Track</th>'
	+ '<th>Title</th>'
	+ '<th>Album</th>'
	+ '<th>Artist</th><th>Length</th></tr></thead><tbody>'
	+ '{{#items}}{{{.}}}{{/items}}</tbody></table>';
	var row_template =
	'<tr><td style="text-align: center"><a href="javascript:voteSong({{song_id}})">'
	+ '<img src="www-data/icons/add.png" alt=vote"/></a></td>'
	+ '<td>{{track}}</td><td class="datacol"><a href="javascript:getSongDetails({{song_id}})">{{title}}</a></td>'
	+ '<td class="datacol"><a href="javascript:selectRequest(\'album\', \'{{{coded_album}}}\')">{{album}}</a></td>'
	+ '<td class="datacol"><a href="javascript:selectRequest(\'artist\', \'{{{coded_artist}}}\')">{{artist}}</a></td>'
	+ '<td>{{time}}</td></tr>';
	for (var item in json) {
		json_items.push({
			title: titleOrPath(json[item]),
			song_id: json[item].song_id,
			track: json[item].track,
			album: json[item].album,
			coded_album: qsencode(json[item].album),
			artist: json[item].artist,
			coded_artist: qsencode(json[item].artist),
			time: readableTime(json[item].length)
		});
		this.songIDs.push(json[item].song_id);
	};
	$('#songresults').html(tableBuilder(table_template, row_template, json_items));

	$("#result_table").tablesorter();
}

/* table_template should contain {{#items}}{{{.}}}{{/items}} */
function tableBuilder(table_template, row_template, items) {
	var rendered_items = { items: _.map(items, function(item){ return Mustache.to_html(row_template, item) }) };
	return Mustache.to_html(table_template,rendered_items);
};

function voteSong(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	if (playlist_pane != 0) {
		$.getJSON(
			jsonSource + '?mode=add_to_playlist;playlist_id='
			+ playlist_pane + ';song_id=' + song_id,
			function (data) {showPlaylist(data);}
		);
	} else {
		$.getJSON(
			jsonSource + '?mode=vote;song_id=' + song_id,
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function unvoteSong(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	if (playlist_pane != 0) {
		$.getJSON(
			jsonSource + '?mode=remove_from_playlist;playlist_id='
			+ playlist_pane + ';song_id=' + song_id,
			function (data) {showPlaylist(data);}
		);
	} else {
		$.getJSON(
			jsonSource + '?mode=unvote;song_id=' + song_id,
			function (data) {handlePlayerStateRequest(data);}
		);
	}
}

function shuffleVotes() {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	$.getJSON(
			jsonSource + '?mode=shuffle_votes',
			function (data) {handlePlayerStateRequest(data);}
	);
}

function voteToTop(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	$.getJSON(
			jsonSource + '?mode=vote_to_top;song_id=' + song_id,
			function (data) {handlePlayerStateRequest(data);}
	);
}

function purgeSongs(user) {
	$.getJSON(
		jsonSource + '?mode=purge;who=' + user,
		function (data) {
			handlePlayerStateRequest(data);
		}
	);
}

function updateVolumeScale(volume) {
	scale = '';
	for (var i = 1; i <= 11; i++) {
		scale += '<a ';
		if (Math.round(volume / 10)+1 == i) scale += 'style="color: red" ';
		scale += 'href="javascript:setVolume(' + ((i * 10) - 10) + ')">' + i + '</a> ';
	}
	$('#volume').html(scale);
}

function qsencode(str) {
	str = str.replace(/\\/g, '\\\\');
	str = str.replace(/\'/g, '\\\'');
	str = str.replace(/\"/g, '\\\"');
	str = str.replace(/&/g, '%2526');
	str = str.replace(/\+/g, '%252B');
	str = str.replace(/#/g, '%2523');
	return str;
}

function formencode(str) {
	str = str.replace('&', '%26');
	str = str.replace('+', '%2B');
	str = str.replace('#', '%23');
	return str;
}

function titleOrPath(json) {
	if(json.player) updateVolumeScale(json.player.volume);
	if (json.title) {
		return json.title;
	}
	else {
		var shortname = /^.*\/(.*)$/.exec(json.path);
		if (shortname) {
			return shortname[1];
		}
		else {
			return json.path;
		}
	}
}

function voteRandom() {
	var possible = this.songIDs.length;
	if (possible <= 0) {
		return;
	}
	var randomSong = this.songIDs[Math.floor(Math.random()*possible)];
	$.getJSON(
		jsonSource + '?mode=vote;song_id=' + randomSong,
		function(data) {handlePlayerStateRequest(data);}
	);
}
// ALL THE POWAR!
function voteAll() {
	var block = "";
	for (var i in this.songIDs) {
		block += "song_id=" + this.songIDs[i] + ";";
	}
	if (block != ""){
		var command = "?mode=vote;";
		if (playlist_pane) {
			command = "?mode=add_to_playlist;playlist_id=" + playlist_pane + ";";
		}
		$.getJSON(
				jsonSource + command + block,
				function(data) {
					if (playlist_pane) showPlaylist(data);
					else handlePlayerStateRequest(data);
				}
		);
	}
}
function hideVoting() {
	$('#voterand').hide();
	$('#voteall').hide();
}
function showVoting() {
	$('#voterand').show();
	$('#voteall').show();
}

function shuffle(array) {
	var tmp, current, top = array.length;

	if(top) while(--top) {
		current = Math.floor(Math.random() * (top + 1));
		tmp = array[current];
		array[current] = array[top];
		array[top] = tmp;
	}

	return array;
}
