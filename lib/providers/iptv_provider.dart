import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/playlist_item.dart';
import '../services/filter_service.dart';

class UserPlaylist {
  final String id;
  final String name;
  final String type;
  final String? host;
  final String? username;
  final String? password;

  UserPlaylist({required this.id, required this.name, required this.type, this.host, this.username, this.password});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'host': host, 'username': username, 'password': password};
  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    host: json['host']?.toString(),
    username: json['username']?.toString(),
    password: json['password']?.toString(),
  );
}

class MyHttpOverrides extends HttpOverrides {
  final String proxyAddress;
  MyHttpOverrides(this.proxyAddress);
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context)..findProxy = (uri) => proxyAddress.isNotEmpty ? "PROXY $proxyAddress;" : "DIRECT"..badCertificateCallback = (cert, host, port) => false;
}

class IPTVProvider with ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  void toggleTheme() async { _isDarkMode = !_isDarkMode; notifyListeners(); (await SharedPreferences.getInstance()).setBool('isDarkMode', _isDarkMode); }

  String _appLanguage = 'العربية';
  String get appLanguage => _appLanguage;
  String _premiumTheme = 'البنفسجي الملكي';
  String get premiumTheme => _premiumTheme;
  Color get accentColor => const Color(0xFFA855F7);
  Color get themeBackground => const Color(0xFF09091A);
  Color get themeSurface => const Color(0xFF14112B);

  bool _tvBoxFocusEnabled = true;
  bool get tvBoxFocusEnabled => _tvBoxFocusEnabled;

  bool _isSecured = true;
  bool get isSecured => _isSecured;
  bool _blockAdultContent = true;
  bool get blockAdultContent => _blockAdultContent;

  String? lastError;
  List<PlaylistItem> _allStreams = [];
  List<PlaylistItem> _filteredStreams = [];
  List<UserPlaylist> _savedPlaylists = [];
  List<UserPlaylist> get savedPlaylists => _savedPlaylists;
  String? _activePlaylistId;
  PlaylistItem? _currentStream;
  List<String> _favorites = [];
  bool _isLoading = false;
  bool _isFetchingData = false;
  bool get isFetchingData => _isFetchingData;
  String _activeTab = "live"; 
  String _selectedCategory = "all";
  String _searchQuery = "";
  bool _isLoggedIn = false;

  List<Map<String, String>> _liveCategories = [];
  List<Map<String, String>> _movieCategories = [];
  List<Map<String, String>> _seriesCategories = [];

  String _activationCode = "";
  String _subscriptionType = "";

  bool _showMoviesSeries = true;
  bool get showMoviesSeries => _showMoviesSeries;
  String _channelFilter = "الكل";
  String get channelFilter => _channelFilter;

  int _currentVersionCode = 235;
  bool _isVersionBlocked = false;
  bool get isVersionBlocked => _isVersionBlocked;
  String get remoteBlockMessage => "🚨 تحديث إجباري مطلوب فوراً 🚨";

  List<PlaylistItem> _recentlyPlayed = [];
  List<PlaylistItem> get recentlyPlayed => _recentlyPlayed;

  void addToRecentlyPlayed(PlaylistItem stream) async {
    _recentlyPlayed.removeWhere((item) => item.streamId == stream.streamId);
    _recentlyPlayed.insert(0, stream);
    if (_recentlyPlayed.length > 10) _recentlyPlayed = _recentlyPlayed.sublist(0, 10);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_played_streams', jsonEncode(_recentlyPlayed.map((e) => e.toJson()).toList()));
  }

  void init() async {
    _isLoading = true; notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _appLanguage = prefs.getString('app_language') ?? 'العربية';
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _activationCode = prefs.getString('active_code') ?? "";
    _favorites = prefs.getStringList('favorites') ?? [];
    final savedPlaylistsStr = prefs.getString('saved_playlists');
    if (savedPlaylistsStr != null) {
        try {
            _savedPlaylists = (json.decode(savedPlaylistsStr) as List).map((e) => UserPlaylist.fromJson(e)).toList();
        } catch(e) { debugPrint("Saved Playlists Error: $e"); }
    }
    
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 235;

    await checkRemoteBlocking();
    if (_isLoggedIn && _activationCode.isNotEmpty) {
      // Force re-login to refresh host/credentials from Cloudflare
      await loginWithCode(_activationCode);
    } else if (_isLoggedIn && _savedPlaylists.isNotEmpty) {
      _activePlaylistId = _savedPlaylists.first.id;
      loadPlaylistStreams(_activePlaylistId!);
    }
    _isLoading = false; notifyListeners();
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final res = await http.get(Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/config?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['min_version_code'] != null && _currentVersionCode < data['min_version_code']) {
          _isVersionBlocked = true; notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<bool> loginWithCode(String code) async {
    lastError = null; String cleanCode = code.trim();
    if (cleanCode.isEmpty) { lastError = "رمز الدخول فارغ"; return false; }
    _isLoading = true; notifyListeners();
    try {
      final res = await http.post(Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/v1/login"), headers: {"Content-Type": "application/json"}, body: json.encode({"code": cleanCode, "version_code": _currentVersionCode})).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['ok'] == true) {
          final u = data['user'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_code', cleanCode);
          await prefs.setBool('is_logged_in', true);
          _activationCode = cleanCode; _isLoggedIn = true;
          final list = UserPlaylist(id: "srv_$cleanCode", name: "Premium", type: u['server_type'], host: u['host'], username: u['username'], password: u['password']);
          _savedPlaylists = [list]; _activePlaylistId = list.id;
          await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
          await loadPlaylistStreams(list.id);
          _isLoading = false; notifyListeners(); return true;
        }
      }
    } catch (e) { debugPrint("Login Error: $e"); }
    
    // GitHub Fallback
    try {
      final fallbackRes = await http.get(Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/app_config.json")).timeout(const Duration(seconds: 10));
      if (fallbackRes.statusCode == 200) {
          final config = json.decode(fallbackRes.body);
          if (config['users'] != null && config['users'][cleanCode] != null) {
              final userData = config['users'][cleanCode];
              final sIndex = userData['server_index'] ?? 0;
              final server = config['servers'][sIndex];
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('active_code', cleanCode);
              await prefs.setBool('is_logged_in', true);
              _isLoggedIn = true; _activationCode = cleanCode;
              final list = UserPlaylist(id: "fallback_$cleanCode", name: "Premium", type: server['type'] ?? 'xtream', host: server['host'], username: server['username'], password: server['password']);
              _savedPlaylists = [list]; _activePlaylistId = list.id;
              await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
              await loadPlaylistStreams(list.id);
              _isLoading = false; notifyListeners(); return true;
          }
      }
    } catch(e) { debugPrint("Fallback Login Error: $e"); }

    lastError = "رمز الدخول غير صحيح";
    _isLoading = false; notifyListeners(); return false;
  }

  Future<void> loadPlaylistStreams(String id) async {
    _isFetchingData = true; notifyListeners();
    _allStreams = []; _liveCategories = []; _movieCategories = []; _seriesCategories = [];
    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) { _isFetchingData = false; notifyListeners(); return; }
    _activePlaylistId = id;

    final host = playlist.host ?? "";
    final user = playlist.username ?? "";
    final pass = playlist.password ?? "";

    if (host.isEmpty || user.isEmpty) { _isFetchingData = false; notifyListeners(); return; }

    try {
      // 1. Load Categories (Live, VOD, Series)
      await _loadCategories(host, user, pass);
      
      // 2. Load Streams (Live, VOD, Series)
      await _loadStreams(host, user, pass);
      
    } catch (e) { debugPrint("Load Playlist Error: $e"); }
    
    _applyFilters(); _isFetchingData = false; notifyListeners();
  }

  Future<void> _loadCategories(String host, String user, String pass) async {
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        _liveCategories = decoded.map<Map<String, String>>((item) => {
            'category_id': item['category_id']?.toString() ?? '',
            'category_name': item['category_name']?.toString() ?? 'بث مباشر'
        }).toList();
      }
    } catch (e) { debugPrint("Live Cats Error: $e"); }

    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_categories")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        _movieCategories = decoded.map<Map<String, String>>((item) => {
            'category_id': item['category_id']?.toString() ?? '',
            'category_name': item['category_name']?.toString() ?? 'أفلام'
        }).toList();
      }
    } catch (e) { debugPrint("VOD Cats Error: $e"); }

    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series_categories")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        _seriesCategories = decoded.map<Map<String, String>>((item) => {
            'category_id': item['category_id']?.toString() ?? '',
            'category_name': item['category_name']?.toString() ?? 'مسلسلات'
        }).toList();
      }
    } catch (e) { debugPrint("Series Cats Error: $e"); }
  }

  Future<void> _loadStreams(String host, String user, String pass) async {
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        for (var item in decoded) {
            try {
                final catId = item['category_id']?.toString() ?? '';
                final cat = _liveCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                final catName = cat.isNotEmpty ? cat['category_name']! : 'بث مباشر';
                _allStreams.add(PlaylistItem(
                    num: item['num'] is int ? item['num'] : null,
                    streamId: item['stream_id']?.toString() ?? '',
                    name: item['name']?.toString() ?? 'Unknown',
                    streamIcon: item['stream_icon']?.toString() ?? '',
                    categoryId: catId,
                    categoryName: catName,
                    url: item['url']?.toString() ?? "$host/live/$user/$pass/${item['stream_id']}.ts",
                    type: "live"
                ));
            } catch(e) {}
        }
      }
    } catch (e) { debugPrint("Live Streams Error: $e"); }

    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_streams")).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        for (var item in decoded) {
            try {
                final catId = item['category_id']?.toString() ?? '';
                final cat = _movieCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                final catName = cat.isNotEmpty ? cat['category_name']! : 'أفلام';
                _allStreams.add(PlaylistItem(
                    num: item['num'] is int ? item['num'] : null,
                    streamId: item['stream_id']?.toString() ?? '',
                    name: item['name']?.toString() ?? 'Unknown',
                    streamIcon: item['stream_icon']?.toString() ?? '',
                    categoryId: catId,
                    categoryName: catName,
                    url: item['url']?.toString() ?? "$host/movie/$user/$pass/${item['stream_id']}.mp4",
                    type: "movie"
                ));
            } catch(e) {}
        }
      }
    } catch (e) { debugPrint("VOD Streams Error: $e"); }
  }

  void _applyFilters() {
    _filteredStreams = _allStreams.where((s) {
      if (_activeTab != s.type) return false;
      if (_selectedCategory != "all" && s.categoryId != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty && !s.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
  }

  void setActiveTab(String tab) { _activeTab = tab; _selectedCategory = "all"; _applyFilters(); notifyListeners(); }
  void setSearchQuery(String q) { _searchQuery = q; _applyFilters(); notifyListeners(); }
  void selectStream(PlaylistItem item) { _currentStream = item; addToRecentlyPlayed(item); notifyListeners(); }
  Future<void> logout() async { (await SharedPreferences.getInstance()).clear(); _isLoggedIn = false; _savedPlaylists = []; _allStreams = []; notifyListeners(); }
}
