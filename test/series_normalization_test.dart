import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/main.dart';

void main() {
  test('normalizes episode lists into a first season', () {
    final episodes = normalizeSeriesEpisodes([
      {'id': 11, 'title': 'الحلقة 1'},
      {'episode_id': 12, 'title': 'الحلقة 2'},
    ]);
    expect(episodes.keys, contains('1'));
    expect(episodes['1'], hasLength(2));
  });

  test('normalizes season maps and preserves episode keys', () {
    final episodes = normalizeSeriesEpisodes({
      '1': [
        {'id': 21},
      ],
      '2': [
        {'stream_id': 31},
      ],
    });
    final seasons = normalizeSeriesSeasons({
      'first': {'season_number': 1, 'name': 'الأول'},
      'second': {'season_number': 2, 'name': 'الثاني'},
    }, episodes, '');
    expect(seasons.map((item) => item['season_number']), [1, 2]);
    expect(episodes['1'], hasLength(1));
    expect(episodes['2'], hasLength(1));
  });

  test('creates seasons when the provider omits the seasons field', () {
    final episodes = normalizeSeriesEpisodes({
      '3': [
        {'media_id': 41},
      ],
    });
    final seasons = normalizeSeriesSeasons(null, episodes, 'cover');
    expect(seasons.single['season_number'], '3');
    expect(seasons.single['episode_count'], 1);
  });

  test('normalizes episode maps keyed by episode id', () {
    final episodes = normalizeSeriesEpisodes({
      '2': {
        '201': {'id': 201, 'title': 'الحلقة 1'},
        '202': {'episode_id': 202, 'title': 'الحلقة 2'},
      },
    });
    expect(episodes['2'], hasLength(2));
    expect(episodes['2']!.first['id'], 201);
  });

  test('derives seasons from a map whose values are episode lists', () {
    final episodes = normalizeSeriesEpisodes({
      '4': [
        {'id': 401},
        {'id': 402},
      ],
    });
    final seasons = normalizeSeriesSeasons({
      '4': episodes['4'],
    }, episodes, 'cover');
    expect(seasons.single['season_number'], '4');
    expect(seasons.single['episode_count'], 2);
  });
}
