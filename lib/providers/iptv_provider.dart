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

  UserPlaylist({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.username,
    this.password,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'host': host,
        'username': username,
        'password': password,
      };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] ?? '',
        host: json['host'],
        username: json['username'],
        password: json['password'],
      );
}

class MyHttpOverrides extends HttpOverrides {
  final String proxyAddress;
  MyHttpOverrides(this.proxyAddress);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        if (proxyAddress.isNotEmpty) {
          return "PROXY $proxyAddress;";
        }
        return "DIRECT";
      }
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return false; 
      };
  }
}

class IPTVProvider with ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  String _appLanguage = 'العربية';
  String get appLanguage => _appLanguage;
  String _premiumTheme = 'البنفسجي الملكي';
  String get premiumTheme => _premiumTheme;
  Color get accentColor {
    switch (_premiumTheme) {
      case 'الأزرق الليلي': return const Color(0xFF38BDF8);
      case 'الذهبي الفاخر': return const Color(0xFFFFC857);
      case 'الزمردي الداكن': return const Color(0xFF34D399);
      case 'الروبي السينمائي': return const Color(0xFFFF5C77);
      case 'السماوي الكهربائي': return const Color(0xFF22D3EE);
      case 'الغروب البرتقالي': return const Color(0xFFFB923C);
      default: return const Color(0xFFA855F7);
    }
  }

  Color get themeBackground {
    switch (_premiumTheme) {
      case 'الأزرق الليلي': return const Color(0xFF07131F);
      case 'الذهبي الفاخر': return const Color(0xFF171107);
      case 'الزمردي الداكن': return const Color(0xFF071914);
      case 'الروبي السينمائي': return const Color(0xFF1B0A10);
      case 'السماوي الكهربائي': return const Color(0xFF06171D);
      case 'الغروب البرتقالي': return const Color(0xFF1B0E07);
      default: return const Color(0xFF09091A);
    }
  }

  Color get themeSurface {
    switch (_premiumTheme) {
      case 'الأزرق الليلي': return const Color(0xFF10253A);
      case 'الذهبي الفاخر': return const Color(0xFF28200F);
      case 'الزمردي الداكن': return const Color(0xFF102A22);
      case 'الروبي السينمائي': return const Color(0xFF30111B);
      case 'السماوي الكهربائي': return const Color(0xFF0D2933);
      case 'الغروب البرتقالي': return const Color(0xFF30170C);
      default: return const Color(0xFF14112B);
    }
  }
  String _profileName = 'Premium User';
  String get profileName => _profileName;
  String _profileLogo = 'play';
  String get profileLogo => _profileLogo;
  String _profileImagePath = '';
  String get profileImagePath => _profileImagePath;

  Future<void> setAppLanguage(String language) async {
    _appLanguage = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language);
  }

  Future<void> setPremiumTheme(String theme) async {
    _premiumTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('premium_theme', theme);
  }

  Future<void> setProfileName(String value) async {
    final cleanName = value.trim();
    if (cleanName.isEmpty) return;
    _profileName = cleanName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', cleanName);
  }

  Future<void> setProfileLogo(String value) async {
    _profileLogo = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_logo', value);
  }

  Future<void> setProfileImagePath(String value) async {
    _profileImagePath = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', value);
  }

  int _playerSettingsVersion = 0;
  int get playerSettingsVersion => _playerSettingsVersion;
  bool _tvBoxFocusEnabled = true;
  bool get tvBoxFocusEnabled => _tvBoxFocusEnabled;

  Future<void> setTvBoxFocusEnabled(bool value) async {
    _tvBoxFocusEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tv_box_focus_enabled', value);
  }

  Future<void> setPlayerStringPreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _playerSettingsVersion++;
    notifyListeners();
  }

  bool _isSecured = true;
  bool get isSecured => _isSecured;
  String _securityMessage = "";
  String get securityMessage => _securityMessage;

  bool _blockAdultContent = true;
  bool get blockAdultContent => _blockAdultContent;

  void setBlockAdultContent(bool value) async {
    _blockAdultContent = value;
    _applyFilters();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('block_adult_content', value);
  }
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
  Timer? _searchDebounce;
  bool _isLoggedIn = false;

  List<Map<String, String>> _liveCategories = [];
  List<Map<String, String>> _movieCategories = [];
  List<Map<String, String>> _seriesCategories = [];

  String _activationCode = "";
  String _stalkerToken = "";
  String get stalkerToken => _stalkerToken;
  int _activationTime = 0;
  int _activationDurationHours = -1;
  String _subscriptionType = "";

  bool _showMoviesSeries = true;
  bool get showMoviesSeries => _showMoviesSeries;

  String _channelFilter = "الكل";
  String get channelFilter => _channelFilter;

  String _parentalPin = "";
  String get parentalPin => _parentalPin;
  bool get isParentalEnabled => _parentalPin.isNotEmpty;

  List<String> _lockedCategories = [];
  List<String> get lockedCategories => _lockedCategories;

  final List<String> _sessionUnlockedCategories = [];

  Future<void> setParentalPin(String newPin) async {
    _parentalPin = newPin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parental_pin', newPin);
    notifyListeners();
  }

  Future<void> toggleCategoryLock(String categoryName) async {
    if (_lockedCategories.contains(categoryName)) {
      _lockedCategories.remove(categoryName);
    } else {
      _lockedCategories.add(categoryName);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('locked_categories', _lockedCategories);
    notifyListeners();
  }

  bool isCategoryLocked(String categoryName) {
    if (_sessionUnlockedCategories.contains(categoryName)) return false;
    return isParentalEnabled && _lockedCategories.contains(categoryName);
  }

  void unlockCategorySession(String categoryName) {
    if (!_sessionUnlockedCategories.contains(categoryName)) {
      _sessionUnlockedCategories.add(categoryName);
      notifyListeners();
    }
  }

  Future<void> clearParentalSettings() async {
    _parentalPin = "";
    _lockedCategories.clear();
    _sessionUnlockedCategories.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parental_pin');
    await prefs.remove('locked_categories');
    notifyListeners();
  }

  void setShowMoviesSeries(bool value) async {
    _showMoviesSeries = value;
    _applyFilters();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('filter_show_movies_series', value);
  }

  void setChannelFilter(String value) async {
    _channelFilter = value;
    _applyFilters();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('channel_filter', value);
  }

  String get activeTab => _activeTab;
  String _globalUserAgent = '';
  String get globalUserAgent => _globalUserAgent;
  void setGlobalUserAgent(String value) {
    _globalUserAgent = value;
    notifyListeners();
  }

  String _globalReferer = '';
  String get globalReferer => _globalReferer;
  void setGlobalReferer(String value) {
    _globalReferer = value;
    notifyListeners();
  }
  
  static const _securityChannel = MethodChannel('com.mahmoud.iptv/security');
  bool _snifferDetected = false;
  bool get snifferDetected => _snifferDetected;

  static const int APP_VERSION_CODE = 235;
  String _currentVersionStr = "2.2.35";
  int _currentVersionCode = 235;

  bool _isVersionBlocked = false;
  String _remoteBlockMessage = "🚨 تحديث إجباري مطلوب فوراً 🚨";
  String get remoteBlockMessage => _remoteBlockMessage;
  bool get isVersionBlocked => _isVersionBlocked;

  bool _vpnDetected = false;
  bool get vpnDetected => _vpnDetected;

  String _globalProxy = "";
  String get globalProxy => _globalProxy;

  String _announcementText = "";
  String get announcementText => _announcementText;
  bool _disableVpnCheck = false;
  bool _disableSnifferCheck = false;

  List<PlaylistItem> _recentlyPlayed = [];
  List<PlaylistItem> get recentlyPlayed => _recentlyPlayed;

  void addToRecentlyPlayed(PlaylistItem stream) async {
    _recentlyPlayed.removeWhere((item) => item.streamId == stream.streamId);
    _recentlyPlayed.insert(0, stream);
    if (_recentlyPlayed.length > 10) _recentlyPlayed = _recentlyPlayed.sublist(0, 10);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = _recentlyPlayed.map((item) => item.toJson()).toList();
      await prefs.setString('recently_played_streams', jsonEncode(jsonList));
    } catch (_) {}
  }

  void loadRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('recently_played_streams');
      if (savedStr != null) {
        final List decoded = jsonDecode(savedStr);
        _recentlyPlayed = decoded.map((item) => PlaylistItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  List<PlaylistItem> get streams => _filteredStreams;
  List<PlaylistItem> get allStreams => _allStreams;
  PlaylistItem? get currentStream => _currentStream;
  List<String> get favorites => _favorites;

  String get activationCode => _activationCode;
  int get activationTime => _activationTime;
  int get activationDurationHours => _activationDurationHours;
  String get subscriptionType => _subscriptionType;
  
  String get expirationDateFormatted {
    if (_activationDurationHours == -1) return "بلا حدود";
    final expiryTime = _activationTime + (_activationDurationHours * 3600000);
    final date = DateTime.fromMillisecondsSinceEpoch(expiryTime);
    return "${date.year}/${date.month}/${date.day}";
  }

  String? get activePlaylistId => _activePlaylistId;

  List<Map<String, String>> get liveCategories => _liveCategories;
  List<Map<String, String>> get movieCategories => _movieCategories;
  List<Map<String, String>> get seriesCategories => _seriesCategories;
  List<String> get categories {
    List<String> cats = [];
    if (_activeTab == "live") {
      cats = _liveCategories.map((c) => c['category_name'] ?? '').toList();
    } else if (_activeTab == "movie") {
      cats = _movieCategories.map((c) => c['category_name'] ?? '').toList();
    } else if (_activeTab == "series") {
      cats = _seriesCategories.map((c) => c['category_name'] ?? '').toList();
    }

    if (_blockAdultContent) {
      final List<String> adultKeywords = ["+18", "18+", "ADULT", "XXX", "PORN", "SEX", "REDLIGHT", "FORBIDDEN", "ع للكبار", "للكبار", "X-RATED", "BLUE", "PENTHOUSE", "PLAYBOY", "HUSTLER", "EGOIST", "VENUS", "CANDY", "NIGHT", "EROTIC"];
      cats = cats.where((c) {
        final String upper = c.toUpperCase();
        for (final kw in adultKeywords) {
          if (upper.contains(kw)) return false;
        }
        return true;
      }).toList();
    }
    return cats;
  }

  bool get isExpired {
    if (_activationDurationHours == -1) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryTime = _activationTime + (_activationDurationHours * 3600000);
    return now > expiryTime;
  }

  void init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _appLanguage = prefs.getString('app_language') ?? 'العربية';
    _premiumTheme = prefs.getString('premium_theme') ?? 'البنفسجي الملكي';
    _profileName = prefs.getString('profile_name') ?? 'Premium User';
    _profileLogo = prefs.getString('profile_logo') ?? 'play';
    _profileImagePath = prefs.getString('profile_image_path') ?? '';
    _tvBoxFocusEnabled = prefs.getBool('tv_box_focus_enabled') ?? true;
    _blockAdultContent = prefs.getBool('block_adult_content') ?? true;
    _channelFilter = prefs.getString('channel_filter') ?? "الكل";
    _showMoviesSeries = prefs.getBool('filter_show_movies_series') ?? true;
    _parentalPin = prefs.getString('parental_pin') ?? "";
    _lockedCategories = prefs.getStringList('locked_categories') ?? [];

    final savedPlaylistsStr = prefs.getString('saved_playlists');
    if (savedPlaylistsStr != null) {
      final List decoded = json.decode(savedPlaylistsStr);
      _savedPlaylists = decoded.map((e) => UserPlaylist.fromJson(e)).toList();
    }

    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _activationCode = prefs.getString('active_code') ?? "";
    _activationTime = prefs.getInt('active_code_activated_at') ?? 0;
    _activationDurationHours = prefs.getInt('active_code_duration_hours') ?? -1;
    _subscriptionType = prefs.getString('active_code_sub_name') ?? "";

    _favorites = prefs.getStringList('favorites') ?? [];
    loadRecentlyPlayed();

    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersionStr = packageInfo.version;
    _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 235;

    await checkRemoteBlocking();
    await _checkVpnAndProxyStatus();

    if (_isLoggedIn && _savedPlaylists.isNotEmpty && _isSecured) {
      _activePlaylistId = _savedPlaylists.first.id;
      loadPlaylistStreams(_activePlaylistId!);
    }

    HttpOverrides.global = MyHttpOverrides("");
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final configRes = await http.get(Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/config?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 5));
      if (configRes.statusCode == 200) {
        final Map<String, dynamic> configData = json.decode(configRes.body);
        Map<String, dynamic>? blockData;
        if (configData.containsKey('blocking')) blockData = Map<String, dynamic>.from(configData['blocking']);
        if (blockData != null) {
          bool isBlocked = false;
          if (blockData.containsKey('min_version_code')) {
            final int minVer = int.tryParse(blockData['min_version_code'].toString()) ?? 0;
            if (_currentVersionCode < minVer) isBlocked = true;
          }
          if (_isVersionBlocked != isBlocked) {
            _isVersionBlocked = isBlocked;
            notifyListeners();
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _checkVpnAndProxyStatus() async {
    try {
      await checkSecurity();
      bool detected = _vpnDetected || _snifferDetected;
      if (!detected) {
        try {
          final systemProxy = HttpClient.findProxyFromEnvironment(Uri.parse("https://google.com"));
          if (systemProxy != "DIRECT" && systemProxy.trim().isNotEmpty) detected = true;
        } catch (_) {}
      }
      if (_vpnDetected != detected) {
        _vpnDetected = detected;
        notifyListeners();
      }
    } catch (_) {
      _vpnDetected = false;
    }
  }

  Future<void> checkSecurity() async {
    try {
      final Map? result = await _securityChannel.invokeMapMethod('checkSecurity');
      if (result != null) {
        final shouldBlock = result['shouldBlock'] == true || result['snifferInstalled'] == true;
        final vpnActive = result['vpnActive'] == true || result['proxyActive'] == true;
        if (_snifferDetected != shouldBlock || _vpnDetected != vpnActive) {
          _snifferDetected = shouldBlock;
          _vpnDetected = vpnActive;
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }
    } catch (_) {}
    return "unknown_device";
  }

  Future<bool> loginWithCode(String code) async {
    lastError = null;
    String cleanCode = code.trim();
    if (cleanCode.isEmpty) { lastError = "رمز الدخول فارغ"; return false; }
    _isLoading = true;
    notifyListeners();

    try {
      final loginUrl = Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/v1/login");
      final deviceId = await _getDeviceId();
      final loginRes = await http.post(loginUrl, headers: {"Content-Type": "application/json"}, body: json.encode({"code": cleanCode, "device_id": deviceId, "version_code": _currentVersionCode})).timeout(const Duration(seconds: 15));

      if (loginRes.statusCode == 200) {
        final loginData = json.decode(loginRes.body);
        if (loginData['ok'] == true) {
          final userData = loginData['user'];
          final host = userData['host'] ?? "";
          final user = userData['username'] ?? "";
          final pass = userData['password'] ?? "";
          final pType = userData['server_type'] ?? "xtream";
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_code', cleanCode);
          await prefs.setBool('is_logged_in', true);
          
          _activationCode = cleanCode;
          _isLoggedIn = true;

          final list = UserPlaylist(id: "${pType}_$cleanCode", name: "Premium", type: pType, host: host, username: user, password: pass);
          _savedPlaylists = [list];
          _activePlaylistId = list.id;
          await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
          
          _isLoading = false;
          notifyListeners();
          await loadPlaylistStreams(list.id);
          return true;
        }
      }
      
      // Fallback
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
              _isLoggedIn = true;
              _activationCode = cleanCode;
              
              final list = UserPlaylist(id: "fallback_$cleanCode", name: "Premium", type: server['type'] ?? 'xtream', host: server['host'], username: server['username'], password: server['password']);
              _savedPlaylists = [list];
              _activePlaylistId = list.id;
              await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
              
              _isLoading = false;
              notifyListeners();
              await loadPlaylistStreams(list.id);
              return true;
          }
      }
      lastError = "رمز الدخول غير صحيح";
    } catch (e) {
      lastError = "تعذر الاتصال";
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadPlaylistStreams(String id) async {
    _isFetchingData = true;
    notifyListeners();
    
    // 1. Reset Lists
    _allStreams = [];
    _liveCategories = [];
    _movieCategories = [];
    _seriesCategories = [];
    
    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) { _isFetchingData = false; notifyListeners(); return; }
    _activePlaylistId = id;

    // 2. ALWAYS Load GitHub Curated List First
    try {
      final url = Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/Main_menu.json?t=${DateTime.now().millisecondsSinceEpoch}");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        List<Map<String, String>> tempCats = [];
        List<PlaylistItem> tempStreams = [];
        Set<String> catIds = {};
        for (int i = 0; i < data.length; i++) {
          final item = data[i];
          final catName = item['category_name']?.toString() ?? 'بث مباشر';
          final catId = item['category_id']?.toString() ?? catName;
          if (!catIds.contains(catId)) {
            catIds.add(catId);
            tempCats.add({'category_id': catId, 'category_name': catName, 'parent_id': '0'});
          }
          tempStreams.add(PlaylistItem(
              num: i,
              streamId: "github_$i",
              name: item['name']?.toString() ?? '',
              streamIcon: item['icon']?.toString() ?? '',
              categoryId: catId,
              categoryName: catName,
              url: item['url']?.toString() ?? '',
              type: item['type']?.toString() ?? 'live'));
        }
        _liveCategories.addAll(FilterService.interceptAndFilterCategories(tempCats.where((c) => !c['category_id']!.contains('movie') && !c['category_id']!.contains('series')).toList(), blockAdult: _blockAdultContent));
        _movieCategories.addAll(FilterService.interceptAndFilterCategories(tempCats.where((c) => c['category_id']!.contains('movie')).toList(), blockAdult: _blockAdultContent));
        _seriesCategories.addAll(FilterService.interceptAndFilterCategories(tempCats.where((c) => c['category_id']!.contains('series')).toList(), blockAdult: _blockAdultContent));
        _allStreams.addAll(FilterService.interceptAndFilterStreams(tempStreams, blockAdult: _blockAdultContent, channelFilter: _channelFilter));
      }
    } catch (e) {
      debugPrint("GitHub Load Error: $e");
    }

    // 3. Load Server Specific Content and Append
    try {
      final host = (playlist.host ?? '').trim();
      final user = (playlist.username ?? '').trim();
      final pass = (playlist.password ?? '').trim();
      
      if (host.isNotEmpty && user.isNotEmpty) {
        final liveCatsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 15));
        final liveStreamsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 25));
        
        if (liveCatsRes.statusCode == 200) {
          final List decoded = json.decode(liveCatsRes.body);
          final serverCats = decoded.map<Map<String, String>>((item) => {'category_id': "srv_${item['category_id']}", 'category_name': item['category_name']?.toString() ?? ''}).toList();
          _liveCategories.addAll(FilterService.interceptAndFilterCategories(serverCats, blockAdult: _blockAdultContent));
        }
        
        if (liveStreamsRes.statusCode == 200) {
          final List decoded = json.decode(liveStreamsRes.body);
          List<PlaylistItem> serverStreams = [];
          for (final item in decoded) {
            final catId = "srv_${item['category_id']}";
            final sId = item['stream_id']?.toString() ?? '';
            serverStreams.add(PlaylistItem(num: null, streamId: "srv_$sId", name: item['name']?.toString() ?? '', streamIcon: item['stream_icon']?.toString() ?? '', categoryId: catId, categoryName: 'بث مباشر', url: "$host/live/$user/$pass/$sId.ts", type: "live"));
          }
          _allStreams.addAll(FilterService.interceptAndFilterStreams(serverStreams, blockAdult: _blockAdultContent, channelFilter: _channelFilter));
        }
      }
    } catch (e) {}

    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
  }

  void _applyFilters() {
    _filteredStreams = _allStreams.where((stream) {
      if (_activeTab != stream.type) return false;
      if (_selectedCategory != "all" && stream.categoryId != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty && !stream.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
  }

  Future<void> setActiveTab(String tab) async {
    _activeTab = tab;
    _selectedCategory = "all";
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void selectStream(PlaylistItem item) {
    _currentStream = item;
    addToRecentlyPlayed(item);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _savedPlaylists.clear();
    _allStreams.clear();
    notifyListeners();
  }
}
