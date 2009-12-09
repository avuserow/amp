goog.require('goog.dom');
goog.require('goog.net.XhrIo');
goog.require('goog.ui.TableSorter');
goog.require('goog.ui.Slider');
goog.require('goog.ui.Component');
goog.require('goog.Throttle');
goog.require('goog.Timer');
goog.require('goog.async.Delay');

vc_modifiable = false;
currentUser = '';

function readableTime(length)
{
	var seconds = length % 60;
	var minutes = Math.round(length / 60) % 60;
	var hours = Math.round(length / 3600);

	var result = "";
	if(hours > 0)
		result += hours+':';
	if(minutes >= 10)
		result += minutes+':';
	else if(minutes < 10 && hours > 0)
		result += '0'+minutes+':';
	else if(minutes < 10)
		result += minutes+':';
	if(seconds < 10)
		result += '0'+seconds;
	else
		result += seconds;
		return result;
	
}

function sendPlayerCommand(mode) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=' + mode,
			function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function setVolume(value) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=volume;value=' + value,
			function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function searchRequest(field, value)
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=search;field='+field+';value='+value,
			function () {
				goog.dom.$('result_title').innerHTML = 'Search on ' + field;
				fillResultTable(this.getResponseJson());
			}
	);
}

function selectRequest(field, value)
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=select;field='+field+';value='+value,
			function () {
				goog.dom.$('result_title').innerHTML = 'Select on ' + field;
				fillResultTable(this.getResponseJson());
			}
	);
}

function startPlayerStateTimer () {
	playerStateRequest();
	var timer = new goog.Timer(15000);
	timer.start();
	goog.events.listen(timer, goog.Timer.TICK, function () {playerStateRequest()});
}

function playerStateRequest () {
	goog.net.XhrIo.send(
		'/acoustics/json.pl',
		function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function handlePlayerStateRequest (json) {
	if (json.who) updateCurrentUser(json.who);
	updateNowPlaying(json.nowPlaying);
	if (json.playlist) updatePlaylist(json.playlist);
	if (json.player) updateVolumeScale(json.player.volume);
}

function updateCurrentUser (who) {
	if (who) {
		currentUser = who;
		goog.dom.$('loginbox').innerHTML = 'welcome ' + who;
	} else goog.dom.$('loginbox').innerHTML = '<a href="www-data/auth">Log in</a>';
}

function updatePlaylist(json)
{
	var totalTime = 0;
	list = '<ul>';
	for (var item in json)
	{
		list += '<li>';
		if (json[item].who && json[item].who.indexOf(currentUser) != -1) {
			list += '<a href="javascript:unvoteSong(' + json[item].song_id
				+ ')"><img src="www-data/icons/delete.png" alt="unvote" /></a> ';
		} else {
			list += '<a href="javascript:voteSong(' + json[item].song_id
				+ ')"><img src="www-data/icons/add.png" alt="vote" /></a> ';
		}
		list += '<a href="javascript:getSongDetails('+json[item].song_id+')">' + json[item].title
			+ '</a> by <a href="javascript:selectRequest(\'artist\', \''
			+ qsencode(json[item].artist) + '\')">' + json[item].artist
			+ '</a>'
			+ '&nbsp;(' + readableTime(json[item].length) +') ('+json[item].who.length+')</li>';
		totalTime = totalTime + parseInt(json[item].length);
	}
	list += '</ui>';
	list += 'Total Time: '+readableTime(totalTime);
	goog.dom.$('playlist').innerHTML = list;
}

function updateNowPlaying(json) {
	if (json) {
		nowPlaying = '<a href="javascript:getSongDetails('+json.song_id+')">' + json.title
			+ '</a> by <a href="javascript:selectRequest(\'artist\', \''
			+ json.artist + '\')">' + json.artist + '</a>';
		if (json.album) {
			nowPlaying += ' (from <a href="javascript:selectRequest(\'album\', \''
				+ json.album + '\')">' + json.album + '</a>)';
		}
		nowPlaying += '&nbsp;('+readableTime(json.length)+')';
	} else {
		nowPlaying = 'nothing playing';
	}
	goog.dom.$('nowplaying').innerHTML = nowPlaying;
}

function loadPlayHistory(amount) {
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=history;amount='+amount,
		function() {
			goog.dom.$('result_title').innerHTML = amount + ' previously played song';
			fillHistoryTable(this.getResponseJson());
		}
	);
}

function loadRecentSongs(amount) {
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=recent;amount=' + amount,
		function () {
			goog.dom.$('result_title').innerHTML = amount + ' Recently Added Songs';
			fillResultTable(this.getResponseJson());
		}
	);
}

function loadRandomSongs(amount) {
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=random;amount=' + amount,
		function () {
			goog.dom.$('result_title').innerHTML = amount + ' Random Songs';
			fillResultTable(this.getResponseJson());
		}
	);
}

function browseSongs(field)
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=browse;field=' + field,
			function () {
				goog.dom.$('result_title').innerHTML = 'Browse by ' + field;
				fillResultList(this.getResponseJson(), field);
			}
	);
}

function getSongDetails(song_id) {
	goog.net.XhrIo.send(
		'/acoustics/json.pl',
		function() {
			var table = '<table id="result_table"><thead><tr><th>Track</th><th>Artist</th><th>Title</th><th>Album</th><th>Length</th></tr></thead>';
			var json = this.getResponseJson();
			json.playlist.push(json.nowPlaying);
			for(var item in json.playlist)
			{
				if(song_id == json.playlist[item].song_id)
				{
					var file = json.playlist[item];
					table += "<tr><td>"+file.track+"</td><td>"+file.artist+"</td><td>"+file.title+"</td><td>"+file.album+"</td><td>"+readableTime(file.length)+"</td></tr>";
					table += "<tr>"+file.path+"</tr>";
					table += "<tr>Who voted for this?</tr>";
					table += "<tr>"
					for(var who in file.who)
						table += file.who[who]+" ";
					table += "</tr>";
				}
			}
			table += "</table>";
		goog.dom.$('songresults').innerHTML = table;
		}
		);
}


function fillResultList(json, field) {
	list = '<ul>';
	for (var item in json) {
		list += '<li><a href="javascript:selectRequest(\'' + field
			+ '\',\'' + qsencode(json[item][field]) + '\')">'
			+ json[item][field] + '</a></li>';
	}
	list += '</ul>';
	goog.dom.$('songresults').innerHTML = list;
}

function fillHistoryTable(json) {
	var table = '<table id="result_table"><thead><tr><th>Vote</th><th>Name</th><th>Played at</th></tr></thead>';
	for (var item in json)
	{
		table += '<tr><td style="text-align: center">'
		+		 '<a href="javascript:voteSong('+json[item].song_id+')"><img src="www-data/icons/add.png" alt=""/></a>'
		+		 '</td><td><a href="javascript:getSongDetails('+json[item].song_id+')">'+json[item].pretty_name+'</a></td><td>'+json[item].time+'</td></tr>';
	}
	table += '</table>';
	goog.dom.$('songresults').innerHTML = table;
}

function fillResultTable(json) {
	table = '<table id="result_table"><thead><tr><th>vote</th>'
		+  '<th>Track</th>'
		+  '<th>Title</th>'
		+  '<th>Album</th>'
		+  '<th>Artist</th></tr></thead><tbody>';
	for (var item in json) {
		table += '<tr>'
		+ '<td style="text-align: center"><a href="javascript:voteSong('
		+ json[item].song_id
		+ ')"><img src="www-data/icons/add.png" alt="vote" /></a></td>'
		+ '<td>' + json[item].track + '</td>'
		+ '<td class="datacol"><a href="javascript:selectRequest(\'title\', \''
		+ qsencode(json[item].title) + '\')">' + json[item].title + '</a></td>'
		+ '<td class="datacol"><a href="javascript:selectRequest(\'album\', \''
		+ qsencode(json[item].album) + '\')">' + json[item].album + '</a></td>'
		+ '<td class="datacol"><a href="javascript:selectRequest(\'artist\', \''
		+ qsencode(json[item].artist) + '\')">' + json[item].artist + '</a></td>'
		+ '</tr>';
	};
	table += '</tbody></table>';
	goog.dom.$('songresults').innerHTML = table;

	var component = new goog.ui.TableSorter();
	component.decorate(goog.dom.$('result_table'));
	component.setDefaultSortFunction(goog.ui.TableSorter.alphaSort);
	component.setSortFunction(1, goog.ui.TableSorter.numericSort);
}

function voteSong(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=vote;song_id=' + song_id,
		function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function unvoteSong(song_id) {
	if (!currentUser) {
		alert("You must log in first.");
		return;
	}
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=unvote;song_id=' + song_id,
		function () {handlePlayerStateRequest(this.getResponseJson());}
	);
}

function updateVolumeScale(volume) {
	scale = '';
	for (var i = 1; i <= 11; i++) {
		scale += '<a ';
		if (((Math.round(volume / 7))+1) == i) scale += 'style="color: red" ';
		scale += 'href="javascript:setVolume(' + ((i * 10) - 10) + ')">' + i + '</a> ';
	}
	goog.dom.$('volume').innerHTML = scale;
}

function qsencode(str) {
	return escape(escape(str));
}
