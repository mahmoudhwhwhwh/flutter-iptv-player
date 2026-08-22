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
  
  bool _isLoading = false, _isFetchingData = false, _isLoggedIn = false;
  bool get isLoading => _isLoading;
  bool get isFetchingData => _isFetchingData;
  bool get isLoggedIn => _isLoggedIn;
  
  String _activationCode = "";
  String get activationCode => _activationCode;
  
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
  
  int _currentVersionCode = 240;
  bool _isVersionBlocked = false;
  bool get isVersionBlocked => _isVersionBlocked;
  
  String _stalkerToken;
  String get globalUserAgent => "MAG250 stbapp ver: 2 rev: 250";

  // Cloudflare Worker URLs for Security and Automatic Updates
  static const String _workerBase = 'https://iptv-subscription-api.tvkora56.workers.dev';
  static const String _configUrl = '$_workerBase/v1/config';
  static const String _loginUrl = '$_workerBase/v1/login';
  
  // GitHub URLs for Public Assets
  static const String _menuUrl = 'https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/Main_menu.json';

  void init() async {
    _isLoading = true; notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _appLanguage = prefs.getString('app_language') ?? 'العربية';
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _activationCode = prefs.getString('active_code') ?? "";
    
    final savedPlaylistsStr = prefs.getString('saved_playlists');
    if (savedPlaylistsStr != null) { try { _savedPlaylists = (json.decode(savedPlaylistsStr) as List).map((e) => UserPlaylist.fromJson(e)).toList(); } catch(e) {} }
    
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 240;
    
    await checkRemoteBlocking();
    if (_isLoggedIn && _activationCode.isNotEmpty) await loginWithCode(_activationCode);
    
    _isLoading = false; notifyListeners();
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final res = await http.get(Uri.parse("$_configUrl?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['blocking'] != null && data['blocking']['min_version_code'] != null && _currentVersionCode < data['blocking']['min_version_code']) { 
          _isVersionBlocked = true; notifyListeners(); 
        }
      }
    } catch (e) {}
  }

  Future<bool> loginWithCode(String code) async {
    String cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;
    _isLoading = true; notifyListeners();
    
    try {
      // Secure login via Cloudflare Worker and D1 Database
      final res = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': cleanCode, 'device_id': 'UKQ1.240624.001'}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['ok'] == true && data['server'] != null) {
          final server = data['server'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_code', cleanCode);
          await prefs.setBool('is_logged_in', true);
          _isLoggedIn = true;
          _activationCode = cleanCode;
          
          final list = UserPlaylist(
            id: "cf_$cleanCode",
            name: "Premium Server",
            type: server['type'] ?? 'xtream',
            host: server['host'],
            username: server['username'],
            password: server['password'],
          );
          
          _savedPlaylists = [list];
          _activePlaylistId = list.id;
          await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
          
          if (server['content_mode'] == 'github') {
            await _loadCuratedGitHubContent();
          } else {
            await loadPlaylistStreams(list.id);
          }
          
          _isLoading = false; notifyListeners();
          return true;
        }
      }
    } catch(e) {
      debugPrint("Login Error: $e");
    }
    
    _isLoading = false; notifyListeners();
    return false;
  }

  Future<void> _loadCuratedGitHubContent() async {
    _isFetchingData = true; notifyListeners();
    _allStreams = []; _liveCategories = [];
    try {
      final res = await http.get(Uri.parse("$_menuUrl?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 10));
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
    _allStreams = []; _liveCategories = [];
    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) { _isFetchingData = false; notifyListeners(); return; }
    _activePlaylistId = id;
    final host = playlist.host ?? "", user = playlist.username ?? "", pass = playlist.password ?? "";
    if (host.isEmpty || user.isEmpty) { _isFetchingData = false; notifyListeners(); return; }
    
    try { 
      if (playlist.type == 'stalker') {
        await _loadStalkerData(host, user);
      } else {
        await _loadCategories(host, user, pass);
        await _loadStreams(host, user, pass);
      }
    } catch (e) {}
    _applyFilters(); _isFetchingData = false; notifyListeners();
  }

  Future<void> _loadStalkerData(String host, String mac) async {
    String baseUrl = host;
    if (!baseUrl.contains('/portal.php')) { baseUrl = baseUrl.endsWith('/') ? '${baseUrl}portal.php' : '$baseUrl/portal.php'; }
    final headers = {'User-Agent': globalUserAgent, 'Cookie': 'mac=$mac'};
    try {
      final hRes = await http.get(Uri.parse("$baseUrl?type=stb&action=handshake"), headers: headers).timeout(const Duration(seconds: 10));
      if (hRes.statusCode == 200) {
        try { final hData = json.decode(hRes.body); _stalkerToken = hData['js']?['token']; if (_stalkerToken != null) headers['Authorization'] = 'Bearer $_stalkerToken'; } catch(_) {}
      }
      await http.get(Uri.parse("$baseUrl?type=stb&action=get_profile"), headers: headers).timeout(const Duration(seconds: 10));
      final catRes = await http.get(Uri.parse("$baseUrl?type=itv&action=get_categories"), headers: headers).timeout(const Duration(seconds: 10));
      if (catRes.statusCode == 200) {
        final dynamic decoded = json.decode(catRes.body);
        List cats = [];
        if (decoded is Map && decoded['js'] != null) { cats = decoded['js'] is List ? decoded['js'] : []; }
        else if (decoded is List) { cats = decoded; }
        _liveCategories = cats.map<Map<String, String>>((item) => {'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? 'بث مباشر'}).toList();
      }
      final chanRes = await http.get(Uri.parse("$baseUrl?type=itv&action=get_all_channels"), headers: headers).timeout(const Duration(seconds: 15));
      if (chanRes.statusCode == 200) {
        final dynamic decoded = json.decode(chanRes.body);
        List channels = [];
        if (decoded is Map && decoded['js'] != null) {
          final js = decoded['js'];
          if (js is Map && js['data'] != null) { channels = js['data'] is List ? js['data'] : []; }
          else if (js is List) { channels = js; }
        } else if (decoded is List) { channels = decoded; }
        for (var item in channels) {
          if (item is! Map) continue;
          final catId = item['category_id']?.toString() ?? '', cat = _liveCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
          _allStreams.add(PlaylistItem(num: int.tryParse(item['number']?.toString() ?? ''), streamId: item['id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['logo']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? (cat['category_name'] ?? 'بث مباشر') : 'بث مباشر', url: "$baseUrl?type=itv&action=create_link&cmd=${Uri.encodeComponent(item['cmd']?.toString() ?? '')}", type: "live"));
        }
      }
    } catch (e) {}
  }

  Future<void> _loadCategories(String host, String user, String pass) async {
    try {
      final r1 = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 10));
      if (r1.statusCode == 200) { final d = json.decode(r1.body); if (d is List) _liveCategories = d.map((i) => {'category_id': i['category_id']?.toString() ?? '', 'category_name': i['category_name']?.toString() ?? 'بث مباشر'}).toList(); }
    } catch (e) {}
  }

  Future<void> _loadStreams(String host, String user, String pass) async {
    try {
      final r = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final List d = json.decode(r.body);
        for (var i in d) {
          final catId = i['category_id']?.toString() ?? '', cat = _liveCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
          _allStreams.add(PlaylistItem(num: int.tryParse(i['num']?.toString() ?? ''), streamId: i['stream_id']?.toString() ?? '', name: i['name']?.toString() ?? 'Unknown', streamIcon: i['stream_icon']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? (cat['category_name'] ?? 'بث مباشر') : 'بث مباشر', url: "$host/live/$user/$pass/${i['stream_id']}.ts", type: "live"));
        }
      }
    } catch (e) {}
  }

  void _applyFilters() {
    _filteredStreams = _allStreams;
    if (_searchQuery.isNotEmpty) {
      _filteredStreams = _filteredStreams.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_selectedCategory != "all") {
      _filteredStreams = _filteredStreams.where((s) => s.categoryId == _selectedCategory).toList();
    }
    notifyListeners();
  }

  void setSearchQuery(String query) { _searchQuery = query; _applyFilters(); }
  void setSelectedCategory(String cat) { _selectedCategory = cat; _applyFilters(); }
  void setActiveTab(String tab) { _activeTab = tab; _selectedCategory = "all"; _applyFilters(); }
  
  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_code');
    await prefs.setBool('is_logged_in', false);
    _isLoggedIn = false;
    _activationCode = "";
    _savedPlaylists = [];
    _allStreams = [];
    _filteredStreams = [];
    notifyListeners();
  }
}
