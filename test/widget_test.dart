import 'package:arkpulse/models/webdav_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes supported audio file extensions', () {
    expect(isAudioFile('track.flac'), isTrue);
    expect(isAudioFile('folder/anthem.MP3'), isTrue);
    expect(isAudioFile('cover.jpg'), isFalse);
    expect(isAudioFile('README'), isFalse);
  });

  test('serializes scraped songs for database persistence', () {
    const song = ScrapedSong(
      id: 'song-1',
      configId: 'config-1',
      title: 'Awakening',
      artist: 'Closure',
      album: 'Signals',
      path: '/music/closure-awakening.flac',
      webDavHref: '/dav/music/closure-awakening.flac',
      remoteUrl: 'https://dav.example.com/music/closure-awakening.flac',
      serverUrl: 'https://dav.example.com',
      username: 'tester',
      password: 'secret',
      format: 'FLAC',
      bitrate: 'N/A',
      durationMs: 0,
    );

    expect(ScrapedSong.fromDb(song.toDb()).title, 'Awakening');
    expect(ScrapedSong.fromDb(song.toDb()).configId, 'config-1');
    expect(ScrapedSong.fromDb(song.toDb()).webDavHref, '/dav/music/closure-awakening.flac');
  });
}
