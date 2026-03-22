import 'dart:async';
import 'dart:math';

import 'package:arkpulse/models/playlist.dart';
import 'package:flutter/material.dart';
import '../models/webdav_config.dart';
import '../services/database_service.dart';
import '../src/rust/api/player_api.dart';
import '../src/rust/api/webdav_api.dart';
import 'package:uuid/uuid.dart';

enum PlaybackMode { listLoop, singleLoop, shuffle }

class AppState extends ChangeNotifier {
  // Singleton for easy global access
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final List<WebDavConfig> _webDavConfigs = [];
  final List<Playlist> _playlists = [];
  final Random _random = Random();
  bool _initialized = false;
  ScrapedSong? _currentTrack;
  String? _playbackErrorMessage;
  List<ScrapedSong> _playbackQueue = const [];
  int _queueIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.listLoop;
  PlaybackState _playbackState = const PlaybackState.stopped();
  bool _isTrackLoading = false;
  int _playRequestSerial = 0;
  int _playbackPositionMs = 0;
  int _playbackDurationMs = 0;
  bool _isSeeking = false;
  int? _seekPreviewPositionMs;
  int _seekRequestSerial = 0;
  int? _pendingSeekPositionMs;

  List<WebDavConfig> get webDavConfigs => List.unmodifiable(_webDavConfigs);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isInitialized => _initialized;
  ScrapedSong? get currentTrack => _currentTrack;
  String? get playbackErrorMessage => _playbackErrorMessage;
  List<ScrapedSong> get playbackQueue => List.unmodifiable(_playbackQueue);
  int get queueIndex => _queueIndex;
  PlaybackMode get playbackMode => _playbackMode;
  PlaybackState get playbackState => _playbackState;
  bool get isTrackLoading => _isTrackLoading;
  int get playbackPositionMs => _playbackPositionMs;
  int get playbackDurationMs => _playbackDurationMs;
  bool get isSeeking => _isSeeking;
  bool get hasPendingSeek => _pendingSeekPositionMs != null;
  int get displayedPlaybackPositionMs =>
      _seekPreviewPositionMs ?? _pendingSeekPositionMs ?? _playbackPositionMs;
  double? get playbackProgress {
    if (_playbackDurationMs <= 0) return null;
    return (displayedPlaybackPositionMs / _playbackDurationMs).clamp(0.0, 1.0);
  }

  /// Must be called once at app startup (in main.dart or MainLayout.initState).
  Future<void> initialize() async {
    if (_initialized) return;
    final database = DatabaseService();
    final rows = await database.loadWebDavConfigs();
    for (final row in rows) {
      final config = WebDavConfig.fromDb(row);
      final songs = (await database.loadScrapedSongs(config.id))
          .map(ScrapedSong.fromDb)
          .toList();
      config.songs = songs;
      config.state = songs.isEmpty ? ScrapeState.idle : ScrapeState.success;
      _webDavConfigs.add(config);
    }
    final playlistRows = await database.loadPlaylists();
    for (final row in playlistRows) {
      final tracks = (await database.loadPlaylistTracks(row['id'] as String))
          .map(PlaylistTrack.fromDb)
          .toList();
      _playlists.add(Playlist.fromDb(row, tracks: tracks));
    }
    _initialized = true;
    notifyListeners();
  }

  // ─── Add WebDAV Config ───────────────────────────────────────────────────

  /// Returns an error string if the name already exists, null on success.
  Future<String?> addWebDavConfig({
    required String name,
    required String url,
    required String username,
    required String password,
    required String davPath,
  }) async {
    // Duplicate name guard
    final nameExists = _webDavConfigs.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (nameExists) {
      return 'A config named "$name" already exists. Please choose a different name.';
    }

    final config = WebDavConfig(
      name: name,
      url: url,
      username: username,
      password: password,
      davPath: davPath,
    );
    _webDavConfigs.add(config);
    await DatabaseService().insertWebDavConfig(config.toDb());
    notifyListeners();

    // Auto-trigger listing immediately
    _listAudioFiles(config);
    return null;
  }

  // ─── Remove WebDAV Config ─────────────────────────────────────────────────

  Future<void> removeWebDavConfig(String id) async {
    _webDavConfigs.removeWhere((c) => c.id == id);
    await DatabaseService().deleteWebDavConfig(id);
    notifyListeners();
  }

  Future<String?> updateWebDavConfig({
    required String id,
    required String name,
    required String url,
    required String username,
    required String password,
    required String davPath,
  }) async {
    final index = _webDavConfigs.indexWhere((c) => c.id == id);
    if (index == -1) return "Config not found.";

    // Duplicate name guard (excluding self)
    final nameExists = _webDavConfigs.any(
      (c) => c.id != id && c.name.toLowerCase() == name.toLowerCase(),
    );
    if (nameExists) {
      return 'A config named "$name" already exists. Please choose a different name.';
    }

    final config = _webDavConfigs[index];
    config.name = name;
    config.url = url;
    config.username = username;
    config.password = password;
    config.davPath = davPath;
    config.state = config.songs.isEmpty ? ScrapeState.idle : ScrapeState.success;
    config.errorMessage = null;

    await DatabaseService().updateWebDavConfig(config.toDb());
    notifyListeners();

    // Re-list after update
    _listAudioFiles(config);
    return null;
  }

  // ─── List Audio Files via Real WebDAV FFI ─────────────────────────────────

  Future<void> triggerScrape(String configId) async {
    final configIndex = _webDavConfigs.indexWhere((c) => c.id == configId);
    if (configIndex == -1) return;
    _listAudioFiles(_webDavConfigs[configIndex]);
  }

  Future<void> _listAudioFiles(WebDavConfig config) async {
    // Guard: don't double-list
    if (config.state == ScrapeState.loading) return;

    config.state = ScrapeState.loading;
    config.errorMessage = null;
    notifyListeners();

    try {
      final client = WebDavClient(
        serverUrl: config.url,
        username: config.username,
        token: config.password,
      );

      // Recursively find all audio files under davPath
      final audioEntries = await client.listAllAudioRecursive(
        rootPath: config.davPath,
      );

      config.songs = audioEntries.map((entry) {
        final nameParts = entry.name
            .replaceAll(RegExp(r'\.[^.]+$'), '')
            .split(' - ');
        final title = nameParts.length >= 2
            ? nameParts.sublist(1).join(' - ')
            : nameParts[0];
        final artist = nameParts.length >= 2 ? nameParts[0] : 'Unknown Artist';
        final ext = entry.name.split('.').last.toUpperCase();

        final webDavHref = entry.path;
        final remoteUrl = _buildRemoteUrl(config.url, webDavHref);
        final displayPath = _buildDisplayPath(webDavHref);

        return ScrapedSong(
          id: const Uuid().v4(),
          configId: config.id,
          title: title,
          artist: artist,
          album: 'Unknown Album',
          path: displayPath,
          webDavHref: webDavHref,
          remoteUrl: remoteUrl, // full URL for playback
          serverUrl: config.url,
          username: config.username,
          password: config.password,
          format: ext,
          bitrate: 'N/A',
          durationMs: 0,
        );
      }).toList();

      await DatabaseService().replaceScrapedSongs(config.id, config.songs);
      config.state = ScrapeState.success;
    } catch (e) {
      config.state = ScrapeState.error;
      config.errorMessage = e.toString();
    }

    notifyListeners();
  }

  // ─── Global Search ────────────────────────────────────────────────────────

  List<ScrapedSong> getAllScrapedSongs() {
    return _webDavConfigs
        .where((c) => c.state == ScrapeState.success)
        .expand((c) => c.songs)
        .toList();
  }

  Future<String?> playSong(ScrapedSong song, {List<ScrapedSong>? queue}) async {
    final requestSerial = ++_playRequestSerial;
    if (queue != null && queue.isNotEmpty) {
      _playbackQueue = List<ScrapedSong>.from(queue);
      _queueIndex = _playbackQueue.indexWhere(
        (item) => _songKey(item) == _songKey(song),
      );
    } else if (_playbackQueue.isEmpty) {
      _playbackQueue = [song];
      _queueIndex = 0;
    } else {
      final existingIndex = _playbackQueue.indexWhere(
        (item) => _songKey(item) == _songKey(song),
      );
      if (existingIndex >= 0) {
        _queueIndex = existingIndex;
      } else {
        _playbackQueue = [song];
        _queueIndex = 0;
      }
    }

    if (_queueIndex < 0) {
      _queueIndex = 0;
    }

    _currentTrack = song;
    _playbackErrorMessage = null;
    _isTrackLoading = true;
    _playbackState = const PlaybackState.stopped();
    _resetPlaybackProgress();
    notifyListeners();

    try {
      await AudioPlayer.stop();
      await AudioPlayer.playRemoteFile(
        url: _buildRemoteUrl(song.serverUrl, song.webDavHref),
        username: song.username,
        token: song.password,
      );
      if (requestSerial != _playRequestSerial) {
        return null;
      }
      _isTrackLoading = false;
      final progress = await AudioPlayer.getProgress();
      syncPlaybackSnapshot(
        state: const PlaybackState.playing(),
        progress: progress,
      );
      return null;
    } catch (e) {
      if (requestSerial != _playRequestSerial) {
        return null;
      }
      _isTrackLoading = false;
      _playbackErrorMessage = e.toString();
      syncPlaybackSnapshot(
        state: PlaybackState.error(_playbackErrorMessage!),
        progress: const PlaybackProgress(positionMs: 0, durationMs: 0),
      );
      return _playbackErrorMessage;
    }
  }

  Future<String?> playQueue(
    List<ScrapedSong> queue, {
    required int startIndex,
  }) async {
    if (queue.isEmpty) {
      return 'No tracks available.';
    }
    if (startIndex < 0 || startIndex >= queue.length) {
      return 'Invalid queue index.';
    }

    _playbackQueue = List<ScrapedSong>.from(queue);
    _queueIndex = startIndex;
    return playSong(_playbackQueue[_queueIndex]);
  }

  Future<void> pausePlayback() async {
    if (_isTrackLoading) return;
    await AudioPlayer.pause();
    final progress = await AudioPlayer.getProgress();
    syncPlaybackSnapshot(
      state: const PlaybackState.paused(),
      progress: progress,
    );
  }

  Future<void> resumePlayback() async {
    if (_isTrackLoading) return;
    await AudioPlayer.resume();
    final progress = await AudioPlayer.getProgress();
    syncPlaybackSnapshot(
      state: const PlaybackState.playing(),
      progress: progress,
    );
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    if (_playbackState is PlaybackState_Playing) {
      await pausePlayback();
    } else {
      await resumePlayback();
    }
  }

  Future<void> stopPlayback() async {
    _playRequestSerial++;
    _isTrackLoading = false;
    await AudioPlayer.stop();
    syncPlaybackSnapshot(
      state: const PlaybackState.stopped(),
      progress: const PlaybackProgress(positionMs: 0, durationMs: 0),
    );
  }

  Future<String?> playNext() async {
    if (_currentTrack == null) return null;
    if (_playbackMode == PlaybackMode.singleLoop) {
      return playSong(_currentTrack!);
    }
    if (_playbackQueue.isEmpty) {
      return playSong(_currentTrack!);
    }

    final nextIndex = _resolveNextIndex();
    if (nextIndex == null) {
      await stopPlayback();
      return null;
    }

    _queueIndex = nextIndex;
    return playSong(_playbackQueue[_queueIndex]);
  }

  Future<String?> playPrevious() async {
    if (_currentTrack == null) return null;
    if (_playbackQueue.isEmpty) {
      return playSong(_currentTrack!);
    }

    final previousIndex = _resolvePreviousIndex();
    if (previousIndex == null) {
      return playSong(_currentTrack!);
    }

    _queueIndex = previousIndex;
    return playSong(_playbackQueue[_queueIndex]);
  }

  void cyclePlaybackMode() {
    switch (_playbackMode) {
      case PlaybackMode.listLoop:
        _playbackMode = PlaybackMode.singleLoop;
      case PlaybackMode.singleLoop:
        _playbackMode = PlaybackMode.shuffle;
      case PlaybackMode.shuffle:
        _playbackMode = PlaybackMode.listLoop;
    }
    notifyListeners();
  }

  void updatePlaybackState(PlaybackState state) {
    syncPlaybackSnapshot(
      state: state,
      progress: PlaybackProgress(
        positionMs: _playbackPositionMs,
        durationMs: _playbackDurationMs,
      ),
    );
  }

  void syncPlaybackSnapshot({
    required PlaybackState state,
    required PlaybackProgress progress,
  }) {
    final nextDuration = progress.durationMs;
    final cappedPosition = nextDuration > 0
        ? progress.positionMs.clamp(0, nextDuration)
        : progress.positionMs;
    final previousState = _playbackState;
    final stateChanged = previousState.toString() != state.toString();
    final positionChanged =
        _playbackPositionMs != cappedPosition || _playbackDurationMs != nextDuration;
    final hasReachedPendingSeek =
        _pendingSeekPositionMs != null &&
        nextDuration > 0 &&
        (cappedPosition - _pendingSeekPositionMs!).abs() <= 1200;
    final loadingChanged =
        _isTrackLoading &&
        (_pendingSeekPositionMs == null
            ? state is PlaybackState_Playing
            : hasReachedPendingSeek);

    if (_isTrackLoading &&
        ((_pendingSeekPositionMs == null && state is PlaybackState_Playing) ||
            hasReachedPendingSeek)) {
      _isTrackLoading = false;
      _pendingSeekPositionMs = null;
    }

    _playbackState = state;
    _playbackPositionMs = cappedPosition;
    _playbackDurationMs = nextDuration;

    if (!_isSeeking) {
      _seekPreviewPositionMs = null;
    }

    if (state is PlaybackState_Error) {
      _isTrackLoading = false;
      _pendingSeekPositionMs = null;
    }

    if (state is PlaybackState_Stopped && previousState is PlaybackState_Playing) {
      scheduleMicrotask(() => playNext());
    }

    if (stateChanged || positionChanged || loadingChanged) {
      notifyListeners();
    }
  }

  void beginSeekPreview() {
    if (_playbackDurationMs <= 0) return;
    _isSeeking = true;
    _seekPreviewPositionMs = _playbackPositionMs;
    notifyListeners();
  }

  void updateSeekPreview(double fraction) {
    if (_playbackDurationMs <= 0) return;
    _isSeeking = true;
    _seekPreviewPositionMs = (_playbackDurationMs * fraction)
        .clamp(0, _playbackDurationMs)
        .round();
    notifyListeners();
  }

  Future<void> commitSeekPreview() async {
    if (_playbackDurationMs <= 0) return;
    final requestSerial = ++_seekRequestSerial;
    final targetPositionMs = _seekPreviewPositionMs ?? _playbackPositionMs;
    _playbackPositionMs = targetPositionMs.clamp(0, _playbackDurationMs);
    final targetPositionSnapshot = _playbackPositionMs;
    final priorState = _playbackState;
    _isSeeking = false;
    _seekPreviewPositionMs = null;
    _isTrackLoading = true;
    _pendingSeekPositionMs = targetPositionSnapshot;
    notifyListeners();
    try {
      await AudioPlayer.seek(positionMs: _playbackPositionMs);
      if (requestSerial != _seekRequestSerial) {
        return;
      }
      final progress = await AudioPlayer.getProgress();
      if (requestSerial != _seekRequestSerial) {
        return;
      }
      final effectiveProgress =
          progress.durationMs > 0
              ? progress
              : PlaybackProgress(
                  positionMs: targetPositionSnapshot,
                  durationMs: _playbackDurationMs,
                );
      syncPlaybackSnapshot(state: priorState, progress: effectiveProgress);
    } catch (e) {
      if (requestSerial != _seekRequestSerial) {
        return;
      }
      _isTrackLoading = false;
      _pendingSeekPositionMs = null;
      _playbackErrorMessage = e.toString();
      notifyListeners();
    }
  }

  void cancelSeekPreview() {
    if (!_isSeeking && _seekPreviewPositionMs == null) return;
    _isSeeking = false;
    _seekPreviewPositionMs = null;
    notifyListeners();
  }

  Future<String?> createPlaylist(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      return 'Playlist name is required.';
    }
    final exists = _playlists.any(
      (playlist) => playlist.name.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) {
      return 'A playlist named "$normalized" already exists.';
    }

    final playlist = Playlist(
      id: const Uuid().v4(),
      name: normalized,
      createdAt: DateTime.now(),
    );
    _playlists.add(playlist);
    await DatabaseService().insertPlaylist(playlist.toDb());
    notifyListeners();
    return null;
  }

  Future<String?> addSongsToPlaylist({
    required String playlistId,
    required List<ScrapedSong> songs,
  }) async {
    if (songs.isEmpty) {
      return 'No tracks selected.';
    }
    final playlistIndex = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (playlistIndex == -1) {
      return 'Playlist not found.';
    }

    final playlist = _playlists[playlistIndex];
    final existingKeys = playlist.tracks
        .map((track) => '${track.serverUrl}|${track.webDavHref}')
        .toSet();

    var nextOrder = playlist.tracks.length;
    final newTracks = <PlaylistTrack>[];
    for (final song in songs) {
      final key = '${song.serverUrl}|${song.webDavHref}';
      if (existingKeys.contains(key)) {
        continue;
      }
      existingKeys.add(key);
      newTracks.add(
        PlaylistTrack.fromScrapedSong(
          song,
          id: const Uuid().v4(),
          playlistId: playlistId,
          sortOrder: nextOrder++,
        ),
      );
    }

    if (newTracks.isEmpty) {
      return 'All selected tracks are already in this playlist.';
    }

    await DatabaseService().insertPlaylistTracks(newTracks);
    _playlists[playlistIndex] = playlist.copyWith(
      tracks: [...playlist.tracks, ...newTracks],
    );
    notifyListeners();
    return null;
  }

  Future<String?> createPlaylistWithSongs({
    required String name,
    required List<ScrapedSong> songs,
  }) async {
    final error = await createPlaylist(name);
    if (error != null) {
      return error;
    }
    final playlistId = _playlists.last.id;
    return addSongsToPlaylist(playlistId: playlistId, songs: songs);
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    await DatabaseService().deletePlaylist(playlistId);
    notifyListeners();
  }

  Future<void> removePlaylistTrack({
    required String playlistId,
    required String trackId,
  }) async {
    final playlistIndex = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (playlistIndex == -1) return;

    final playlist = _playlists[playlistIndex];
    final updatedTracks = playlist.tracks
        .where((track) => track.id != trackId)
        .toList();
    _playlists[playlistIndex] = playlist.copyWith(tracks: updatedTracks);
    await DatabaseService().deletePlaylistTrack(trackId);
    notifyListeners();
  }

  String _buildRemoteUrl(String serverUrl, String webDavHref) {
    final baseUri = Uri.parse(serverUrl);
    final href = webDavHref.trim();
    if (href.isEmpty) {
      return serverUrl;
    }

    final hrefUri = Uri.tryParse(href);
    if (hrefUri != null && hrefUri.hasScheme) {
      return hrefUri.toString();
    }

    return baseUri.resolveUri(Uri.parse(href)).toString();
  }

  String _buildDisplayPath(String webDavHref) {
    final href = webDavHref.trim();
    if (href.isEmpty) {
      return href;
    }

    final parsed = Uri.tryParse(href);
    final path = parsed?.path ?? href;
    return Uri.decodeFull(path);
  }

  String _songKey(ScrapedSong song) => '${song.serverUrl}|${song.webDavHref}';

  int? _resolveNextIndex() {
    if (_playbackQueue.isEmpty) return null;
    if (_playbackMode == PlaybackMode.shuffle && _playbackQueue.length > 1) {
      var nextIndex = _queueIndex;
      while (nextIndex == _queueIndex) {
        nextIndex = _random.nextInt(_playbackQueue.length);
      }
      return nextIndex;
    }
    if (_queueIndex + 1 < _playbackQueue.length) {
      return _queueIndex + 1;
    }
    return 0;
  }

  int? _resolvePreviousIndex() {
    if (_playbackQueue.isEmpty) return null;
    if (_queueIndex > 0) {
      return _queueIndex - 1;
    }
    return _playbackQueue.isEmpty ? null : _playbackQueue.length - 1;
  }

  void _resetPlaybackProgress() {
    _playbackPositionMs = 0;
    _playbackDurationMs = 0;
    _isSeeking = false;
    _seekPreviewPositionMs = null;
    _pendingSeekPositionMs = null;
  }
}
