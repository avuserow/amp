goog.require('goog.dom');
goog.require('goog.net.XhrIo');
goog.require('goog.ui.TableSorter');

function sendPlayerCommand(mode) {
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=' + mode,
			function () {updateNowPlaying(this.getResponseJson());}
	);
}

function nowPlayingRequest () {
	goog.net.XhrIo.send(
		'/acoustics/json.pl',
		function () {updateNowPlaying(this.getResponseJson());}
	);
}

function getPlaylistRequest() 
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=playlist',
			function () {getPlaylist(this.getResponseJson());}
	);
}

function getPlaylist(json)
{
	list = '<ul>';
	for (var item in json)
	{
		list += '<li>' + json[item].artist + ' - ' + json[item].title + '</li>';
	}
	list += '</ui>';
	goog.dom.$('playlist').innerHTML = list;
}

function updateNowPlaying(json) {
	if (json) {
		nowPlaying = json.title + ' by ' + json.artist;
	} else {
		nowPlaying = 'nothing playing';
	}
	goog.dom.setTextContent(goog.dom.$('nowplaying'), nowPlaying);
}

function loadRandomSongs() {
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=random',
		function () {fillResultTable(this.getResponseJson())}
	);
}

function fillResultTable(json) {
	rows = '<thead><tr><td></td>'
		+  '<th>Title</th>'
		+  '<th>Album</th>'
		+  '<th>Artist</th></tr></thead><tbody>';
	for (var item in json) {
		rows += '<tr>'
		+ '<td><a href="javascript:voteSong(' + json[item].song_id + ')">vote</a></td>'
		+ '<td>' + json[item].title + '</td>'
		+ '<td>' + json[item].album + '</td>'
		+ '<td>' + json[item].artist + '</td>'
		+ '</tr>';
	};
	rows += '</tbody>';
	goog.dom.$('songresults').innerHTML = rows;

	var component = new goog.ui.TableSorter();
	component.decorate(goog.dom.$('songresults'));
	component.setDefaultSortFunction(goog.ui.TableSorter.alphaSort);
}

function voteSong(song_id) {
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=vote;song_id=' + song_id,
		// XXX: make this more useful
		function () {alert('vote succeeded');}
	);
}
