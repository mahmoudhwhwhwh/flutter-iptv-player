import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/playlist_item.dart';
import '../services/filter_service.dart';

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
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  String _appLanguage = 'العربية';
  String get appLanguage => _appLanguage;
  Future<void> setAppLanguage(String lang) async {
    _appLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    notifyListeners();
  }

  String _premiumTheme = 'البنفسجي الملكي';
  String get premiumTheme => _premiumTheme;
  Color get accentColor {
    const colors = <String, Color>{
      'البنفسجي الملكي': Color(0xFFA855F7),
      'الأزرق الليلي': Color(0xFF4F8CFF),
      'الذهبي الفاخر': Color(0xFFEAB308),
      'الزمردي الداكن': Color(0xFF10B981),
      'الروبي السينمائي': Color(0xFFEF476F),
      'السماوي الكهربائي': Color(0xFF22D3EE),
      'الغروب البرتقالي': Color(0xFFF97316),
    };
    return colors[_premiumTheme] ?? const Color(0xFFA855F7);
  }
  Color get themeBackground => const Color(0xFF09091A);
  Color get themeSurface => const Color(0xFF14112B);
  Future<void> setPremiumTheme(String value) async {
    _premiumTheme = value.trim().isEmpty ? 'البنفسجي الملكي' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('premium_theme', _premiumTheme);
    notifyListeners();
  }

  // هذه الحالات لا تفترض وجود root/VPN/sniffer؛ لا نحجب المستخدمين الطبيعيين بتخمينات.
  bool get snifferDetected => false;
  bool get vpnDetected => false;
  bool get isSecured => true;
  String get securityMessage => '';
  String _remoteBlockMessage = 'هذه النسخة غير مدعومة. يرجى استخدام LIVE STREAM PREMIUM 2.2.32.';
  String get remoteBlockMessage => _remoteBlockMessage;
  String? _lastError;
  String? get lastError => _lastError;
  bool get isExpired => _expirationAt != null && _expirationAt!.isBefore(DateTime.now().toUtc());

  bool _isLoading = false, _isFetchingData = false, _isLoggedIn = false;
  bool get isLoading => _isLoading;
  bool get isFetchingData => _isFetchingData;
  bool get isLoggedIn => _isLoggedIn;

  String _activationCode = '';
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

  String _activeTab = 'live', _selectedCategory = 'all', _searchQuery = '';
  String get activeTab => _activeTab;
  String get selectedCategory => _selectedCategory;
  List<String> get categories {
    final seen = <String>{};
    return _liveCategories.map((category) => category['category_name']?.trim() ?? '').where((name) => name.isNotEmpty && seen.add(name)).toList();
  }
  void setCategory(String category) {
    if (category == 'الكل' || category == 'all' || category.trim().isEmpty) {
      _selectedCategory = 'all';
    } else {
      final matched = _liveCategories.firstWhere(
        (item) => item['category_name'] == category || item['category_id'] == category,
        orElse: () => {},
      );
      _selectedCategory = matched.isEmpty ? category : (matched['category_name'] ?? category);
    }
    _applyFilters();
    notifyListeners();
  }
  void setTab(String tab) => setActiveTab(tab);

  final Set<String> _favorites = <String>{};
  Set<String> get favorites => Set.unmodifiable(_favorites);
  PlaylistItem? _currentStream;
  PlaylistItem? get currentStream => _currentStream;
  void selectStream(PlaylistItem stream) {
    _currentStream = stream;
    notifyListeners();
  }
  void zapChannel(bool next) {
    final source = _filteredStreams.isNotEmpty ? _filteredStreams : _allStreams;
    if (source.isEmpty) return;
    final currentIndex = _currentStream == null ? -1 : source.indexWhere((item) => item.streamId == _currentStream!.streamId);
    final nextIndex = currentIndex < 0 ? 0 : (next ? (currentIndex + 1) % source.length : (currentIndex - 1 + source.length) % source.length);
    _currentStream = source[nextIndex];
    notifyListeners();
  }
  Future<void> toggleFavorite(String streamId) async {
    if (streamId.trim().isEmpty) return;
    if (!_favorites.add(streamId)) _favorites.remove(streamId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites.toList());
    notifyListeners();
  }
  Future<void> addToRecentlyPlayed(PlaylistItem stream) async {
    _recentlyPlayed.removeWhere((item) => item.streamId == stream.streamId);
    _recentlyPlayed.insert(0, stream);
    if (_recentlyPlayed.length > 30) _recentlyPlayed = _recentlyPlayed.take(30).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recently_played', json.encode(_recentlyPlayed.map((item) => item.toJson()).toList()));
    notifyListeners();
  }
  int _playerSettingsVersion = 0;
  int get playerSettingsVersion => _playerSettingsVersion;
  Future<void> setPlayerStringPreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    if (key == 'global_referer') _globalReferer = value;
    _playerSettingsVersion++;
    notifyListeners();
  }

  final Set<String> _lockedCategories = <String>{};
  Set<String> get lockedCategories => Set.unmodifiable(_lockedCategories);
  Future<void> toggleCategoryLock(String category) async {
    final value = category.trim();
    if (value.isEmpty) return;
    if (!_lockedCategories.add(value)) _lockedCategories.remove(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('locked_categories', _lockedCategories.toList());
    notifyListeners();
  }

  int _currentVersionCode = 232;
  bool _isVersionBlocked = false;
  bool get isVersionBlocked => _isVersionBlocked;

  String? _stalkerToken;
  String get stalkerToken => _stalkerToken ?? '';
  String _globalReferer = '';
  String get globalReferer => _globalReferer;
  String get globalUserAgent => 'MAG250 stbapp ver: 2 rev: 250';

  bool _tvBoxFocusEnabled = true;
  bool get tvBoxFocusEnabled => _tvBoxFocusEnabled;
  Future<void> setTvBoxFocusEnabled(bool value) async {
    _tvBoxFocusEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tv_box_focus_enabled', value);
    notifyListeners();
  }

  bool _showMoviesSeries = true;
  bool get showMoviesSeries => _showMoviesSeries;
  Future<void> setShowMoviesSeries(bool value) async {
    _showMoviesSeries = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_movies_series', value);
    notifyListeners();
  }

  String _channelFilter = 'الكل';
  String get channelFilter => _channelFilter;
  Future<void> setChannelFilter(String value) async {
    _channelFilter = value;
    _applyFilters();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('channel_filter', value);
    notifyListeners();
  }

  bool _blockAdultContent = true;
  bool get blockAdultContent => _blockAdultContent;
  Future<void> setBlockAdultContent(bool value) async {
    _blockAdultContent = value;
    _applyFilters();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('block_adult_content', value);
    notifyListeners();
  }

  bool _isParentalEnabled = false;
  String _parentalPin = '';
  final Set<String> _unlockedCategories = <String>{};
  bool get isParentalEnabled => _isParentalEnabled;
  String get parentalPin => _parentalPin;
  bool isCategoryLocked(String categoryName) {
    if (categoryName.trim().isEmpty) return false;
    if (_unlockedCategories.contains(categoryName)) return false;
    return _lockedCategories.contains(categoryName) || (_isParentalEnabled && FilterService.isAdultStream('', categoryName));
  }
  void unlockCategorySession(String categoryName) {
    if (categoryName.trim().isEmpty) return;
    _unlockedCategories.add(categoryName);
    notifyListeners();
  }
  Future<void> setParentalPin(String value) async {
    final pin = value.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) return;
    _parentalPin = pin;
    _isParentalEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parental_pin', pin);
    await prefs.setBool('parental_enabled', true);
    notifyListeners();
  }
  Future<void> clearParentalSettings() async {
    _parentalPin = '';
    _isParentalEnabled = false;
    _unlockedCategories.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parental_pin');
    await prefs.setBool('parental_enabled', false);
    notifyListeners();
  }

  String _profileName = 'LIVE STREAM PREMIUM';
  String _profileLogo = 'play';
  String _profileImagePath = '';
  String get profileName => _profileName;
  String get profileLogo => _profileLogo;
  String get profileImagePath => _profileImagePath;
  Future<void> setProfileName(String value) async {
    final name = value.trim();
    if (name.isNotEmpty) _profileName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _profileName);
    notifyListeners();
  }
  Future<void> setProfileLogo(String value) async {
    _profileLogo = value.trim().isEmpty ? 'play' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_logo', _profileLogo);
    notifyListeners();
  }
  Future<void> setProfileImagePath(String value) async {
    _profileImagePath = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', _profileImagePath);
    notifyListeners();
  }

  DateTime? _expirationAt;
  String _subscriptionType = '';
  String get subscriptionType => _subscriptionType;
  String get expirationDateFormatted {
    if (_expirationAt == null) return 'بلا حدود';
    final local = _expirationAt!.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day';
  }

  static const String _workerBase = 'https://iptv-subscription-api.tvkora56.workers.dev';
  static const String _configUrl = '$_workerBase/v1/config';
  static const String _loginUrl = '$_workerBase/v1/login';
  static const String _menuUrl = 'https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/Main_menu.json';

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _appLanguage = prefs.getString('app_language') ?? 'العربية';
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _activationCode = prefs.getString('active_code') ?? '';
    _tvBoxFocusEnabled = prefs.getBool('tv_box_focus_enabled') ?? true;
    _showMoviesSeries = prefs.getBool('show_movies_series') ?? true;
    _channelFilter = prefs.getString('channel_filter') ?? 'الكل';
    _blockAdultContent = prefs.getBool('block_adult_content') ?? true;
    _isParentalEnabled = prefs.getBool('parental_enabled') ?? false;
    _parentalPin = prefs.getString('parental_pin') ?? '';
    _profileName = prefs.getString('profile_name') ?? 'LIVE STREAM PREMIUM';
    _profileLogo = prefs.getString('profile_logo') ?? 'play';
    _profileImagePath = prefs.getString('profile_image_path') ?? '';
    _premiumTheme = prefs.getString('premium_theme') ?? 'البنفسجي الملكي';
    _favorites.addAll(prefs.getStringList('favorites') ?? const <String>[]);
    _lockedCategories.addAll(prefs.getStringList('locked_categories') ?? const <String>[]);
    final recentJson = prefs.getString('recently_played');
    if (recentJson != null) {
      try {
        final decoded = json.decode(recentJson);
        if (decoded is List) _recentlyPlayed = decoded.whereType<Map>().map((item) => PlaylistItem.fromJson(Map<String, dynamic>.from(item))).toList();
      } catch (_) {}
    }
    final savedPlaylistsStr = prefs.getString('saved_playlists');
    if (savedPlaylistsStr != null) {
      try {
        _savedPlaylists = (json.decode(savedPlaylistsStr) as List).map((e) => UserPlaylist.fromJson(e)).toList();
      } catch (_) {
        _savedPlaylists = [];
      }
    }
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 232;
    await checkRemoteBlocking();
    if (_isLoggedIn && _activationCode.isNotEmpty) {
      final restored = await loginWithCode(_activationCode);
      if (!restored) {
        _isLoggedIn = false;
        _activationCode = '';
        await prefs.remove('active_code');
        await prefs.setBool('is_logged_in', false);
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final res = await http.get(Uri.parse('$_configUrl?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final blocking = data['blocking'];
        if (blocking is Map && blocking['block_message'] is String) _remoteBlockMessage = blocking['block_message'].toString();
        if (blocking is Map && blocking['min_version_code'] != null && _currentVersionCode < (int.tryParse(blocking['min_version_code'].toString()) ?? 0)) {
          _isVersionBlocked = true;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<bool> loginWithCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': cleanCode, 'device_id': 'UKQ1.240624.001'}),
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['ok'] == true && data['server'] is Map) {
          final server = Map<String, dynamic>.from(data['server'] as Map);
          final subscription = data['subscription'] is Map ? Map<String, dynamic>.from(data['subscription'] as Map) : <String, dynamic>{};
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_code', cleanCode);
          await prefs.setBool('is_logged_in', true);
          _isLoggedIn = true;
          _activationCode = cleanCode;
          _subscriptionType = (subscription['max_devices']?.toString() == '0') ? 'اشتراك بلا حدود' : 'اشتراك Premium';
          final expiry = subscription['expires_at']?.toString();
          _expirationAt = expiry == null || expiry.isEmpty ? null : DateTime.tryParse(expiry);
          final list = UserPlaylist(
            id: 'cf_$cleanCode', name: 'Premium Server', type: server['type']?.toString() ?? 'xtream',
            host: server['host']?.toString(), username: server['username']?.toString(), password: server['password']?.toString(),
          );
          _savedPlaylists = [list];
          _activePlaylistId = list.id;
          await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
          if (server['content_mode']?.toString() == 'github') {
            await _loadCuratedGitHubContent();
          } else {
            await loadPlaylistStreams(list.id);
          }
          if (_allStreams.isEmpty) {
            _lastError = 'تم قبول الكود، لكن مصدر القنوات لم يُرجع قائمة حالياً. حاول التحديث بعد لحظات.';
            _isLoggedIn = false;
            _activationCode = '';
            _savedPlaylists = [];
            _activePlaylistId = null;
            await prefs.remove('active_code');
            await prefs.remove('saved_playlists');
            await prefs.setBool('is_logged_in', false);
            _isLoading = false;
            notifyListeners();
            return false;
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Login Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _loadCuratedGitHubContent() async {
    _isFetchingData = true;
    _allStreams = [];
    _liveCategories = [];
    notifyListeners();
    try {
      final res = await http.get(Uri.parse('$_menuUrl?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          final catsSeen = <String, String>{};
          for (final raw in decoded) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final catId = item['category_id']?.toString() ?? '99';
            final catName = item['category_name']?.toString() ?? 'بث مباشر';
            if (!catsSeen.containsKey(catId)) {
              catsSeen[catId] = catName;
              _liveCategories.add({'category_id': catId, 'category_name': catName});
            }
            _allStreams.add(PlaylistItem(num: null, streamId: _allStreams.length.toString(), name: item['name']?.toString() ?? 'Unknown', streamIcon: item['icon']?.toString() ?? '', categoryId: catId, categoryName: catName, url: item['url']?.toString() ?? '', type: 'live'));
          }
        }
      }
    } catch (_) {}
    _liveCategories = FilterService.interceptAndFilterCategories(_liveCategories, blockAdult: _blockAdultContent);
    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
  }

  Future<void> loadPlaylistStreams(String id) async {
    _isFetchingData = true;
    _allStreams = [];
    _filteredStreams = [];
    _liveCategories = [];
    notifyListeners();
    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) {
      _isFetchingData = false;
      notifyListeners();
      return;
    }
    _activePlaylistId = id;
    final host = playlist.host?.trim() ?? '', user = playlist.username?.trim() ?? '', pass = playlist.password?.trim() ?? '';
    if (host.isEmpty || user.isEmpty) {
      _isFetchingData = false;
      notifyListeners();
      return;
    }
    try {
      if (playlist.type == 'stalker') {
        await _loadStalkerData(host, user);
      } else {
        await _loadCategories(host, user, pass);
        await _loadStreams(host, user, pass);
      }
    } catch (e) {
      debugPrint('Playlist loading error: $e');
    }
    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
  }

  Uri _xtreamApiUri(String host, String user, String pass, String action) {
    final base = Uri.parse(host.endsWith('/') ? host.substring(0, host.length - 1) : host);
    final path = '${base.path.replaceFirst(RegExp(r'/$'), '')}/player_api.php';
    return base.replace(path: path, queryParameters: {'username': user, 'password': pass, 'action': action});
  }

  Future<void> _loadStalkerData(String host, String mac) async {
    var baseUrl = host;
    if (!baseUrl.contains('/portal.php')) baseUrl = baseUrl.endsWith('/') ? '${baseUrl}portal.php' : '$baseUrl/portal.php';
    final headers = {'User-Agent': globalUserAgent, 'Cookie': 'mac=$mac'};
    try {
      final hRes = await http.get(Uri.parse('$baseUrl?type=stb&action=handshake'), headers: headers).timeout(const Duration(seconds: 15));
      if (hRes.statusCode == 200) {
        try {
          final hData = json.decode(hRes.body);
          _stalkerToken = hData['js']?['token']?.toString();
          if (_stalkerToken != null && _stalkerToken!.isNotEmpty) headers['Authorization'] = 'Bearer $_stalkerToken';
        } catch (_) {}
      }
      await http.get(Uri.parse('$baseUrl?type=stb&action=get_profile'), headers: headers).timeout(const Duration(seconds: 15));
      final catRes = await http.get(Uri.parse('$baseUrl?type=itv&action=get_categories'), headers: headers).timeout(const Duration(seconds: 20));
      if (catRes.statusCode == 200) {
        final decoded = json.decode(catRes.body);
        List cats = [];
        if (decoded is Map && decoded['js'] != null) cats = decoded['js'] is List ? decoded['js'] : [];
        else if (decoded is List) cats = decoded;
        _liveCategories = cats.whereType<Map>().map<Map<String, String>>((item) => {'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? 'بث مباشر'}).toList();
        _liveCategories = FilterService.interceptAndFilterCategories(_liveCategories, blockAdult: _blockAdultContent);
      }
      final chanRes = await http.get(Uri.parse('$baseUrl?type=itv&action=get_all_channels'), headers: headers).timeout(const Duration(seconds: 30));
      if (chanRes.statusCode == 200) {
        final decoded = json.decode(chanRes.body);
        List channels = [];
        if (decoded is Map && decoded['js'] != null) {
          final js = decoded['js'];
          if (js is Map && js['data'] is List) channels = js['data'];
          else if (js is List) channels = js;
        } else if (decoded is List) channels = decoded;
        for (final raw in channels) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final catId = item['category_id']?.toString() ?? '';
          final cat = _liveCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
          _allStreams.add(PlaylistItem(num: int.tryParse(item['number']?.toString() ?? ''), streamId: item['id']?.toString() ?? '', name: item['name']?.toString() ?? 'Unknown', streamIcon: item['logo']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? (cat['category_name'] ?? 'بث مباشر') : 'بث مباشر', url: '$baseUrl?type=itv&action=create_link&cmd=${Uri.encodeComponent(item['cmd']?.toString() ?? '')}', type: 'live'));
        }
      }
    } catch (e) {
      debugPrint('Stalker loading error: $e');
    }
  }

  Future<void> _loadCategories(String host, String user, String pass) async {
    try {
      final response = await http.get(_xtreamApiUri(host, user, pass, 'get_live_categories')).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          _liveCategories = decoded.whereType<Map>().map<Map<String, String>>((item) => {'category_id': item['category_id']?.toString() ?? '', 'category_name': item['category_name']?.toString() ?? 'بث مباشر'}).toList();
          _liveCategories = FilterService.interceptAndFilterCategories(_liveCategories, blockAdult: _blockAdultContent);
        }
      }
    } catch (e) {
      debugPrint('Categories loading error: $e');
    }
  }

  Future<void> _loadStreams(String host, String user, String pass) async {
    try {
      final response = await http.get(_xtreamApiUri(host, user, pass, 'get_live_streams')).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is! List) return;
        final cleanHost = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
        for (final raw in decoded) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final streamId = item['stream_id']?.toString() ?? '';
          if (streamId.isEmpty) continue;
          final catId = item['category_id']?.toString() ?? '';
          final cat = _liveCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
          _allStreams.add(PlaylistItem(num: int.tryParse(item['num']?.toString() ?? ''), streamId: streamId, name: item['name']?.toString() ?? 'Unknown', streamIcon: item['stream_icon']?.toString() ?? '', categoryId: catId, categoryName: cat.isNotEmpty ? (cat['category_name'] ?? 'بث مباشر') : 'بث مباشر', url: '$cleanHost/live/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/${Uri.encodeComponent(streamId)}.ts', type: 'live'));
        }
      }
    } catch (e) {
      debugPrint('Streams loading error: $e');
    }
  }

  void _applyFilters() {
    var result = FilterService.interceptAndFilterStreams(_allStreams, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
    if (_searchQuery.isNotEmpty) result = result.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    if (_selectedCategory != 'all') {
      result = result.where((s) => s.categoryId == _selectedCategory || s.categoryName == _selectedCategory).toList();
    }
    _filteredStreams = result;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }
  void setSelectedCategory(String category) => setCategory(category);
  void setActiveTab(String tab) {
    _activeTab = tab;
    _selectedCategory = 'all';
    _applyFilters();
    notifyListeners();
  }

  Future<void> changeSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_code');
    await prefs.remove('saved_playlists');
    await prefs.setBool('is_logged_in', false);
    _isLoggedIn = false;
    _activationCode = '';
    _savedPlaylists = [];
    _activePlaylistId = null;
    _allStreams = [];
    _filteredStreams = [];
    _liveCategories = [];
    _subscriptionType = '';
    _expirationAt = null;
    _currentStream = null;
    _lastError = null;
    notifyListeners();
  }

  Future<void> logout() => changeSubscription();
}
