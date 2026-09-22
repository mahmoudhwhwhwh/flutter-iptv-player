import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/providers/iptv_provider.dart';

void main() {
  test('builds a standard Xtream live URL with encoded credentials', () {
    final url = buildXtreamLiveUrl(
      host: 'https://iptv.example:8080/',
      username: 'user@example',
      password: 'p/ass:word',
      streamId: '42',
      extension: 'mpeg-ts',
    );
    expect(url,
        'https://iptv.example:8080/live/user%40example/p%2Fass%3Aword/42.ts');
  });

  test('normalizes HLS and DASH extensions', () {
    expect(buildXtreamLiveUrl(
      host: 'https://iptv.example',
      username: 'u',
      password: 'p',
      streamId: '7',
      extension: 'hls',
    ), contains('/7.m3u8'));
    expect(buildXtreamLiveUrl(
      host: 'https://iptv.example',
      username: 'u',
      password: 'p',
      streamId: '8',
      extension: 'dash',
    ), contains('/8.mpd'));
  });
}

