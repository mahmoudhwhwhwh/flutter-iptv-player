import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../lib/providers/iptv_provider.dart';

void main() {
  test('progressive TS playback leaves ExoPlayer format inference enabled', () {
    final player = File('lib/screens/player_screen.dart').readAsStringSync();
    final multi = File('lib/screens/multi_screen_player.dart').readAsStringSync();

    expect(player, contains('format = null;'));
    expect(multi, contains('format = null;'));
    expect(player, isNot(contains('format = BetterPlayerVideoFormat.other;')));
    expect(multi, isNot(contains('format = BetterPlayerVideoFormat.other;')));
  });

  test('normalizes descriptive live containers to playable TS', () {
    expect(normalizeXtreamMediaExtension('live'), 'ts');
    expect(normalizeXtreamMediaExtension('raw'), 'ts');
    expect(normalizeXtreamMediaExtension('mpeg-ts'), 'ts');
    expect(normalizeXtreamMediaExtension('m3u8'), 'm3u8');
    expect(normalizeXtreamMediaExtension('mpd'), 'mpd');
  });
}
