import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'catalog_webview_screen.dart';

const List<String> kDefaultSportsShowcaseUrls = <String>[
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/new_banner_salah.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_1.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_2.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_3.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_4.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_5.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_6.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_7.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_8.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_9.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_10.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_11.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_12.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_13.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_14.jpg',
  'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/sport_15.png',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/drydqgsQCZcHPQOE.jpeg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/UsMUEQZteddHmwBD.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/GIzmNyaEtCEEJHap.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/wTTbGDTucVMjiQnV.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/WhsGmYVkJjonzprk.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/LrbFrdXdLmuxqhTQ.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/hmoDHYheLxTLoaHZ.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/OlOEgrWrMidnajLO.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/ZVzgyJLhDbgeolsr.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/sNToXbWmQEHixEfN.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/UKBRotOdjIpQrLTX.jpeg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/cHSIAnFUsOeJjlHg.jpeg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/cNHVCwUQvRtbKTNO.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/gonOzijsqEOQWwoK.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/uqwnQmIJxMlQWjnQ.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/gtOwkbfGHxvJGecj.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/AUXKqOvFTgIyvebw.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/jRkSHeyeqPYDiIoM.jpeg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/yGlcKrFfCcPkuuYW.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/jSCVClKGbNUWPNKA.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/ZZJOYDRWLWUApAdy.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/WGbjGGLUWVWTucKy.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/cdRppflaZUaUQVnL.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/kfOzMNMsejaXonrc.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/CgMGzmjJMtpGJPbo.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/ocRRxxIoRzPPxTTc.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/oIXWupwYQfRhpeUI.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/nPQMDerTlQxxJTLW.webp',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/urkEpvLZDyeEuxcd.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/cdCuLEpxyuSnyKXj.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/PJYuTtXrxiZTQUuq.jpeg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/ybriNlALTxDTjxCw.jpeg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/viRhJdepdapHQLNP.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/CnmyMnBgexGCcGJl.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/FHIVrzglKaAURskC.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/wvxIdmXKAhuCfcYT.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/AJfoNdLFOvomvxEP.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/UgPkTSoETGldbPwr.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/cHcXNUvtgKyEJvTR.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/nnrYXXXNdBTEeojJ.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/SuFfNkmzPlEbiFjm.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/qcBncpLjPaZKNXJe.png',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/kLmJZjEwCLhGktua.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/YLfZulJcJtEOKpZw.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/fvDqKVOXDJBzvTuo.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/qKixsJYsxgcCCPaw.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/JITgseyFRTRfGJFP.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/NkIovWkaDDEjyUXk.jpg',
  'https://files.manuscdn.com/user_upload_by_module/session_file/310519663703079074/tcmeEtqBRqLouVmt.jpg',
];

const List<String> _kCuratedSportsHeadlines = <String>[
  'تغطية خاصة: أبرز مواجهات ونجوم الكرة العالمية والأوروبية',
  'دوري أبطال أوروبا: قمم نارية وصراع التأهل للأدوار الإقصائية',
  'الدوري الإنجليزي الممتاز: صراع الصدارة وتألق النجوم العرب',
  'الدوري الإسباني: كلاسيكو الأرض ومنافسة محتدمة على اللقب',
  'الدوري الإيطالي: مواجهات تكتيكية كبرى في الكالتشيو',
  'الدوري الألماني: إثارة البوندسليغا وأهداف حاسمة',
  'الدوري الفرنسي: نجوم باريس والمنافسة الأوروبية',
  'دوري روشن السعودي: صفقات عالمية ومباريات جماهيرية كبرى',
  'المنتخبات العربية: استعدادات قوية للتصفيات والبطولات القارية',
  'سوق الانتقالات: أبرز الصفقات والتحركات في الأندية الكبرى',
  'أرقام قياسية: إحصائيات استثنائية لأفضل هدافي الموسم',
  'مواعيد المباريات الكبرى: جدول القمم الكروية المنتظرة',
  'تحليل فني: قراءة شاملة في خطط المدربين الكبار',
  'الكرة الأفريقية والآسيوية: صراع الأبطال على الألقاب القارية',
  'نجوم الملاعب: أبرز لقطات الأسبوع الكروي العالمي',
  'تغطية حصرية: كواليس الملاعب وأخبار الأندية لحظة بلحظة',
];

String normalizeSportsShowcaseUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.replaceAll(
    'mahmoudhwhwhwh/live-stream-premium/',
    'mahmoudhwhwhwh/flutter-iptv-player/',
  );
}

List<Map<String, dynamic>> buildCuratedShowcaseNewsItems(
    [List<String>? customUrls]) {
  final sourceUrls = (customUrls != null && customUrls.isNotEmpty)
      ? customUrls
      : kDefaultSportsShowcaseUrls;
  final seen = <String>{};
  final items = <Map<String, dynamic>>[];

  for (var i = 0; i < sourceUrls.length; i++) {
    final cleanUrl = normalizeSportsShowcaseUrl(sourceUrls[i]);
    if (cleanUrl.isEmpty || cleanUrl.contains('CecUqep.png')) continue;
    if (!seen.add(cleanUrl)) continue;
    final headline =
        _kCuratedSportsHeadlines[items.length % _kCuratedSportsHeadlines.length];
    items.add(<String, dynamic>{
      'Title': headline,
      'Description':
          '$headline — متابعة رياضية مصورة لأحدث الأخبار والمباريات والبطولات العالمية والعربية.',
      'CategoryName': 'أخبار رياضية مميزة',
      'TourName': 'تغطية خاصة',
      'Date': 'تحديث مباشر',
      'IsShowcase': true,
      'Picture': <String, dynamic>{
        'BigPath': cleanUrl,
        'MeduimPath': cleanUrl,
        'SmallPath': cleanUrl,
      },
    });
  }
  return items;
}

Future<List<String>> fetchSportsShowcaseUrls() async {
  final results = <String>[];
  final seen = <String>{};

  void addUrl(String raw) {
    final normalized = normalizeSportsShowcaseUrl(raw);
    if (normalized.isEmpty || normalized.contains('CecUqep.png')) return;
    if (seen.add(normalized)) {
      results.add(normalized);
    }
  }

  // First add the curated sport_1..sport_15 & salah banners so they are always at the front
  for (final u in kDefaultSportsShowcaseUrls.take(16)) {
    addUrl(u);
  }

  try {
    final res = await http
        .get(Uri.parse(
            'https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/app_Slider.json'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final decoded = json.decode(res.body);
      if (decoded is List) {
        for (final item in decoded) {
          addUrl(item.toString());
        }
      }
    }
  } catch (_) {}

  for (final u in kDefaultSportsShowcaseUrls) {
    addUrl(u);
  }

  return results;
}

void showSportsNewsDetailSheet(
    BuildContext context, Map<String, dynamic> item) {
  final picture = item['Picture'] is Map
      ? Map<String, dynamic>.from(item['Picture'])
      : const <String, dynamic>{};
  final imageUrl = normalizeSportsShowcaseUrl((picture['BigPath'] ??
          picture['MeduimPath'] ??
          picture['SmallPath'] ??
          '')
      .toString());
  final title = (item['Title'] ?? 'خبر رياضي').toString();
  final description = (item['Description'] ?? '').toString().trim();
  final categoryName = (item['CategoryName'] ?? 'أخبار الرياضة').toString();
  final tourName = (item['TourName'] ?? '').toString();
  final rawDate = (item['Date'] ?? '').toString().replaceFirst('T', ' ');
  final articleUrl =
      (item['Url'] ?? item['NewsUrl'] ?? item['ShareUrl'] ?? '').toString();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14112B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 220,
                        maxHeight: 460,
                      ),
                      color: const Color(0xFF0E0B1E),
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.0,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF211C42)),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (categoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFA855F7).withOpacity(0.5)),
                        ),
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            color: Color(0xFFD8B4FE),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (tourName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2DD4BF).withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2DD4BF).withOpacity(0.45)),
                        ),
                        child: Text(
                          tourName,
                          style: const TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                if (rawDate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        rawDate,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Text(
                  description.isNotEmpty ? description : title,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 16,
                    height: 1.65,
                  ),
                ),
                if (articleUrl.startsWith('http')) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CatalogWebViewScreen(
                            title: title,
                            url: Uri.parse(articleUrl),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.article_rounded),
                    label: const Text(
                      'قراءة الخبر كاملاً',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    },
  );
}

class SportsNewsScreen extends StatefulWidget {
  const SportsNewsScreen({super.key});

  @override
  State<SportsNewsScreen> createState() => _SportsNewsScreenState();
}

class _SportsNewsScreenState extends State<SportsNewsScreen> {
  List<Map<String, dynamic>> _news = buildCuratedShowcaseNewsItems();
  bool _loading = false;
  bool _loadingMore = false;
  int _pageIndex = 1;
  String _selectedCategory = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadNews(reset: true);
  }

  Future<void> _loadNews({bool reset = false}) async {
    if (reset) {
      setState(() {
        _pageIndex = 1;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final showcaseUrls = await fetchSportsShowcaseUrls();
    final curatedItems = buildCuratedShowcaseNewsItems(showcaseUrls);

    final apiItems = <Map<String, dynamic>>[];
    try {
      final targetPage = reset ? 1 : (_pageIndex + 1);
      final uri = Uri.parse(
        'https://sportfeeds.gemini.media/yallakoraapi/NewsList?pageIndex=$targetPage&pageSize=20&otherSportsNews=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              apiItems.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      if (!reset && apiItems.isNotEmpty) {
        _pageIndex = targetPage;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      if (reset) {
        _news = <Map<String, dynamic>>[
          ...curatedItems,
          ...apiItems,
        ];
      } else {
        _news = <Map<String, dynamic>>[
          ..._news,
          ...apiItems,
        ];
      }
      _loading = false;
      _loadingMore = false;
    });
  }

  List<String> get _categories {
    final set = <String>{'الكل'};
    for (final item in _news) {
      final cat = (item['CategoryName'] ?? '').toString().trim();
      if (cat.isNotEmpty) set.add(cat);
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredNews {
    if (_selectedCategory == 'الكل') return _news;
    return _news
        .where((item) =>
            (item['CategoryName'] ?? '').toString().trim() == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    final filtered = _filteredNews;
    final categories = _categories;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.newspaper_rounded, color: accent, size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الأخبار الرياضية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: () => _loadNews(reset: true),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (categories.length > 1)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final selected = _selectedCategory == cat;
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? accent : surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? accent : accent.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFFD2D2DA),
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading && filtered.isEmpty
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : RefreshIndicator(
                      color: accent,
                      onRefresh: () => _loadNews(reset: true),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              isMobile ? 1 : (screenW < 1000 ? 2 : 3),
                          mainAxisExtent: 265,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            return Center(
                              child: _loadingMore
                                  ? CircularProgressIndicator(color: accent)
                                  : OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                            color: accent.withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                      ),
                                      onPressed: () =>
                                          _loadNews(reset: false),
                                      icon: const Icon(
                                          Icons.expand_more_rounded),
                                      label: const Text(
                                          'عرض المزيد من الأخبار'),
                                    ),
                            );
                          }
                          final item = filtered[index];
                          final picture = item['Picture'] is Map
                              ? Map<String, dynamic>.from(item['Picture'])
                              : const <String, dynamic>{};
                          final imageUrl = normalizeSportsShowcaseUrl(
                              (picture['MeduimPath'] ??
                                      picture['BigPath'] ??
                                      picture['SmallPath'] ??
                                      '')
                                  .toString());
                          final title =
                              (item['Title'] ?? 'خبر رياضي').toString();
                          final date = (item['Date'] ?? '')
                              .toString()
                              .replaceFirst('T', ' ');
                          final catName =
                              (item['CategoryName'] ?? '').toString();
                          final tourName =
                              (item['TourName'] ?? '').toString();

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () =>
                                showSportsNewsDetailSheet(context, item),
                            child: Container(
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: accent.withOpacity(0.22)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        imageUrl.isEmpty
                                            ? const ColoredBox(
                                                color: Color(0xFF211C42))
                                            : CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    const ColoredBox(
                                                        color: Color(
                                                            0xFF211C42)),
                                              ),
                                        if (tourName.isNotEmpty ||
                                            catName.isNotEmpty)
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.75),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                tourName.isNotEmpty
                                                    ? tourName
                                                    : catName,
                                                style: const TextStyle(
                                                  color: Color(0xFFFFC857),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 6),
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  if (date.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 0, 12, 10),
                                      child: Text(
                                        date,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
