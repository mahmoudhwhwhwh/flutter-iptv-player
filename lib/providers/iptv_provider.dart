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

class IPTVProvider with ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  void toggleTheme() async { _isDarkMode = !_isDarkMode; notifyListeners(); (await SharedPreferences.getInstance()).setBool('isDarkMode', _isDarkMode); }
  String _appLanguage = 'العربية';
  String get appLanguage => _appLanguage;
  Color get accentColor => const Color(0xFFA855F7);
  Color get themeBackground => const Color(0xFF09091A);
  Color get themeSurface => const Color(0xFF14112B);

  bool _isSecured = true;
  bool get isSecured => _isSecured;
  String? lastError;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isFetchingData = false;
  bool get isFetchingData => _isFetchingData;
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;
  String _activationCode = "";
  String get activationCode => _activationCode;
  
  List<PlaylistItem> _allStreams = [];
  List<PlaylistItem> get allStreams => _allStreams;
  List<PlaylistItem> _filteredStreams = [];
  List<PlaylistItem> get streams => _filteredStreams;
  
  List<UserPlaylist> _savedPlaylists = [];
  List<UserPlaylist> get savedPlaylists => _savedPlaylists;
  String? _activePlaylistId;
  
  List<Map<String, String>> _liveCategories = [];
  List<Map<String, String>> get liveCategories => _liveCategories;
  List<Map<String, String>> _movieCategories = [];
  List<Map<String, String>> get movieCategories => _movieCategories;
  List<Map<String, String>> _seriesCategories = [];
  List<Map<String, String>> get seriesCategories => _seriesCategories;

  String _activeTab = "live"; 
  String get activeTab => _activeTab;
  String _selectedCategory = "all";
  String get selectedCategory => _selectedCategory;
  String _searchQuery = "";
  bool _showMoviesSeries = true;
  bool get showMoviesSeries => _showMoviesSeries;
  
  int _currentVersionCode = 235;
  bool _isVersionBlocked = false;
  bool get isVersionBlocked => _isVersionBlocked;
  String get remoteBlockMessage => "Update Required";

  String _profileName = 'Premium User';
  String get profileName => _profileName;
  String _profileLogo = 'play';
  String get profileLogo => _profileLogo;
  String _profileImagePath = '';
  String get profileImagePath => _profileImagePath;
  String get subscriptionType => "Premium";
  List<PlaylistItem> _recentlyPlayed = [];
  List<PlaylistItem> get recentlyPlayed => _recentlyPlayed;
  List<String> _favorites = [];

  String _parentalPin = "";
  String get parentalPin => _parentalPin;
  List<String> _lockedCategories = [];
  List<String> get lockedCategories => _lockedCategories;

  List<String> get categories {
    if (_activeTab == "live") return _liveCategories.map((e) => e['category_name']!).toList();
    if (_activeTab == "movie") return _movieCategories.map((e) => e['category_name']!).toList();
    if (_activeTab == "series") return _seriesCategories.map((e) => e['category_name']!).toList();
    return [];
  }

  void init() async {
    _isLoading = true; notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _appLanguage = prefs.getString('app_language') ?? 'العربية';
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _activationCode = prefs.getString('active_code') ?? "";
    _favorites = prefs.getStringList('favorites') ?? [];
    _parentalPin = prefs.getString('parental_pin') ?? "";
    _lockedCategories = prefs.getStringList('locked_categories') ?? [];
    
    final savedPlaylistsStr = prefs.getString('saved_playlists');
    if (savedPlaylistsStr != null) {
        try {
            _savedPlaylists = (json.decode(savedPlaylistsStr) as List).map((e) => UserPlaylist.fromJson(e)).toList();
        } catch(e) {}
    }
    
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 235;

    await checkRemoteBlocking();
    if (_isLoggedIn && _activationCode.isNotEmpty) {
      await loginWithCode(_activationCode);
    } else if (_isLoggedIn && _savedPlaylists.isNotEmpty) {
      _activePlaylistId = _savedPlaylists.first.id;
      loadPlaylistStreams(_activePlaylistId!);
    }
    _isLoading = false; notifyListeners();
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final res = await http.get(Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 5));
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
    if (cleanCode.isEmpty) { lastError = "Empty code"; return false; }
    _isLoading = true; notifyListeners();
    
    try {
      final res = await http.get(Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
          final config = json.decode(res.body);
          if (config['users'] != null && config['users'][cleanCode] != null) {
              final userData = config['users'][cleanCode];
              final sIndex = userData['server_index'] ?? 0;
              final server = config['servers'][sIndex];
              final mode = userData['mode'] ?? 'iptv';
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('active_code', cleanCode);
              await prefs.setBool('is_logged_in', true);
              _isLoggedIn = true; _activationCode = cleanCode;
              
              final list = UserPlaylist(
                id: "gh_$cleanCode", 
                name: server['name'] ?? "Premium", 
                type: server['type'] ?? 'xtream', 
                host: server['host'], 
                username: server['username'], 
                password: server['password']
              );
              _savedPlaylists = [list]; _activePlaylistId = list.id;
              await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
              
              if (mode == 'github') {
                  await _loadCuratedGitHubContent();
              } else {
                  await loadPlaylistStreams(list.id);
              }
              
              _isLoading = false; notifyListeners(); return true;
          }
      }
    } catch(e) {}

    lastError = "Invalid code";
    _isLoading = false; notifyListeners(); return false;
  }

  Future<void> _loadCuratedGitHubContent() async {
    _isFetchingData = true; notifyListeners();
    _allStreams = []; _liveCategories = []; _movieCategories = []; _seriesCategories = [];
    try {
      final res = await http.get(Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/Main_menu.json?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        final catsSeen = <String, String>{};
        for (var item in decoded) {
            final catId = item['category_id']?.toString() ?? '99';
            final catName = item['category_name']?.toString() ?? 'بث مباشر';
            if (!catsSeen.containsKey(catId)) {
                catsSeen[catId] = catName;
                _liveCategories.add({'category_id': catId, 'category_name': catName});
            }
            _allStreams.add(PlaylistItem(
                num: null,
                streamId: _allStreams.length.toString(),
                name: item['name']?.toString() ?? 'Unknown',
                streamIcon: item['icon']?.toString() ?? '',
                categoryId: catId,
                categoryName: catName,
                url: item['url']?.toString() ?? "",
                type: "live"
            ));
        }
      }
    } catch (e) {}
    _applyFilters(); _isFetchingData = false; notifyListeners();
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
      await _loadCategories(host, user, pass);
      await _loadStreams(host, user, pass);
    } catch (e) {}
    
    _applyFilters(); _isFetchingData = false; notifyListeners();
  }

  Future<void> _loadCategories(String host, String user, String pass) async {
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        _liveCategories = decoded.map<Map<String, String>>((item) => {'category_id': item['category_id']?.toString() ?? '', 'category_name': item['category_name']?.toString() ?? 'بث مباشر'}).toList();
      }
    } catch (e) {}
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_categories")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        _movieCategories = decoded.map<Map<String, String>>((item) => {'category_id': item['category_id']?.toString() ?? '', 'category_name': item['category_name']?.toString() ?? 'أفلام'}).toList();
      }
    } catch (e) {}
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series_categories")).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        _seriesCategories = decoded.map<Map<String, String>>((item) => {'category_id': item['category_id']?.toString() ?? '', 'category_name': item['category_name']?.toString() ?? 'مسلسلات'}).toList();
      }
    } catch (e) {}
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
                _allStreams.add(PlaylistItem(num: item['num'] is int ? item['num'] : null, streamId: item['stream_id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['stream_icon']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? cat['category_name']! : 'بث مباشر', url: item['url']?.toString() ?? "$host/live/$user/$pass/${item['stream_id']}.ts", type: "live"));
            } catch(e) {}
        }
      }
    } catch (e) {}
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_streams")).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        for (var item in decoded) {
            try {
                final catId = item['category_id']?.toString() ?? '';
                final cat = _movieCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                _allStreams.add(PlaylistItem(num: item['num'] is int ? item['num'] : null, streamId: item['stream_id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['stream_icon']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? cat['category_name']! : 'أفلام', url: item['url']?.toString() ?? "$host/movie/$user/$pass/${item['stream_id']}.mp4", type: "movie"));
            } catch(e) {}
        }
      }
    } catch (e) {}
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series")).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        for (var item in decoded) {
            try {
                final catId = item['category_id']?.toString() ?? '';
                final cat = _seriesCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                _allStreams.add(PlaylistItem(num: item['num'] is int ? item['num'] : null, streamId: item['series_id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['cover']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? cat['category_name']! : 'مسلسلات', url: "", type: "series"));
            } catch(e) {}
        }
      }
    } catch (e) {}
  }

  void _applyFilters() {
    _filteredStreams = _allStreams.where((s) {
      if (_activeTab != s.type) return false;
      if (_selectedCategory != "all") {
          final cat = categories.firstWhere((c) => c == _selectedCategory, orElse: () => "");
          if (cat.isEmpty) return false;
          if (s.categoryName != cat) return false;
      }
      if (_searchQuery.isNotEmpty && !s.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
  }

  void setTab(String tab) { _activeTab = tab; _selectedCategory = "all"; _applyFilters(); notifyListeners(); }
  void setCategory(String category) { _selectedCategory = category; _applyFilters(); notifyListeners(); }
  void setSearchQuery(String q) { _searchQuery = q; _applyFilters(); notifyListeners(); }
  void selectStream(PlaylistItem item) { addToRecentlyPlayed(item); notifyListeners(); }
  void toggleFavorite(String streamId) async {
    if (_favorites.contains(streamId)) _favorites.remove(streamId); else _favorites.add(streamId);
    notifyListeners();
    (await SharedPreferences.getInstance()).setStringList('favorites', _favorites);
  }
  bool isFavorite(String streamId) => _favorites.contains(streamId);
  void addToRecentlyPlayed(PlaylistItem stream) async {
    _recentlyPlayed.removeWhere((item) => item.streamId == stream.streamId);
    _recentlyPlayed.insert(0, stream);
    if (_recentlyPlayed.length > 10) _recentlyPlayed = _recentlyPlayed.sublist(0, 10);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_played_streams', jsonEncode(_recentlyPlayed.map((e) => e.toJson()).toList()));
  }
  
  bool isCategoryLocked(String category) => _lockedCategories.contains(category);
  void unlockCategorySession(String category) {}
  void toggleCategoryLock(String category) async {
    if (_lockedCategories.contains(category)) _lockedCategories.remove(category); else _lockedCategories.add(category);
    notifyListeners();
    (await SharedPreferences.getInstance()).setStringList('locked_categories', _lockedCategories);
  }
  void setParentalPin(String pin) async {
    _parentalPin = pin; notifyListeners();
    (await SharedPreferences.getInstance()).setString('parental_pin', pin);
  }

  Future<void> logout() async { (await SharedPreferences.getInstance()).clear(); _isLoggedIn = false; _savedPlaylists = []; _allStreams = []; notifyListeners(); }
}
