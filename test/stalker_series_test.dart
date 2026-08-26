import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/services/stalker_series.dart';

void main() {
  test('extracts the parent series id from Stalker composite ids', () {
    expect(stalkerSeriesParentId('8846:1'), '8846');
    expect(stalkerSeriesParentId('8846'), '8846');
  });

  test('groups Stalker rows by season and preserves playback command', () {
    final episodes = stalkerRowsToEpisodes([
      {'id': '8846:1', 'name': 'Season 1', 'cmd': 'opaque-command'},
      {
        'id': '8846:2',
        'name': 'Episode 2',
        'season_num': 1,
        'series_number': 2
      },
      {'id': '', 'name': 'invalid'},
    ]);
    expect(episodes.keys, contains('1'));
    expect(episodes['1'], hasLength(2));
    expect(episodes['1']!.first['cmd'], 'opaque-command');
    expect(episodes['1']!.last['episode_num'], 2);
  });
}
