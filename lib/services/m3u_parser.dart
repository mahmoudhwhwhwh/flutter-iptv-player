import '../models/playlist_item.dart';
import 'filter_service.dart';

class M3UParser {
  static Map<String, dynamic> parse(String content, {bool blockAdult = true, String channelFilter = "الكل"}) {
    // 1. اعتراض السلسلة النصية الخام وتنظيفها من القنوات الإباحية قبل الـ Parsing (Interception at source)
    final cleanedContent = FilterService.interceptAndCleanRawM3U(content, blockAdult: blockAdult);

    final List<PlaylistItem> items = [];
    final Set<String> categories = {};
    
    final lines = cleanedContent.split('\n');
    Map<String, String>? currentMeta;
    int counter = 1;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final infoPart = line.substring(8);
        
        // Extract logo
        final logoRegExp = RegExp(r'tvg-logo="([^"]+)"', caseSensitive: false);
        final logoMatch = logoRegExp.firstMatch(infoPart);
        final logo = logoMatch != null ? logoMatch.group(1) ?? "" : "";

        // Extract category group
        final groupRegExp = RegExp(r'group-title="([^"]+)"', caseSensitive: false);
        final groupMatch = groupRegExp.firstMatch(infoPart);
        final group = groupMatch != null ? groupMatch.group(1) ?? "Uncategorized" : "Uncategorized";

        // Extract ID
        final idRegExp = RegExp(r'tvg-id="([^"]+)"', caseSensitive: false);
        final idMatch = idRegExp.firstMatch(infoPart);
        final id = idMatch != null ? idMatch.group(1) ?? "" : "";

        // Channel Name
        final lastCommaIdx = line.lastIndexOf(',');
        String name = "Channel $counter";
        if (lastCommaIdx != -1 && lastCommaIdx < line.length - 1) {
          name = line.substring(lastCommaIdx + 1).trim();
        }

        currentMeta = {
          'name': name,
          'logo': logo,
          'group': group,
          'id': id.isNotEmpty ? id : 'item_$counter',
        };
      } else if (line.startsWith('#')) {
        continue;
      } else {
        if (currentMeta != null) {
          final catId = currentMeta['group']!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
          categories.add(currentMeta['group']!);

          String type = "live";
          final urlLower = line.toLowerCase();
          if (urlLower.contains('/movie/') || urlLower.endsWith('.mp4') || urlLower.endsWith('.mkv')) {
            type = "movie";
          } else if (urlLower.contains('/series/') || urlLower.contains('s01e')) {
            type = "series";
          }

          items.add(
            PlaylistItem(
              num: counter++,
              streamId: "${currentMeta['id']}_$counter",
              name: currentMeta['name']!,
              streamIcon: currentMeta['logo']!,
              categoryId: catId.isEmpty ? 'uncategorized' : catId,
              categoryName: currentMeta['group']!,
              url: line,
              type: type,
            ),
          );
          currentMeta = null;
        }
      }
    }

    // 2. تصفية الفئات (Category interception)
    final List<Map<String, String>> categoriesList = categories.map((cat) {
      final catId = cat.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      return {
        'category_id': catId.isEmpty ? 'uncategorized' : catId,
        'category_name': cat,
      };
    }).toList();

    final filteredCategories = FilterService.interceptAndFilterCategories(
      categoriesList,
      blockAdult: blockAdult,
    );

    // 3. تصفية القنوات الناتجة بالكامل (Stream interception)
    final filteredItems = FilterService.interceptAndFilterStreams(
      items,
      blockAdult: blockAdult,
      channelFilter: channelFilter,
    );

    return {
      'items': filteredItems,
      'categories': filteredCategories.map((c) => c['category_name']!).toList(),
    };
  }
}
