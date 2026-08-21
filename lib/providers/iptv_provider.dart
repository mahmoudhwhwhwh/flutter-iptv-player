import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/playlist_item.dart';

class UserPlaylist {
  final String id, name, type;
  final String? host, username, password;
  UserPlaylist({required this.id, required this.name, required this.type, this.host, this.username, this.password});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'host': host, 'username': username, 'password': password};
  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? '', type: json['type']?.toString() ?? '',
    host: json['host']?.toString(), username: json['username']?.toString(), password: json['password']?.toString(),
  );
}

class IPTVProvider with ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  void toggleTheme() async { _isDarkMode = !_isDarkMode; notifyListeners(); (await SharedPreferences.getInstance()).setBool('isDarkMode', _isDarkMode); }
  String _appLanguage = 'العربية';
  String get appLanguage => _appLanguage;
  Future<void> setAppLanguage(String lang) async { _appLanguage = lang; notifyListeners(); (await SharedPreferences.getInstance()).setString('app_language', lang); }
  Color get accentColor => const Color(0xFFA855F7);
  Color get themeBackground => const Color(0xFF09091A);
  Color get themeSurface => const Color(0xFF14112B);
  String _premiumTheme = 'البنفسجي الملكي';
  String get premiumTheme => _premiumTheme;
  void setPremiumTheme(String val) { _premiumTheme = val; notifyListeners(); }

  bool _isSecured = true;
  bool get isSecured => _isSecured;
  String? lastError;
  bool _isLoading = false, _isFetchingData = false, _isLoggedIn = false;
  bool get isLoading => _isLoading;
  bool get isFetchingData => _isFetchingData;
  bool get isLoggedIn => _isLoggedIn;
  String _activationCode = "";
  String get activationCode => _activationCode;
  bool get snifferDetected => false;
  bool get vpnDetected => false;
  String get securityMessage => "";
  bool get isExpired => false;

  List<PlaylistItem> _allStreams = [], _filteredStreams = [], _recentlyPlayed = [];
  List<PlaylistItem> get allStreams => _allStreams;
  List<PlaylistItem> get streams => _filteredStreams;
  List<PlaylistItem> get recentlyPlayed => _recentlyPlayed;
  List<UserPlaylist> _savedPlaylists = [];
  List<UserPlaylist> get savedPlaylists => _savedPlaylists;
  String? _activePlaylistId;
  String? get activePlaylistId => _activePlaylistId;
  List<Map<String, String>> _liveCategories = [], _movieCategories = [], _seriesCategories = [];
  List<Map<String, String>> get liveCategories => _liveCategories;
  List<Map<String, String>> get movieCategories => _movieCategories;
  List<Map<String, String>> get seriesCategories => _seriesCategories;
  String _activeTab = "live", _selectedCategory = "all", _searchQuery = "";
  String get activeTab => _activeTab;
  String get selectedCategory => _selectedCategory;
  bool _showMoviesSeries = true;
  bool get showMoviesSeries => _showMoviesSeries;
  void setShowMoviesSeries(bool val) { _showMoviesSeries = val; notifyListeners(); }
  String _channelFilter = "all";
  String get channelFilter => _channelFilter;
  void setChannelFilter(String f) { _channelFilter = f; _applyFilters(); }
  int _currentVersionCode = 236;
  bool _isVersionBlocked = false;
  bool get isVersionBlocked => _isVersionBlocked;
  String get remoteBlockMessage => "🚨 تم إيقاف هذا الإصدار القديم نهائياً لدواعي الأمان والاستقرار.\nيرجى التحديث إلى v2.2.36 للاستمرار.";
  int get playerSettingsVersion => 1;
  String _profileName = 'Premium User', _profileLogo = 'play', _profileImagePath = '';
  String get profileName => _profileName;
  String get profileLogo => _profileLogo;
  String get profileImagePath => _profileImagePath;
  String get subscriptionType => "Premium";
  String get expirationDateFormatted => "بلا حدود ";
  List<String> _favorites = [], _lockedCategories = [];
  List<String> get favorites => _favorites;
  List<String> get lockedCategories => _lockedCategories;
  String _parentalPin = "";
  String get parentalPin => _parentalPin;
  bool get isParentalEnabled => _parentalPin.isNotEmpty;
  bool get blockAdultContent => false;
  void setBlockAdultContent(bool val) { notifyListeners(); }

  PlaylistItem? _currentStream;
  PlaylistItem? get currentStream => _currentStream;
  String? get stalkerToken => null;
  String get globalUserAgent => "Mozilla/5.0";
  String get globalReferer => "";
  bool _tvBoxFocusEnabled = false;
  bool get tvBoxFocusEnabled => _tvBoxFocusEnabled;
  void setTvBoxFocusEnabled(bool val) { _tvBoxFocusEnabled = val; notifyListeners(); }

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
    if (savedPlaylistsStr != null) { try { _savedPlaylists = (json.decode(savedPlaylistsStr) as List).map((e) => UserPlaylist.fromJson(e)).toList(); } catch(e) {} }
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 236;
    await checkRemoteBlocking();
    if (_isLoggedIn && _activationCode.isNotEmpty) await loginWithCode(_activationCode);
    _isLoading = false; notifyListeners();
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final res = await http.get(Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['blocking'] != null && data['blocking']['min_version_code'] != null && _currentVersionCode < data['blocking']['min_version_code']) { _isVersionBlocked = true; notifyListeners(); }
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
          final List servers = config['servers'] ?? [];
          final Map rootUsers = config['users'] ?? {};
          dynamic userData, targetServer;
          if (rootUsers[cleanCode] != null) { userData = rootUsers[cleanCode]; final sIndex = userData['server_index'] ?? 0; if (sIndex < servers.length) targetServer = servers[sIndex]; }
          if (targetServer == null) { for (var server in servers) { final serverUsers = server['users'] ?? {}; if (serverUsers[cleanCode] != null) { userData = serverUsers[cleanCode]; targetServer = server; break; } } }
          if (targetServer != null) {
              final mode = userData['mode'] ?? 'iptv';
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('active_code', cleanCode); await prefs.setBool('is_logged_in', true);
              _isLoggedIn = true; _activationCode = cleanCode;
              final list = UserPlaylist(id: "gh_$cleanCode", name: targetServer['name'] ?? "Premium", type: targetServer['type'] ?? 'xtream', host: targetServer['host'], username: userData['username'] ?? targetServer['username'], password: userData['password'] ?? targetServer['password']);
              _savedPlaylists = [list]; _activePlaylistId = list.id;
              await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
              if (mode == 'github') await _loadCuratedGitHubContent(); else await loadPlaylistStreams(list.id);
              _isLoading = false; notifyListeners(); return true;
          }
      }
    } catch(e) {}
    lastError = "Invalid code"; _isLoading = false; notifyListeners(); return false;
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
            final catId = item['category_id']?.toString() ?? '99', catName = item['category_name']?.toString() ?? 'بث مباشر';
            if (!catsSeen.containsKey(catId)) { catsSeen[catId] = catName; _liveCategories.add({'category_id': catId, 'category_name': catName}); }
            _allStreams.add(PlaylistItem(num: null, streamId: _allStreams.length.toString(), name: item['name']?.toString() ?? 'Unknown', streamIcon: item['icon']?.toString() ?? '', categoryId: catId, categoryName: catName, url: item['url']?.toString() ?? "", type: "live"));
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
    final host = playlist.host ?? "", user = playlist.username ?? "", pass = playlist.password ?? "";
    if (host.isEmpty || user.isEmpty) { _isFetchingData = false; notifyListeners(); return; }
    try { if (playlist.type == 'stalker') await _loadStalkerData(host, user); else { await _loadCategories(host, user, pass); await _loadStreams(host, user, pass); } } catch (e) {}
    _applyFilters(); _isFetchingData = false; notifyListeners();
  }

  Future<void> _loadStalkerData(String host, String mac) async {
    final baseUrl = host.endsWith('/') ? host : '$host/', headers = {'User-Agent': 'Mozilla/5.0', 'Cookie': 'mac=$mac'};
    try {
      final res = await http.get(Uri.parse("${baseUrl}portal.php?type=itv&action=get_categories"), headers: headers);
      if (res.statusCode == 200) {
        final List cats = json.decode(res.body)['js'] ?? [];
        _liveCategories = cats.map<Map<String, String>>((item) => {'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? 'بث مباشر'}).toList();
      }
      final resStreams = await http.get(Uri.parse("${baseUrl}portal.php?type=itv&action=get_all_channels"), headers: headers);
      if (resStreams.statusCode == 200) {
        final List channels = json.decode(resStreams.body)['js']['data'] ?? [];
        for (var item in channels) {
          final catId = item['category_id']?.toString() ?? '', cat = _liveCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
          _allStreams.add(PlaylistItem(num: int.tryParse(item['number']?.toString() ?? ''), streamId: item['id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['logo']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? cat['category_name']! : 'بث مباشر', url: "${baseUrl}portal.php?type=itv&action=create_link&cmd=${Uri.encodeComponent(item['cmd'] ?? '')}", type: "live"));
        }
      }
    } catch (e) {}
  }

  Future<void> _loadCategories(String host, String user, String pass) async {
    final h = {'User-Agent': 'IPTVSmarters'};
    try {
      final r1 = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories"), headers: h).timeout(const Duration(seconds: 10));
      if (r1.statusCode == 200) { final d = json.decode(r1.body); if (d is List) _liveCategories = d.map<Map<String, String>>((i) => {'category_id': i['category_id']?.toString() ?? '', 'category_name': i['category_name']?.toString() ?? 'بث مباشر'}).toList(); }
      final r2 = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_categories"), headers: h).timeout(const Duration(seconds: 10));
      if (r2.statusCode == 200) { final d = json.decode(r2.body); if (d is List) _movieCategories = d.map<Map<String, String>>((i) => {'category_id': i['category_id']?.toString() ?? '', 'category_name': i['category_name']?.toString() ?? 'أفلام'}).toList(); }
      final r3 = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series_categories"), headers: h).timeout(const Duration(seconds: 10));
      if (r3.statusCode == 200) { final d = json.decode(r3.body); if (d is List) _seriesCategories = d.map<Map<String, String>>((i) => {'category_id': i['category_id']?.toString() ?? '', 'category_name': i['category_name']?.toString() ?? 'مسلسلات'}).toList(); }
    } catch (e) {}
  }

  Future<void> _loadStreams(String host, String user, String pass) async {
    try {
      final res = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams"), headers: {'User-Agent': 'IPTVSmarters'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          for (var item in decoded) {
            _allStreams.add(PlaylistItem(num: int.tryParse(item['num']?.toString() ?? ''), streamId: item['stream_id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['stream_icon']?.toString() ?? '', categoryId: item['category_id']?.toString() ?? '', categoryName: _liveCategories.firstWhere((c) => c['category_id'] == item['category_id']?.toString(), orElse: () => {'category_name': 'بث مباشر'})['category_name']!, url: "$host/live/$user/$pass/${item['stream_id']}.m3u8", type: "live"));
          }
        }
      }
    } catch (e) {}
  }

  void _applyFilters() {
    _filteredStreams = _allStreams.where((s) {
      if (_selectedCategory != "all" && s.categoryId != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty && !s.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
    notifyListeners();
  }

  void setCategory(String cat) { _selectedCategory = cat; _applyFilters(); }
  void setSearch(String query) { _searchQuery = query; _applyFilters(); }
  void setSearchQuery(String query) { _searchQuery = query; _applyFilters(); }
  void setTab(String tab) { _activeTab = tab; _selectedCategory = "all"; _applyFilters(); }
  void selectStream(PlaylistItem stream) { _currentStream = stream; addToRecentlyPlayed(stream); notifyListeners(); }
  void addToRecentlyPlayed(PlaylistItem stream) { if (!_recentlyPlayed.any((s) => s.streamId == stream.streamId)) { _recentlyPlayed.insert(0, stream); if (_recentlyPlayed.length > 20) _recentlyPlayed.removeLast(); } }
  void toggleFavorite(String streamId) async { if (_favorites.contains(streamId)) _favorites.remove(streamId); else _favorites.add(streamId); notifyListeners(); (await SharedPreferences.getInstance()).setStringList('favorites', _favorites); }
  void zapChannel(bool next) {
    if (_filteredStreams.isEmpty || _currentStream == null) return;
    int index = _filteredStreams.indexWhere((s) => s.streamId == _currentStream!.streamId);
    if (index == -1) return;
    int offset = next ? 1 : -1, newIndex = (index + offset) % _filteredStreams.length;
    if (newIndex < 0) newIndex += _filteredStreams.length;
    selectStream(_filteredStreams[newIndex]);
  }
  Future<void> setProfileName(String name) async { _profileName = name; notifyListeners(); }
  Future<void> setProfileLogo(String logo) async { _profileLogo = logo; notifyListeners(); }
  Future<void> setProfileImagePath(String path) async { _profileImagePath = path; notifyListeners(); }
  Future<void> setParentalPin(String pin) async { _parentalPin = pin; notifyListeners(); (await SharedPreferences.getInstance()).setString('parental_pin', pin); }
  Future<void> clearParentalSettings() async { _parentalPin = ""; _lockedCategories = []; notifyListeners(); (await SharedPreferences.getInstance()).remove('parental_pin'); (await SharedPreferences.getInstance()).remove('locked_categories'); }
  Future<void> changeSubscription() async { logout(); }
  Future<void> logout() async { _isLoggedIn = false; _activationCode = ""; _allStreams = []; _filteredStreams = []; final prefs = await SharedPreferences.getInstance(); await prefs.setBool('is_logged_in', false); await prefs.remove('active_code'); notifyListeners(); }
  Future<void> setPlayerStringPreference(String key, String val) async { (await SharedPreferences.getInstance()).setString(key, val); }
  bool isCategoryLocked(String cat) => _lockedCategories.contains(cat);
  Future<void> toggleCategoryLock(String cat) async { if (_lockedCategories.contains(cat)) _lockedCategories.remove(cat); else _lockedCategories.add(cat); notifyListeners(); (await SharedPreferences.getInstance()).setStringList('locked_categories', _lockedCategories); }
  void unlockCategorySession(String cat) {}
}
