package Acoustics;

use strict;
use warnings;

use Mouse;
use DBI;

has 'db' => (is => 'ro', isa => 'DBI', handles => [qw(begin_work commit)]);
has 'data_source' => (is => 'ro', isa => 'Str');

sub BUILD {
	my $self = shift;

	$self->{db} = DBI->connect(
		'dbi:SQLite:' . $self->data_source,
		'', '', # user, pass
		{RaiseError => 1, AutoCommit => 1},
	);
}

sub check_if_song_exists {
	my $self = shift;
	my $path = shift;

	my @rows = $self->db->selectrow_array(
		'SELECT count(*) FROM songs WHERE path = ?',
		undef, $path,
	);

	return $rows[0];
}

sub add_song {
	my $self = shift;
	my $data = shift;

	my $sth = $self->db->prepare('
		INSERT INTO songs(artist, album, title, length, track, path)
		VALUES(?, ?, ?, ?, ?, ?)
	');

	$sth->execute((map {$data->{$_}} qw(artist album title length track path)));
}

sub update_song {
	my $self = shift;
	my $data = shift;

	my $sth = $self->db->prepare('
		UPDATE songs SET artist=?, album=?, title=?, length=?, track=?
		WHERE path = ?
	');

	$sth->execute((map {$data->{$_}} qw(artist album title length track path)));
}

sub get_playlist {
	my $self = shift;

	# If we have votes, then get the corresponding songs
	my @songs = @{$self->db->selectall_arrayref(
		'SELECT songs.path, songs.song_id, songs.title, songs.album,
		songs.artist, songs.length, votes.who, votes.time
		FROM songs, votes WHERE songs.song_id == votes.song_id
		ORDER BY votes.time DESC',
		{Slice => {}},
	)};

	unless (@songs) {
		# if we don't have any votes, then get a random song
		@songs = $self->db->selectrow_hashref(
			'SELECT song_id, title, artist, album, path, length
			FROM songs ORDER BY RANDOM() LIMIT 1'
		);
	}

	return @songs;
}

sub delete_vote {
	my $self = shift;
	my $song = shift;

	my $sth = $self->db->prepare('DELETE FROM votes WHERE song_id = ?');
	$sth->execute($song);
}

sub add_playhistory {
	my $self = shift;
	my $data = shift;

	my $sth = $self->db->prepare(
		'INSERT INTO history(song_id, who, time, pretty_name) values(?, ?, ?, ?)'
	);
	$sth->execute(
		$data->{song_id}, '', time, "$data->{artist} - $data->{title}",
	);
}

sub delete_song {
	my $self = shift;
	my $song = shift;

	my $sth = $self->db->prepare('DELETE FROM songs WHERE song_id = ?');
	$sth->execute($song);
}

sub get_library {
	my $self = shift;

	my $sth = $self->db->prepare("SELECT * FROM songs ORDER BY artist,album,track ASC");

	$sth->execute();

	my @songs = @{$sth->fetchall_arrayref({})};
}

sub vote {
	my $self = shift;
	my $song_id = shift;

	my $sth = $self->db->prepare("INSERT INTO votes (song_id, time) VALUES (?,?)");

	$sth->execute($song_id, time);
}

1;
