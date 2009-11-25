goog.require('goog.dom');
goog.require('goog.net.XhrIo');
goog.require('goog.ui.TableSorter');
goog.require('goog.ui.Slider');
goog.require('goog.ui.Component');
goog.require('goog.Throttle');
goog.require('goog.Timer');
goog.require('goog.async.Delay');

function sendPlayerCommand(mode) {
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=' + mode,
			function () {updateNowPlaying(this.getResponseJson());}
	);
}

function setVolume(value) {
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=volume;value=' + value
	);
}

function searchRequest(field, value)
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=search;field='+field+';value='+value,
			function () {fillResultTable(this.getResponseJson());}
	);
}

function selectRequest(field, value)
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=select;field='+field+';value='+value,
			function () {fillResultTable(this.getResponseJson());}
	);
}

function startPlayerStateTimer () {
	nowPlayingRequest();
	var timer = new goog.Timer(15000);
	timer.start();
	goog.events.listen(timer, goog.Timer.TICK, function () {nowPlayingRequest()});
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

function browseSongs(field)
{
	goog.net.XhrIo.send(
			'/acoustics/json.pl?mode=browse;field=' + field,
			function () {fillResultList(this.getResponseJson(), field)}
	);
}

function fillResultList(json, field) {
	list = '<ul>';
	for (var item in json) {
		list += '<li><a href="javascript:searchRequest(\''+field+'\',\''+json[item][field]+'\')">' + json[item][field] + '</a></li>';
	}
	list += '</ul>';
	goog.dom.$('songresults').innerHTML = list;
}

function fillResultTable(json) {
	table = '<table id="result_table"><thead><tr><td></td>'
		+  '<th>Title</th>'
		+  '<th>Album</th>'
		+  '<th>Artist</th></tr></thead><tbody>';
	for (var item in json) {
		table += '<tr>'
		+ '<td><a href="javascript:voteSong(' + json[item].song_id
		+ ')">vote</a></td>'
		+ '<td><a href="javascript:selectRequest(\'title\', \''
		+ json[item].title + '\')">' + json[item].title + '</a></td>'
		+ '<td><a href="javascript:selectRequest(\'album\', \''
		+ json[item].album + '\')">' + json[item].album + '</a></td>'
		+ '<td><a href="javascript:selectRequest(\'artist\', \''
		+ json[item].artist + '\')">' + json[item].artist + '</a></td>'
		+ '</tr>';
	};
	table += '</tbody></table>';
	goog.dom.$('songresults').innerHTML = table;

	var component = new goog.ui.TableSorter();
	component.decorate(goog.dom.$('result_table'));
	component.setDefaultSortFunction(goog.ui.TableSorter.alphaSort);
}

function voteSong(song_id) {
	goog.net.XhrIo.send(
		'/acoustics/json.pl?mode=vote;song_id=' + song_id,
		// XXX: make this more useful
		function () {alert('vote succeeded');}
	);
}

function makeVolumeSlider(elm) {
	var s = new goog.ui.Slider;
	s.decorate(elm);
	s.setMoveToPointEnabled(true);

	// Throttle the slider, so we don't spam the server with requests
	// Delay each setVolume call slightly, so that the changes are smoother.
	var throttle = new goog.Throttle(
			function () {
				var delay = new goog.async.Delay(function() {
					setVolume(s.getValue());
					}, 500);
				delay.start();
			},
			1000
	);
	s.addEventListener(goog.ui.Component.EventType.CHANGE, function() {
			throttle.fire();
	});
}
