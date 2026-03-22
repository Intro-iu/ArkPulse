import 'package:uuid/uuid.dart';

/// Common audio file extensions we consider valid for the player.
const _audioExtensions = {
  'flac',
  'mp3',
  'ogg',
  'opus',
  'aac',
  'm4a',
  'wav',
  'wv',
  'ape',
  'alac',
  'aiff',
  'aif',
  'dsf',
  'dff',
  'mqa',
};

bool isAudioFile(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return _audioExtensions.contains(ext);
}

enum ScrapeState { idle, loading, success, error }

class ScrapedSong {
  final String id;
  final String configId;
  final String title;
  final String artist;
  final String album;
  final String path; // Human-readable path for UI
  final String webDavHref; // Raw WebDAV href returned by PROPFIND
  final String remoteUrl; // Canonical full URL for audio streaming
  final String serverUrl;
  final String username;
  final String password;
  final String format;
  final String bitrate;
  final int durationMs;

  const ScrapedSong({
    required this.id,
    required this.configId,
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
  });

  factory ScrapedSong.fromDb(Map<String, dynamic> row) {
    return ScrapedSong(
      id: row['id'] as String,
      configId: row['config_id'] as String,
      title: row['title'] as String,
      artist: row['artist'] as String,
      album: row['album'] as String,
      path: row['path'] as String,
      webDavHref: (row['webdav_href'] ?? row['path']) as String,
      remoteUrl: row['remote_url'] as String,
      serverUrl: row['server_url'] as String,
      username: row['username'] as String,
      password: row['password'] as String,
      format: row['format'] as String,
      bitrate: row['bitrate'] as String,
      durationMs: row['duration_ms'] as int,
    );
  }

  Map<String, dynamic> toDb() => {
    'id': id,
    'config_id': configId,
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
  };
}

class WebDavConfig {
  final String id;
  String name;
  String url;
  String username;
  String password;
  String davPath;
  ScrapeState state;
  String? errorMessage;
  List<ScrapedSong> songs;

  WebDavConfig({
    String? id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.davPath = '/',
    this.state = ScrapeState.idle,
    this.errorMessage,
    this.songs = const [],
  }) : id = id ?? const Uuid().v4();

  factory WebDavConfig.fromDb(Map<String, dynamic> row) {
    return WebDavConfig(
      id: row['id'] as String,
      name: row['name'] as String,
      url: row['url'] as String,
      username: row['username'] as String,
      password: row['password'] as String,
      davPath: row['dav_path'] as String,
    );
  }

  Map<String, dynamic> toDb() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'dav_path': davPath,
    'created_at': DateTime.now().toIso8601String(),
  };

  // TODO(scraper): Replace with real WebDAV traversal + symphonia metadata extraction.
  // Steps needed:
  //   1. Connect to [url] with [username]/[password] using Rust WebDavClient
  //   2. Recursively list files under [davPath] using WebDavClient.listDirectory()
  //   3. Filter by isAudioFile() helper
  //   4. Use symphonia via FFI to read metadata (title, artist, album, bitrate, duration)
  //   5. Persist scraped song metadata to database
  //
  // For now: listing is done via real WebDAV PROPFIND but metadata is inferred from filename.
}
