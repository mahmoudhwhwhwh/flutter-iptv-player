import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/models/playlist_item.dart';
import 'package:flutter_iptv_player/services/filter_service.dart';

PlaylistItem item({required String id, required String type, required String name, required String category}) {
  return PlaylistItem(
    streamId: id,
    name: name,
    streamIcon: '',
    categoryId: '1',
    categoryName: category,
    url: 'https://example.test/$id.ts',
    type: type,
  );
}

void main() {
  test('topic channel filters do not remove movie and series entries', () {
    final entries = [
      item(id: 'live', type: 'live', name: 'Sports HD', category: 'Sports'),
      item(id: 'movie', type: 'movie', name: 'Drama Film', category: 'Movies'),
      item(id: 'series', type: 'series', name: 'Drama Series', category: 'Series'),
    ];

    final filtered = FilterService.interceptAndFilterStreams(
      entries,
      blockAdult: true,
      channelFilter: 'قنوات الرياضة فقط',
    );

    expect(filtered.map((entry) => entry.streamId), containsAll(<String>['live', 'movie', 'series']));
  });
}
