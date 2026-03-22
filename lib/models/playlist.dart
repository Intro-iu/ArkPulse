import 'webdav_config.dart';

class PlaylistTrack {
  final String id;
  final String playlistId;
  final String title;
  final String artist;
  final String album;
  final String path;
  final String webDavHref;
  final String remoteUrl;
  final String serverUrl;
  final String username;
  final String password;
  final String format;
  final String bitrate;
  final int durationMs;
  final int sortOrder;

  const PlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.webDavHref,
    required this.remoteUrl,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.format,
    required this.bitrate,
    required this.durationMs,
    required this.sortOrder,
  });

  factory PlaylistTrack.fromDb(Map<String, dynamic> row) {
    return PlaylistTrack(
      id: row['id'] as String,
      playlistId: row['playlist_id'] as String,
      title: row['title'] as String,
      artist: row['artist'] as String,
      album: row['album'] as String,
      path: row['path'] as String,
      webDavHref: row['webdav_href'] as String,
      remoteUrl: row['remote_url'] as String,
      serverUrl: row['server_url'] as String,
      username: row['username'] as String,
      password: row['password'] as String,
      format: row['format'] as String,
      bitrate: row['bitrate'] as String,
      durationMs: row['duration_ms'] as int,
      sortOrder: row['sort_order'] as int,
    );
  }

  factory PlaylistTrack.fromScrapedSong(
    ScrapedSong song, {
    required String id,
    required String playlistId,
    required int sortOrder,
  }) {
    return PlaylistTrack(
      id: id,
      playlistId: playlistId,
      title: song.title,
      artist: song.artist,
      album: song.album,
      path: song.path,
      webDavHref: song.webDavHref,
      remoteUrl: song.remoteUrl,
      serverUrl: song.serverUrl,
      username: song.username,
      password: song.password,
      format: song.format,
      bitrate: song.bitrate,
      durationMs: song.durationMs,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toDb() => {
    'id': id,
    'playlist_id': playlistId,
    'title': title,
    'artist': artist,
    'album': album,
    'path': path,
    'webdav_href': webDavHref,
    'remote_url': remoteUrl,
    'server_url': serverUrl,
    'username': username,
    'password': password,
    'format': format,
    'bitrate': bitrate,
    'duration_ms': durationMs,
    'sort_order': sortOrder,
  };

  ScrapedSong toScrapedSong() => ScrapedSong(
    id: id,
    configId: playlistId,
    title: title,
    artist: artist,
    album: album,
    path: path,
    webDavHref: webDavHref,
    remoteUrl: remoteUrl,
    serverUrl: serverUrl,
    username: username,
    password: password,
    format: format,
    bitrate: bitrate,
    durationMs: durationMs,
  );
}

class Playlist {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<PlaylistTrack> tracks;

  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.tracks = const [],
  });

  factory Playlist.fromDb(
    Map<String, dynamic> row, {
    List<PlaylistTrack> tracks = const [],
  }) {
    return Playlist(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      tracks: tracks,
    );
  }

  Map<String, dynamic> toDb() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  Playlist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<PlaylistTrack>? tracks,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      tracks: tracks ?? this.tracks,
    );
  }
}
