goog.require('goog.dom');
goog.require('goog.net.XhrIo');
goog.require('goog.ui.TableSorter');
goog.require('goog.ui.Slider');
goog.require('goog.ui.Component');
goog.require('goog.Throttle');
goog.require('goog.Timer');
goog.require('goog.async.Delay');

playlist_pane = 0;
vc_modifiable = false;
currentUser = '';
rem_time = 0;
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
	goog.net.XhrIo.send(
			jsonSource + '?mode=' + mode,
			function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function zapPlayer(player) {
	if (player){
		goog.net.XhrIo.send(
			jsonSource + '?mode=zap;value=' + '"' + player +'"',
			function () {handlePlayerStateRequest(this.getResponseJson());}
		);
	}
}

function login() {
	goog.net.XhrIo.send(
		'www-data/auth',
		function () {playerStateRequest();}
	);
}

function setVolume(value) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
			jsonSource + '?mode=volume;value=' + value,
			function () {handlePlayerStateRequest(this.getResponseJson());}
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
		goog.net.XhrIo.send(
				jsonSource + '?mode=search;field='+field+';value='+value,
				function () {
					goog.dom.$('result_title').innerHTML = 'Search for "' + value + '" in ' + field;
					fillResultTable(this.getResponseJson());
					showVoting();
				}
		);
	}
}

function selectRequest(field, value)
{
	goog.net.XhrIo.send(
			jsonSource + '?mode=select;field='+field+';value='+value,
			function () {
				goog.dom.$('result_title').innerHTML = 'Select on ' + field;
				fillResultTable(this.getResponseJson());
				showVoting();
			}
	);
}

function startPlayingTimer() {
	var tim = new goog.Timer(1000);
	tim.start();
	goog.events.listen(tim, goog.Timer.TICK, function () {updatePlayingTime()});
}

function statsRequest(who)
{
	this.songIDs = [];
	goog.net.XhrIo.send(
			jsonSource+'?mode=stats;who='+who,
			function() {
				goog.dom.$('result_title').innerHTML = 'A bit of statistics for ' + (who === '' ? "everyone" : who) + "...";
				fillStatsTable(this.getResponseJson());
				hideVoting();
			}
	);
}

function updatePlayingTime()
{
	if(rem_time > 0) goog.dom.$('playingTime').innerHTML = readableTime(--rem_time);
}

function startPlayerStateTimer () {
	playerStateRequest();
	var timer = new goog.Timer(15000);
	timer.start();
	goog.events.listen(timer, goog.Timer.TICK, function () {playerStateRequest()});
}

function playerStateRequest () {
	goog.net.XhrIo.send(
		jsonSource,
		function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function handlePlayerStateRequest (json) {
	if (json.who) updateCurrentUser(json.who);

	// skip link
	if (json.can_skip) goog.dom.$('skip_link').style.visibility = 'visible';
	else goog.dom.$('skip_link').style.visibility = 'hidden';
	// Admin Dequeue && zap
	if (json.is_admin){
		goog.dom.$('purgeuser').style.visibility = 'visible';
		goog.dom.$('zap').style.visibility = 'visible';
	}
	else {
		goog.dom.$('purgeuser').style.visibility = 'hidden';
		goog.dom.$('zap').style.visibility = 'hidden';
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
		goog.dom.$('loginbox').innerHTML = 'welcome ' + who;
	} else goog.dom.$('loginbox').innerHTML = '<a href="www-data/auth">Log in</a>';
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
	goog.dom.$('playlist').innerHTML = tableBuilder(whole_template, list_template, json_items) + time;
	fillPurgeDropDown(dropdown);
}

function fillPurgeDropDown(options)
{
	var purgelist = goog.dom.$('user');
	purgelist.options.length = 0;
	purgelist.options.add(new Option("Pick one",''));
	for (var i in options)
	{
		purgelist.options.add(new Option(options[i],options[i]));
	}
}

function updatePlaylistSelector(who) {
	if (who) goog.net.XhrIo.send(
		jsonSource + '?mode=playlists;who='+who,
		function() {
			var json = this.getResponseJson();
			var selector = goog.dom.$('playlistchooser');
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
		if (title) goog.net.XhrIo.send(
			jsonSource + '?mode=create_playlist;title=' + title,
			function() {
				//var json = this.getResponseJson();
				updatePlaylistSelector(currentUser);
			}
		);
		else updatePlaylistSelector(currentUser);
	} else if (playlist != 0) { // show a playlist
		playerStateRequest();
		goog.net.XhrIo.send(
			jsonSource + '?mode=playlist_contents;playlist_id=' + playlist,
			function() {
				playlist_pane = playlist;
				goog.dom.$('playlist_action').innerHTML = '<a href="javascript:enqueuePlaylist()"><img src="www-data/icons/add.png" alt="" /> enqueue playlist</a> <br /> <a href="javascript:enqueuePlaylistShuffled(10)"><img src="www-data/icons/sport_8ball.png" alt="" /> enqueue 10 random songs</a>';
				goog.dom.$('playlist_remove').innerHTML = '<a href="javascript:deletePlaylist()"><img src="www-data/icons/bomb.png" alt="" /> delete playlist</a>';
				showPlaylist(this.getResponseJson());
			}
		);
	} else { // show the queue
		playlist_pane = 0;
		playerStateRequest();
		// reset the dropdown to "Queue"
		goog.dom.$('playlistchooser').selectedIndex = 0;
		goog.dom.$('playlist_action').innerHTML = '<a href="javascript:shuffleVotes()"><img src="www-data/icons/sport_8ball.png" alt="" /> shuffle my votes</a>';
		goog.dom.$('playlist_remove').innerHTML = '<a href="javascript:purgeSongs(currentUser)"><img src="www-data/icons/disconnect.png" alt="" /> clear my votes</a>';
	}
}

function playlistRequest (who) {
	goog.net.XhrIo.send(
		jsonSource + '?mode=playlists;who=' + who,
		function() {
			hideVoting();
			goog.dom.$('result_title').innerHTML = (who === "" ? "All" : who + "'s") + " playlists";
			var json = this.getResponseJson();
			var list = "<ul>";
			for (var i in json) {
				list += '<li><a href="javascript:playlistTableRequest('
					+ json[i].playlist_id + ',' + "\'" + json[i].title + "\'" + ')">' + json[i].title + '</a> by '
					+ json[i].who + '</li>';
			}
			list += "</ul>";
			goog.dom.$('songresults').innerHTML = list;
		}
	);
}

function playlistTableRequest(playlist_id,title,who) {
	goog.net.XhrIo.send(
		jsonSource + '?mode=playlist_contents;playlist_id=' + playlist_id,
		function() {
			showVoting();
			goog.dom.$('result_title').innerHTML = 'Contents of playlist "' + title + '"';
			fillResultTable(this.getResponseJson());
		}
	);
}

function deletePlaylist () {
	var answer = confirm("Really delete this playlist?");
	if (answer) {
		goog.net.XhrIo.send(
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
		goog.net.XhrIo.send(
			jsonSource + '?mode=playlist_contents;playlist_id=' + playlist_pane,
			function() {
				var json = shuffle(this.getResponseJson());
				var block = "";
				for (var i = 0; i < json.length && i < amount; i++) {
					block += "song_id=" + json[i].song_id + ";";
				}
				if (block != ""){
					goog.net.XhrIo.send(
							jsonSource + '?mode=vote;' + block,
							function() {handlePlayerStateRequest(this.getResponseJson());selectPlaylist(0);}
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
		goog.net.XhrIo.send(
			jsonSource + '?mode=playlist_contents;playlist_id=' + playlist_pane,
			function() {
				var json = this.getResponseJson();
				var block = "";
				for (var i in json) {
					block += "song_id=" + json[i].song_id + ";";
				}
				if (block != ""){
					goog.net.XhrIo.send(
							jsonSource + '?mode=vote;' + block,
							function() {handlePlayerStateRequest(this.getResponseJson());}
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
	goog.dom.$('playlist').innerHTML = tableBuilder(playlist_template, item_template, json_items) + time;
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

	goog.dom.$('currentsong').innerHTML = Mustache.to_html(now_template, json_item) + Mustache.to_html(pane_template,player_model);
	goog.dom.$('zap').innerHTML = '<a href="javascript:zapPlayer(\'' + selected_player + '\')"><img src="www-data/icons/wrench_orange.png" alt="zap"/> Zap The Player</a>';
}

function changePlayer(player_id) {
	goog.net.XhrIo.send(
		jsonSource + '?mode=change_player;player_id=' + player_id,
		function() {
			handlePlayerStateRequest(this.getResponseJson());
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
	goog.net.XhrIo.send(
		jsonSource + '?mode=history;amount='+amount+';who='+who,
		function() {
			var text = amount + ' previously played songs';
			if (who) text += ' by ' + who;
			goog.dom.$('result_title').innerHTML = text
			// TODO: make me mighty
			fillResultTable(this.getResponseJson());
			showVoting();
		}
	);
}

function loadRecentSongs(amount) {
	goog.net.XhrIo.send(
		jsonSource + '?mode=recent;amount=' + amount,
		function () {
			goog.dom.$('result_title').innerHTML = amount + ' Recently Added Songs';
			fillResultTable(this.getResponseJson());
			showVoting();
		}
	);
}

function loadRandomSongs(amount) {
	goog.net.XhrIo.send(
		jsonSource + '?mode=random;amount=' + amount,
		function () {
			goog.dom.$('result_title').innerHTML = amount + ' Random Songs';
			fillResultTable(this.getResponseJson());
			showVoting();
		}
	);
}

function loadVotesFromVoter(voter){
	goog.net.XhrIo.send(
		jsonSource + '?mode=byvoter;voter=' + voter,
		function(){
			goog.dom.$('result_title').innerHTML = voter + "'s Songs";
			fillResultTable(this.getResponseJson());
			goog.dom.$('userstats').innerHTML = '<a href="javascript:statsRequest(\'' + voter + '\')">' + voter + '\'s stats</a>';
			showVoting();
		}
	);
}

function getSongDetails(song_id) {
	this.songIDs = [song_id];
	goog.net.XhrIo.send(
		jsonSource + '?mode=get_details;song_id='+song_id,
		function() {
			var json = this.getResponseJson().song;
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
			goog.dom.$('songresults').innerHTML = tableBuilder(table_template, row_template, [json_item]);
			goog.dom.$('result_title').innerHTML = "Details for this song";
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
	goog.dom.$('songresults').innerHTML = tableBuilder(table_template, row_template, json_items);
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
	goog.dom.$('songresults').innerHTML = tableBuilder(table_template, row_template, json_items);
	goog.dom.$('userstats').innerHTML = "";
}

function fillResultTable(json) {
	this.songIDs = [];
	var json_items = [];
	var table_template =
	'<table id="result_table"><thead><tr><th>vote</th>'
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
	goog.dom.$('songresults').innerHTML = tableBuilder(table_template, row_template, json_items);

	var component = new goog.ui.TableSorter();
	component.decorate(goog.dom.$('result_table'));
	component.setDefaultSortFunction(goog.ui.TableSorter.alphaSort);
	component.setSortFunction(1, goog.ui.TableSorter.numericSort);
	component.setSortFunction(5, timeSorter);
}

/* table_template should contain {{#items}}{{{.}}}{{/items}} */
function tableBuilder(table_template, row_template, items) {
	var rendered_items = { items: _.map(items, function(item){ return Mustache.to_html(row_template, item) }) };
	return Mustache.to_html(table_template,rendered_items);
};

timeSorter = function(a, b) {
	var a_ = a.split(":");
	a = 0;
	for (var i=0; i<a_.length; i++) {
		a = a * 100 + parseFloat(a_[i]);
	}
	a_ = b.split(":");
	b = 0;
	for (var i=0; i<a_.length; i++) {
		b = b * 100 + parseFloat(a_[i]);
	}
	return parseFloat(a) - parseFloat(b);
};

function voteSong(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	if (playlist_pane != 0) {
		goog.net.XhrIo.send(
			jsonSource + '?mode=add_to_playlist;playlist_id='
			+ playlist_pane + ';song_id=' + song_id,
			function () {showPlaylist(this.getResponseJson());}
		);
	} else {
		goog.net.XhrIo.send(
			jsonSource + '?mode=vote;song_id=' + song_id,
			function () {handlePlayerStateRequest(this.getResponseJson());}
		);
	}
}

function unvoteSong(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	if (playlist_pane != 0) {
		goog.net.XhrIo.send(
			jsonSource + '?mode=remove_from_playlist;playlist_id='
			+ playlist_pane + ';song_id=' + song_id,
			function () {showPlaylist(this.getResponseJson());}
		);
	} else {
		goog.net.XhrIo.send(
			jsonSource + '?mode=unvote;song_id=' + song_id,
			function () {handlePlayerStateRequest(this.getResponseJson());}
		);
	}
}

function shuffleVotes() {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
			jsonSource + '?mode=shuffle_votes',
			function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function voteToTop(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
			jsonSource + '?mode=vote_to_top;song_id=' + song_id,
			function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function purgeSongs(user) {
	goog.net.XhrIo.send(
		jsonSource + '?mode=purge;who=' + user,
		function () {
			handlePlayerStateRequest(this.getResponseJson());
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
	goog.dom.$('volume').innerHTML = scale;
}

function qsencode(str) {
	str = str.replace(/\\/, '\\\\');
	str = str.replace(/\'/, '\\\'');
	str = str.replace(/\"/, '\\\"');
	str = str.replace('&', '%2526');
	str = str.replace('+', '%252B');
	str = str.replace('#', '%2523');
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
	goog.net.XhrIo.send(
		jsonSource + '?mode=vote;song_id=' + randomSong,
		function() {handlePlayerStateRequest(this.getResponseJson());}
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
		goog.net.XhrIo.send(
				jsonSource + command + block,
				function() {
					if (playlist_pane) showPlaylist(this.getResponseJson());
					else handlePlayerStateRequest(this.getResponseJson());
				}
		);
	}
}
function hideVoting() {
	goog.dom.$('voterand').style.visibility = "hidden";
	goog.dom.$('voteall').style.visibility = "hidden";
}
function showVoting() {
	goog.dom.$('voterand').style.visibility = "visible";
	goog.dom.$('voteall').style.visibility = "visible";
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
