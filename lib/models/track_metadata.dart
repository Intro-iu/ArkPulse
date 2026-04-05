import 'dart:typed_data';
import '../src/rust/api/player_api.dart';
import 'webdav_config.dart';

class TimedLyricLine {
  final int timestampMs;
  final String text;

  const TimedLyricLine({required this.timestampMs, required this.text});
}

class ParsedLyrics {
  final List<TimedLyricLine> timedLines;
  final List<String> plainLines;

  const ParsedLyrics({this.timedLines = const [], this.plainLines = const []});

  bool get hasTimedLyrics => timedLines.isNotEmpty;
  bool get hasLyrics => hasTimedLyrics || plainLines.isNotEmpty;

  int activeIndexForPosition(int positionMs) {
    if (timedLines.isEmpty) {
      return -1;
    }
    for (var i = timedLines.length - 1; i >= 0; i--) {
      if (positionMs >= timedLines[i].timestampMs) {
        return i;
      }
    }
    return 0;
  }

  static ParsedLyrics parse(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const ParsedLyrics();
    }

    final timed = <TimedLyricLine>[];
    final plain = <String>[];
    final lines = normalized.split(RegExp(r'\r?\n'));
    final tagPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

    for (final originalLine in lines) {
      final line = originalLine.trimRight();
      if (line.trim().isEmpty) {
        continue;
      }
      final matches = tagPattern.allMatches(line).toList();
      if (matches.isEmpty) {
        plain.add(line.trim());
        continue;
      }

      final text = line.replaceAll(tagPattern, '').trim();
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionRaw = match.group(3) ?? '';
        final millis = switch (fractionRaw.length) {
          0 => 0,
          1 => (int.tryParse(fractionRaw) ?? 0) * 100,
          2 => (int.tryParse(fractionRaw) ?? 0) * 10,
          _ => int.tryParse(fractionRaw.padRight(3, '0').substring(0, 3)) ?? 0,
        };
        timed.add(
          TimedLyricLine(
            timestampMs: minutes * 60000 + seconds * 1000 + millis,
            text: text.isEmpty ? '...' : text,
          ),
        );
      }
    }

    timed.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return ParsedLyrics(timedLines: timed, plainLines: plain);
  }
}

class StandardTrackMetadata {
  final String title;
  final String subtitle;
  final String artist;
  final String albumArtist;
  final String album;
  final String genre;
  final String date;
  final String trackNumber;
  final String discNumber;
  final int durationMs;
  final String lyrics;
  final ParsedLyrics parsedLyrics;
  final Uint8List? coverArt;

  const StandardTrackMetadata({
    required this.title,
    required this.subtitle,
    required this.artist,
    required this.albumArtist,
    required this.album,
    required this.genre,
    required this.date,
    required this.trackNumber,
    required this.discNumber,
    required this.durationMs,
    required this.lyrics,
    required this.parsedLyrics,
    this.coverArt,
  });

  factory StandardTrackMetadata.fromSources(
    ScrapedSong? song,
    TrackInfo? trackInfo,
  ) {
    final title = _firstNonEmpty([
      trackInfo?.title,
      song?.title,
      'Unknown Title',
    ]);
    final subtitle = _firstNonEmpty([trackInfo?.subtitle, '']);
    final artist = _firstNonEmpty([
      trackInfo?.artist,
      song?.artist,
      'Unknown Artist',
    ]);
    final albumArtist = _firstNonEmpty([
      trackInfo?.albumArtist,
      trackInfo?.artist,
      song?.artist,
      '',
    ]);
    final album = _firstNonEmpty([
      trackInfo?.album,
      song?.album,
      'Unknown Album',
    ]);
    final genre = _firstNonEmpty([trackInfo?.genre, '']);
    final date = _firstNonEmpty([trackInfo?.date, '']);
    final trackNumber = _firstNonEmpty([trackInfo?.trackNumber, '']);
    final discNumber = _firstNonEmpty([trackInfo?.discNumber, '']);
    final lyrics = (trackInfo?.lyrics ?? '').trim();

    return StandardTrackMetadata(
      title: title,
      subtitle: subtitle,
      artist: artist,
      albumArtist: albumArtist,
      album: album,
      genre: genre,
      date: date,
      trackNumber: trackNumber,
      discNumber: discNumber,
      durationMs: trackInfo?.durationMs ?? song?.durationMs ?? 0,
      lyrics: lyrics,
      parsedLyrics: ParsedLyrics.parse(lyrics),
      coverArt: trackInfo?.coverArt,
    );
  }

  String get heroLine {
    final fragments = <String>[
      artist,
      if (album.isNotEmpty) album,
      if (date.isNotEmpty) date,
    ];
    return fragments.join(' // ');
  }

  String get archiveCode {
    final fragments = <String>[
      if (discNumber.isNotEmpty) 'DISC $discNumber',
      if (trackNumber.isNotEmpty) 'TRK $trackNumber',
      if (genre.isNotEmpty) genre,
    ];
    return fragments.join(' // ');
  }
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}
