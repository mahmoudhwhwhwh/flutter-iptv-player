import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/services/stalker_playback.dart';

void main() {
  test('recognizes an already-proxied Stalker TS stream', () {
    const url = 'https://worker.example/v1/stalker/stream?mac=masked&url=http%3A%2F%2Fline.example%2Fplay%2Flive.php%3Fextension%3Dts';
    expect(isWorkerStalkerStreamUrl(url), isTrue);
    expect(isDirectStalkerPlaybackUrl(url), isTrue);
    expect(isProgressiveTsUrl(url), isTrue);
  });

  test('recognizes direct and ffmpeg-prefixed TS playback URLs', () {
    expect(isDirectStalkerPlaybackUrl('ffmpeg http://media.example/play/live.php?extension=ts&play_token=masked'), isTrue);
    expect(isProgressiveTsUrl('http://media.example/live/1744949.ts'), isTrue);
    expect(isProgressiveTsUrl('http://media.example/play/live.php?extension=ts'), isTrue);
  });

  test('recognizes HLS and DASH in direct and proxied URLs', () {
    expect(isHlsPlaybackUrl('https://media.example/live/index.m3u8'), isTrue);
    expect(isDashPlaybackUrl('https://media.example/live/index.mpd'), isTrue);
    expect(isHlsPlaybackUrl('https://worker.example/v1/stalker/stream?url=https%3A%2F%2Fmedia.example%2Findex.m3u8'), isTrue);
    expect(isDashPlaybackUrl('https://worker.example/v1/stalker/stream?url=https%3A%2F%2Fmedia.example%2Findex.mpd'), isTrue);
    expect(isProgressiveTsUrl('https://media.example/live/index.m3u8'), isFalse);
    expect(isProgressiveTsUrl('https://media.example/live/index.mpd'), isFalse);
  });

  test('does not classify a non-playback Stalker command as a direct media URL', () {
    expect(isDirectStalkerPlaybackUrl('http://media.example/ch/1744949_'), isFalse);
  });

  test('classifies direct media and page URLs without pretending pages are media', () {
    expect(classifyPlaybackUrl('https://cdn.test/live/index.m3u8').kind,
        PlaybackSourceKind.hls);
    expect(classifyPlaybackUrl('https://cdn.test/live/manifest.mpd').kind,
        PlaybackSourceKind.dash);
    expect(classifyPlaybackUrl('https://cdn.test/live/1.ts').kind,
        PlaybackSourceKind.transportStream);
    expect(classifyPlaybackUrl('https://cdn.test/video.mp4').kind,
        PlaybackSourceKind.progressiveFile);

    final youtube = classifyPlaybackUrl('https://youtu.be/example');
    expect(youtube.kind, PlaybackSourceKind.youtubePage);
    expect(youtube.isDirectMedia, isFalse);
    expect(youtube.unsupportedReason, isNotEmpty);

    final page = classifyPlaybackUrl('https://example.com/watch/123');
    expect(page.kind, PlaybackSourceKind.webPage);
    expect(page.isDirectMedia, isFalse);

    expect(
      classifyPlaybackUrl('https://drive.google.com/uc?id=abc&export=download').kind,
      PlaybackSourceKind.progressiveFile,
    );
    expect(
      classifyPlaybackUrl('https://drive.google.com/file/d/abc/view').kind,
      PlaybackSourceKind.webPage,
    );
  });
}
