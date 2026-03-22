import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/playlist.dart';
import '../models/webdav_config.dart';

/// Persists all application configuration in a local SQLite database.
/// The database is stored in the OS-appropriate app-config directory:
///  - Windows: %LOCALAPPDATA%\arkpulse\arkpulse.db
///  - Linux:   ~/.config/arkpulse/arkpulse.db
///  - macOS:   ~/Library/Application Support/arkpulse/arkpulse.db
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    // Initialize ffi for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    Directory appDir;
    if (Platform.isWindows) {
      // %LOCALAPPDATA%\arkpulse
      final localAppData =
          Platform.environment['LOCALAPPDATA'] ??
          (await getApplicationDocumentsDirectory()).path;
      appDir = Directory(p.join(localAppData, 'arkpulse'));
    } else if (Platform.isLinux) {
      // ~/.config/arkpulse
      final home = Platform.environment['HOME'] ?? '/tmp';
      appDir = Directory(p.join(home, '.config', 'arkpulse'));
    } else {
      // macOS / other: use application support directory
      final support = await getApplicationSupportDirectory();
      appDir = Directory(p.join(support.path, 'arkpulse'));
    }

    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    final dbPath = p.join(appDir.path, 'arkpulse.db');
    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE webdav_configs (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        url TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        dav_path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await _createScrapedSongsTable(db);
    await _createPlaylistsTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createScrapedSongsTable(db);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE scraped_songs ADD COLUMN webdav_href TEXT',
      );
      await db.execute(
        'UPDATE scraped_songs SET webdav_href = path WHERE webdav_href IS NULL',
      );
    }
    if (oldVersion < 4) {
      await _createPlaylistsTables(db);
    }
  }

  Future<void> _createScrapedSongsTable(Database db) async {
    await db.execute('''
      CREATE TABLE scraped_songs (
        id TEXT PRIMARY KEY,
        config_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        path TEXT NOT NULL,
        webdav_href TEXT NOT NULL,
        remote_url TEXT NOT NULL,
        server_url TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        format TEXT NOT NULL,
        bitrate TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        FOREIGN KEY (config_id) REFERENCES webdav_configs(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_scraped_songs_config_id ON scraped_songs(config_id)',
    );
  }

  Future<void> _createPlaylistsTables(Database db) async {
    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE playlist_tracks (
        id TEXT PRIMARY KEY,
        playlist_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        path TEXT NOT NULL,
        webdav_href TEXT NOT NULL,
        remote_url TEXT NOT NULL,
        server_url TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        format TEXT NOT NULL,
        bitrate TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_playlist_tracks_playlist_id ON playlist_tracks(playlist_id, sort_order)',
    );
  }

  // ────────────────── WebDAV Config CRUD ──────────────────

  Future<List<Map<String, dynamic>>> loadWebDavConfigs() async {
    final database = await db;
    return await database.query('webdav_configs', orderBy: 'created_at ASC');
  }

  Future<void> insertWebDavConfig(Map<String, dynamic> config) async {
    final database = await db;
    await database.insert(
      'webdav_configs',
      config,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWebDavConfig(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('scraped_songs', where: 'config_id = ?', whereArgs: [id]);
      await txn.delete('webdav_configs', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateWebDavConfig(Map<String, dynamic> config) async {
    final database = await db;
    await database.update(
      'webdav_configs',
      config,
      where: 'id = ?',
      whereArgs: [config['id']],
    );
  }

  Future<bool> configNameExists(String name, {String? excludeId}) async {
    final database = await db;
    final List<Map<String, dynamic>> result = excludeId != null
        ? await database.query(
            'webdav_configs',
            where: 'name = ? AND id != ?',
            whereArgs: [name, excludeId],
          )
        : await database.query(
            'webdav_configs',
            where: 'name = ?',
            whereArgs: [name],
          );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> loadScrapedSongs(String configId) async {
    final database = await db;
    return await database.query(
      'scraped_songs',
      where: 'config_id = ?',
      whereArgs: [configId],
      orderBy: 'artist COLLATE NOCASE ASC, title COLLATE NOCASE ASC',
    );
  }

  Future<void> replaceScrapedSongs(
    String configId,
    List<ScrapedSong> songs,
  ) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete(
        'scraped_songs',
        where: 'config_id = ?',
        whereArgs: [configId],
      );

      final batch = txn.batch();
      for (final song in songs) {
        batch.insert(
          'scraped_songs',
          song.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteScrapedSongs(String configId) async {
    final database = await db;
    await database.delete(
      'scraped_songs',
      where: 'config_id = ?',
      whereArgs: [configId],
    );
  }

  Future<List<Map<String, dynamic>>> loadPlaylists() async {
    final database = await db;
    return await database.query('playlists', orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> loadPlaylistTracks(String playlistId) async {
    final database = await db;
    return await database.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC',
    );
  }

  Future<void> insertPlaylist(Map<String, dynamic> playlist) async {
    final database = await db;
    await database.insert(
      'playlists',
      playlist,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      await txn.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    });
  }

  Future<bool> playlistNameExists(String name, {String? excludeId}) async {
    final database = await db;
    final result = excludeId != null
        ? await database.query(
            'playlists',
            where: 'name = ? AND id != ?',
            whereArgs: [name, excludeId],
          )
        : await database.query(
            'playlists',
            where: 'name = ?',
            whereArgs: [name],
          );
    return result.isNotEmpty;
  }

  Future<void> insertPlaylistTracks(List<PlaylistTrack> tracks) async {
    final database = await db;
    final batch = database.batch();
    for (final track in tracks) {
      batch.insert(
        'playlist_tracks',
        track.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> getNextPlaylistTrackOrder(String playlistId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    return (result.first['next_order'] as int?) ?? 0;
  }

  Future<void> deletePlaylistTrack(String trackId) async {
    final database = await db;
    await database.delete(
      'playlist_tracks',
      where: 'id = ?',
      whereArgs: [trackId],
    );
  }
}
