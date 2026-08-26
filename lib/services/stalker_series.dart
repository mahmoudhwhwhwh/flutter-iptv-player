/// Pure helpers for the inconsistent series shapes returned by Stalker portals.
String stalkerSeriesParentId(String value) => value.split(':').first.trim();

Map<String, List<dynamic>> stalkerRowsToEpisodes(Iterable<dynamic> rows) {
  final result = <String, List<dynamic>>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty) continue;
    final season =
        (row['season_num'] ?? (id.contains(':') ? id.split(':').last : '1'))
            .toString()
            .trim();
    if (season.isEmpty) continue;
    final item = Map<String, dynamic>.from(row);
    item['episode_num'] ??= item['number'] ?? item['series_number'] ?? 1;
    result.putIfAbsent(season, () => <dynamic>[]).add(item);
  }
  return result;
}
