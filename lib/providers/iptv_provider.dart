import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
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
  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(id: json['id'] ?? '', name: json['name'] ?? '', type: json['type'] ?? '', host: json['host'], username: json['username'], password: json['password']);
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

  String _profileName = 'Premium User';
  String get profileName => _profileName;
  String _profileLogo = 'play';
  String get profileLogo => _profileLogo;
  String _profileImagePath = '';
  String get profileImagePath => _profileImagePath;

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

  String _currentVersionStr = "2.2.35";
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
    if (savedPlaylistsStr != null) _savedPlaylists = (json.decode(savedPlaylistsStr) as List).map((e) => UserPlaylist.fromJson(e)).toList();
    
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 235;

    await checkRemoteBlocking();
    if (_isLoggedIn && _savedPlaylists.isNotEmpty) {
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
      lastError = "رمز الدخول غير صحيح";
    } catch (e) { lastError = "تعذر الاتصال"; }
    _isLoading = false; notifyListeners(); return false;
  }

  Future<void> loadPlaylistStreams(String id) async {
    _isFetchingData = true; notifyListeners();
    _allStreams = []; _liveCategories = []; _movieCategories = []; _seriesCategories = [];
    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) { _isFetchingData = false; notifyListeners(); return; }
    
    try {
      final host = playlist.host ?? "";
      final user = playlist.username ?? "";
      final pass = playlist.password ?? "";
      
      // 1. Load Categories
      final catsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 10));
      if (catsRes.statusCode == 200) {
        final List decoded = json.decode(catsRes.body);
        _liveCategories = decoded.map<Map<String, String>>((item) => {'category_id': item['category_id'].toString(), 'category_name': item['category_name'].toString()}).toList();
      }
      
      // 2. Load Streams
      final streamsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 20));
      if (streamsRes.statusCode == 200) {
        final List decoded = json.decode(streamsRes.body);
        _allStreams = decoded.map((item) => PlaylistItem(
          num: item['num'], streamId: item['stream_id'].toString(), name: item['name'].toString(), 
          streamIcon: item['stream_icon'].toString(), categoryId: item['category_id'].toString(), 
          categoryName: 'بث مباشر', url: item['url'] ?? "$host/live/$user/$pass/${item['stream_id']}.ts", type: "live"
        )).toList();
      }
    } catch (e) { debugPrint("Load Error: $e"); }
    
    _applyFilters(); _isFetchingData = false; notifyListeners();
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
