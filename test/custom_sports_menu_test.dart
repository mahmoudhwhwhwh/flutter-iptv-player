import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Main_menu.json exposes six safe TS proxy entries for SPORTS', () {
    final file = File('Main_menu.json');
    expect(file.existsSync(), isTrue);

    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<List<dynamic>>());
    final menu = List<Map<String, dynamic>>.from(
      (decoded as List).map((item) => Map<String, dynamic>.from(item as Map)),
    );
    final sports = menu.where((item) => item['name'].toString().startsWith('SPORTS')).toList();

    expect(sports, hasLength(6));
    for (var index = 0; index < sports.length; index++) {
      final url = sports[index]['url'].toString();
      expect(url, 'https://iptv-subscription-api.tvkora56.workers.dev/v1/custom/stream/$index.ts?code=2027');
      expect(url, isNot(contains('.m3u8')));
    }

    final publicMenu = jsonEncode(menu);
    expect(publicMenu, isNot(matches(RegExp(r'(password|username|token=|/live/.+/.+/.+)', caseSensitive: false))));
  });
}
