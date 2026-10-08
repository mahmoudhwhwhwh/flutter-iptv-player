import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/playlist_item.dart';
import '../providers/iptv_provider.dart';
import '../services/app_translations.dart';
import 'player_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _matches = [];
  String _filterStatus = 'all'; // all, live, upcoming, finished
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final dateStr = _formatDate(_selectedDate);
    final url =
        'https://api-ar.ysscores.com/api/matches/matches_date_get/$dateStr/%5B%2299376%22,%22408340%22%5D/%5B%5D/%5B%228633%22%5D/D/180';

    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko)',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        final data = decoded is Map ? decoded['data'] : null;
        final list = <Map<String, dynamic>>[];
        if (data is List) {
          for (final item in data) {
            if (item is Map) list.add(Map<String, dynamic>.from(item));
          }
        }
        if (mounted) {
          setState(() {
            _matches = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'تعذر تحميل المباريات لهذا اليوم';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر الاتصال بجدول المباريات';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMatches {
    return _matches.where((m) {
      final isLive = m['live'] == 1 || m['live'] == '1';
      final status = m['status']?.toString() ?? '0';
      final isFinished = status == '1' || status == '2' || status == 'FT';
      final isUpcoming = !isLive && !isFinished;

      if (_filterStatus == 'live' && !isLive) return false;
      if (_filterStatus == 'upcoming' && !isUpcoming) return false;
      if (_filterStatus == 'finished' && !isFinished) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final home = (m['home_team']?['title'] ?? '').toString().toLowerCase();
        final away = (m['away_team']?['title'] ?? '').toString().toLowerCase();
        final champ =
            (m['championship']?['title'] ?? '').toString().toLowerCase();
        if (!home.contains(q) && !away.contains(q) && !champ.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedMatches {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final m in _filteredMatches) {
      final champ =
          (m['championship']?['title'] ?? 'مباريات متنوعة').toString();
      if (!map.containsKey(champ)) {
        map[champ] = [];
      }
      map[champ]!.add(m);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final lang = provider.appLanguageCode;
    final isRtl = AppTranslations.isRtl(lang);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF14141E),
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sports_soccer_rounded,
                    color: Color(0xFF22C55E), size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                AppTranslations.get('matches', lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              onPressed: _fetchMatches,
            ),
            IconButton(
              tooltip: 'اختيار التاريخ',
              icon: const Icon(Icons.calendar_month_rounded,
                  color: Color(0xFF2DD4BF)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFFA855F7),
                        surface: Color(0xFF1E1E28),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null && picked != _selectedDate) {
                  setState(() => _selectedDate = picked);
                  _fetchMatches();
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildDateSelector(),
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                      ),
                    )
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : _filteredMatches.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _fetchMatches,
                              color: const Color(0xFFA855F7),
                              backgroundColor: const Color(0xFF1E1E28),
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                children: _groupedMatches.entries.map((entry) {
                                  return _buildChampionshipGroup(
                                      entry.key, entry.value, provider);
                                }).toList(),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));
    final afterTomorrow = now.add(const Duration(days: 2));

    final dates = [
      {'label': 'أمس', 'date': yesterday},
      {'label': 'اليوم', 'date': now},
      {'label': 'غداً', 'date': tomorrow},
      {'label': 'بعد غد', 'date': afterTomorrow},
    ];

    return Container(
      color: const Color(0xFF14141E),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: dates.map((d) {
          final dt = d['date'] as DateTime;
          final isSelected = dt.year == _selectedDate.year &&
              dt.month == _selectedDate.month &&
              dt.day == _selectedDate.day;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedDate = dt);
                _fetchMatches();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF1E1E28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFA855F7)
                        : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Center(
                  child: Text(
                    d['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterBar() {
    final liveCount =
        _matches.where((m) => m['live'] == 1 || m['live'] == '1').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF12121A),
      child: Row(
        children: [
          _buildFilterChip('الكل (${_matches.length})', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip(
              liveCount > 0 ? '🔴 مباشر ($liveCount)' : 'مباشر (0)', 'live',
              highlight: liveCount > 0),
          const SizedBox(width: 8),
          _buildFilterChip('لم تبدأ', 'upcoming'),
          const SizedBox(width: 8),
          _buildFilterChip('انتهت', 'finished'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value,
      {bool highlight = false}) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (highlight ? Colors.redAccent : const Color(0xFFA855F7))
              : (highlight
                  ? Colors.redAccent.withOpacity(0.15)
                  : const Color(0xFF1E1E28)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (highlight ? Colors.redAccent : const Color(0xFFA855F7))
                : (highlight
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.white12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (highlight ? Colors.redAccent : Colors.white70),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildChampionshipGroup(String championship,
      List<Map<String, dynamic>> matches, IPTVProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF171724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFFFC857), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    championship,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                Text(
                  '${matches.length} مباريات',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.white.withOpacity(0.04), height: 1),
            itemBuilder: (context, i) {
              return _buildMatchTile(matches[i], provider);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> m, IPTVProvider provider) {
    final home = m['home_team'] is Map ? m['home_team'] : {};
    final away = m['away_team'] is Map ? m['away_team'] : {};
    final homeTitle = (home['title'] ?? 'الفريق الأول').toString();
    final awayTitle = (away['title'] ?? 'الفريق الثاني').toString();
    final homeLogo = (home['image'] ?? '').toString();
    final awayLogo = (away['image'] ?? '').toString();

    final isLive = m['live'] == 1 || m['live'] == '1';
    final status = m['status']?.toString() ?? '0';
    final isFinished = status == '1' || status == '2' || status == 'FT';

    final homeScore = m['home_scores']?.toString();
    final awayScore = m['away_scores']?.toString();

    String rawTime = (m['match_time'] ?? '').toString();
    if (rawTime.length >= 5) {
      rawTime = rawTime.substring(0, 5);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        homeTitle,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTeamLogo(homeLogo),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isLive
                      ? Colors.redAccent.withOpacity(0.18)
                      : const Color(0xFF1E1E28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLive
                        ? Colors.redAccent.withOpacity(0.4)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  children: [
                    if (isLive || isFinished)
                      Text(
                        '${homeScore ?? '0'} - ${awayScore ?? '0'}',
                        style: TextStyle(
                          color: isLive ? Colors.redAccent : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      )
                    else
                      Text(
                        rawTime.isNotEmpty ? rawTime : '--:--',
                        style: const TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      isLive
                          ? '🔴 مباشر'
                          : (isFinished ? 'انتهت' : 'قريباً'),
                      style: TextStyle(
                        color: isLive
                            ? Colors.redAccent
                            : (isFinished ? Colors.white54 : const Color(0xFF2DD4BF)),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    _buildTeamLogo(awayLogo),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        awayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _watchMatchStream(context, homeTitle, awayTitle, provider),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFA855F7).withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.live_tv_rounded,
                      color: Color(0xFFA855F7), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isLive ? 'مشاهدة البث المباشر للمباراة' : 'البحث عن القناة الناقلة',
                    style: const TextStyle(
                      color: Color(0xFFD8B4FE),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String url) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black26,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.sports_soccer_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
              )
            : const Icon(
                Icons.sports_soccer_rounded,
                color: Colors.white38,
                size: 16,
              ),
      ),
    );
  }

  void _watchMatchStream(BuildContext context, String home, String away,
      IPTVProvider provider) {
    final sportsStreams = provider.allStreams
        .where((s) =>
            s.type == 'live' &&
            (provider.isSportsStream(s) ||
                s.name.toLowerCase().contains('bein') ||
                s.name.toLowerCase().contains('ssc') ||
                s.name.toLowerCase().contains('ad sport') ||
                s.name.toLowerCase().contains('alkass') ||
                s.name.toLowerCase().contains(home.toLowerCase()) ||
                s.name.toLowerCase().contains(away.toLowerCase())))
        .toList();

    if (sportsStreams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم العثور على قناة ناقلة متاحة حالياً',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    PlaylistItem target = sportsStreams.first;
    for (final s in sportsStreams) {
      if (s.name.contains(home) || s.name.contains(away)) {
        target = s;
        break;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(stream: target),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                color: Colors.white30, size: 54),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _fetchMatches,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA855F7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 54, color: Colors.white30),
          ),
          const SizedBox(height: 14),
          const Text(
            'لا توجد مباريات مسجلة لهذا التاريخ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'جرب اختيار تاريخ آخر من الشريط العلوي',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
