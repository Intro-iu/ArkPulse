import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart';

class SMTCService {
  SMTCService._();
  static final SMTCService instance = SMTCService._();

  SMTCWindows? _smtc;

  bool get isSupported => Platform.isWindows && !kIsWeb;

  Future<void> init({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
  }) async {
    if (!isSupported) return;

    try {
      // Must initialize the flutter_rust_bridge from the smtc_windows library first
      await SMTCWindows.initialize();

      _smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: false,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );

      _smtc?.buttonPressStream.listen((event) {
        switch (event) {
          case PressedButton.play:
            onPlay();
            break;
          case PressedButton.pause:
            onPause();
            break;
          case PressedButton.next:
            onNext();
            break;
          case PressedButton.previous:
            onPrevious();
            break;
          default:
            break;
        }
      });
    } catch (e) {
      debugPrint('SMTC Init Error: $e');
    }
  }

  void updatePlaybackState(bool isPlaying) {
    if (!isSupported || _smtc == null) return;
    _smtc?.setPlaybackStatus(
      isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
    );
  }

  void stop() {
    if (!isSupported || _smtc == null) return;
    _smtc?.setPlaybackStatus(PlaybackStatus.stopped);
    _smtc?.clearMetadata();
  }

  void updateMetadata({
    required String title,
    required String artist,
    required String album,
  }) {
    if (!isSupported || _smtc == null) return;
    try {
      _smtc?.updateMetadata(
        MusicMetadata(title: title, artist: artist, album: album),
      );
    } catch (e) {
      debugPrint('SMTC Metadata Sync Error: $e');
    }
  }
}
