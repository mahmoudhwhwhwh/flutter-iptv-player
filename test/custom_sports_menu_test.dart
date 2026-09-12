import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/services/stalker_playback.dart';

void main() {
  test('Main_menu.json preserves all 21 entries and source media mappings', () {
    final file = File('Main_menu.json');
    expect(file.existsSync(), isTrue);

    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<List<dynamic>>());
    final menu = List<Map<String, dynamic>>.from(
      (decoded as List).map((item) => Map<String, dynamic>.from(item as Map)),
    );
    final sports = menu
        .where((item) => item['name'].toString().startsWith('SPORTS'))
        .toList();

    expect(menu, hasLength(21));
    expect(sports, hasLength(6));
    for (var index = 0; index < sports.length; index++) {
      final url = sports[index]['url'].toString();
      final sourceIndex = index + 9;
      final extension = index == 0 ? 'ts' : 'm3u8';
      expect(url,
          'https://iptv-subscription-api.tvkora56.workers.dev/v1/custom/stream/$sourceIndex.$extension?code=2027');
    }

    const hlsUrl = 'https://live-football-2mf.pages.dev/index_bein%20max1.m3u8';
    expect(hlsUrl, startsWith('https://'));
    expect(hlsUrl, endsWith('.m3u8'));
    expect(hlsUrl, isNot(contains('/v1/custom/stream/')));

    final publicMenu = jsonEncode(menu);
    expect(
        publicMenu,
        isNot(matches(RegExp(r'(password|username|token=|/live/.+/.+/.+)',
            caseSensitive: false))));
  });

  test('custom Worker TS URL with query is classified as direct media', () {
    const url =
        'https://iptv-subscription-api.tvkora56.workers.dev/v1/custom/stream/0.ts?code=2027';
    final descriptor = classifyPlaybackUrl(url);
    expect(descriptor.isDirectMedia, isTrue);
    expect(descriptor.kind, PlaybackSourceKind.transportStream);
    expect(isProgressiveTsUrl(url), isTrue);
  });
}
