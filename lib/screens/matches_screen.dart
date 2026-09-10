import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/playlist_item.dart';
import 'player_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({Key? key}) : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _NewsHeadline extends StatelessWidget {
  final String title;
  const _NewsHeadline({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 16));
  }
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<dynamic> _matchesList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await http.get(Uri.parse(
          'https://iptv-subscription-api.tvkora56.workers.dev/v1/matches?t=${DateTime.now().millisecondsSinceEpoch}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _matchesList = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'فشل تحميل جدول المباريات. رمز: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء الاتصال بالخادم الرئيسي';
        _isLoading = false;
      });
    }
  }

  void _watchMatch(Map<String, dynamic> match, int index) {
    final streamUrl = match['stream_url'];
    if (streamUrl == null || (streamUrl as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('البث المباشر غير متوفر حالياً لهذه المباراة')),
      );
      return;
    }

    final stream = PlaylistItem(
      streamId: 'match_$index',
      name: '${match['team_a']} 🆚 ${match['team_b']}',
      streamIcon: match['team_a_logo'] ?? '',
      categoryId: 'matches',
      categoryName: 'المباريات المباشرة',
      url: streamUrl,
      type: 'live',
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'جدول مباريات اليوم',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchMatches,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchMatches,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          )
                        ],
                      ),
                    ),
                  )
                : _matchesList.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد مباريات مجدولة اليوم',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _matchesList.length,
                        itemBuilder: (context, index) {
                          final match = _matchesList[index];
                          final isLive = match['status'] == 'مباشر';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        match['tournament'] ?? 'بطولة رياضية',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isLive
                                              ? Colors.red.withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            if (isLive)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(left: 6),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            Text(
                                              match['status'] ?? 'قريباً',
                                              style: TextStyle(
                                                color: isLive ? Colors.red : Colors.grey[400],
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24, thickness: 0.5),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            if (match['team_a_logo'] != null &&
                                                (match['team_a_logo'] as String).isNotEmpty)
                                              Image.network(
                                                match['team_a_logo'],
                                                width: 55,
                                                height: 55,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.sports_shield, size: 55, color: Colors.grey),
                                              )
                                            else
                                              const Icon(Icons.sports_shield, size: 55, color: Colors.grey),
                                            const SizedBox(height: 8),
                                            Text(
                                              match['team_a'] ?? '',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            match['time'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'VS',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            if (match['team_b_logo'] != null &&
                                                (match['team_b_logo'] as String).isNotEmpty)
                                              Image.network(
                                                match['team_b_logo'],
                                                width: 55,
                                                height: 55,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.sports_shield, size: 55, color: Colors.grey),
                                              )
                                            else
                                              const Icon(Icons.sports_shield, size: 55, color: Colors.grey),
                                            const SizedBox(height: 8),
                                            Text(
                                              match['team_b'] ?? '',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.tv, size: 18, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            match['channel'] ?? 'غير محدد',
                                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _watchMatch(match, index),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isLive ? Colors.green[700] : Colors.blueGrey[800],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                                        label: Text(
                                          isLive ? 'شاهد البث المباشر' : 'مشاهدة القناة',
                                          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                        },
                      ),
      ),
    );
  }
}
