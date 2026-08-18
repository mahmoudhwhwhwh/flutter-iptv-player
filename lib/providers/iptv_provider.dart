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

// تجاوز طلبات الـ HTTP لمنع تخطي شهادات الـ SSL وتخريب الاتصال عبر البروكسي
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
        // نرفض كافة الشهادات غير الموثوقة لمنع هجمات التقاط الحزم والتجسس فورا
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
      case 'الأزرق الليلي':
        return const Color(0xFF38BDF8);
      case 'الذهبي الفاخر':
        return const Color(0xFFFFC857);
      case 'الزمردي الداكن':
        return const Color(0xFF34D399);
      case 'الروبي السينمائي':
        return const Color(0xFFFF5C77);
      case 'السماوي الكهربائي':
        return const Color(0xFF22D3EE);
      case 'الغروب البرتقالي':
        return const Color(0xFFFB923C);
      default:
        return const Color(0xFFA855F7);
    }
  }

  Color get themeBackground {
    switch (_premiumTheme) {
      case 'الأزرق الليلي':
        return const Color(0xFF07131F);
      case 'الذهبي الفاخر':
        return const Color(0xFF171107);
      case 'الزمردي الداكن':
        return const Color(0xFF071914);
      case 'الروبي السينمائي':
        return const Color(0xFF1B0A10);
      case 'السماوي الكهربائي':
        return const Color(0xFF06171D);
      case 'الغروب البرتقالي':
        return const Color(0xFF1B0E07);
      default:
        return const Color(0xFF09091A);
    }
  }

  Color get themeSurface {
    switch (_premiumTheme) {
      case 'الأزرق الليلي':
        return const Color(0xFF10253A);
      case 'الذهبي الفاخر':
        return const Color(0xFF28200F);
      case 'الزمردي الداكن':
        return const Color(0xFF102A22);
      case 'الروبي السينمائي':
        return const Color(0xFF30111B);
      case 'السماوي الكهربائي':
        return const Color(0xFF0D2933);
      case 'الغروب البرتقالي':
        return const Color(0xFF30170C);
      default:
        return const Color(0xFF14112B);
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

  String _channelFilter =
      "الكل"; // "الكل", "القنوات العربية فقط", "القنوات الأجنبية فقط"
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
    if (_sessionUnlockedCategories.contains(categoryName)) {
      return false;
    }
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

  // ==========================================
  // أنظمة الحماية المتطورة (Security & Anti-Sniffing)
  // ==========================================
  static const _securityChannel = MethodChannel('com.mahmoud.iptv/security');
  bool _snifferDetected = false;
  bool get snifferDetected => _snifferDetected;

  static const int APP_VERSION_CODE = 212;
  String _currentVersionStr = "2.2.12";
  int _currentVersionCode = 212;

  bool _isVersionBlocked = false;
  String _remoteBlockMessage =
      "🚨 تحديث إجباري مطلوب فوراً 🚨\n\nلقد تم إيقاف هذا الإصدار القديم نهائياً لدواعي صيانة وتحديث الأمان. يرجى تنزيل الإصدار الأخير للاستمرار في مشاهدة القنوات والاشتراكات. شكراً لكم!";
  String get remoteBlockMessage => _remoteBlockMessage;
  bool get isVersionBlocked => _isVersionBlocked;

  bool _vpnDetected = false;
  bool get vpnDetected => _vpnDetected;

  String _globalProxy = "";
  String get globalProxy => _globalProxy;

  // New additions: Announcement & Security remote override controls
  String _announcementText = "";
  String get announcementText => _announcementText;
  bool _disableVpnCheck = false;
  bool _disableSnifferCheck = false;

  // New addition: Recently Played/Continue Watching
  List<PlaylistItem> _recentlyPlayed = [];
  List<PlaylistItem> get recentlyPlayed => _recentlyPlayed;

  void addToRecentlyPlayed(PlaylistItem stream) async {
    _recentlyPlayed.removeWhere((item) => item.streamId == stream.streamId);
    _recentlyPlayed.insert(0, stream);
    if (_recentlyPlayed.length > 10) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 10);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          _recentlyPlayed.map((item) => item.toJson()).toList();
      await prefs.setString('recently_played_streams', jsonEncode(jsonList));
    } catch (_) {}
  }

  void loadRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('recently_played_streams');
      if (savedStr != null) {
        final List decoded = jsonDecode(savedStr);
        _recentlyPlayed =
            decoded.map((item) => PlaylistItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ==========================================

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
      final List<String> adultKeywords = [
        "+18",
        "18+",
        "ADULT",
        "XXX",
        "PORN",
        "SEX",
        "REDLIGHT",
        "FORBIDDEN",
        "ع للكبار",
        "للكبار",
        "X-RATED",
        "BLUE",
        "PENTHOUSE",
        "PLAYBOY",
        "HUSTLER",
        "EGOIST",
        "VENUS",
        "CANDY",
        "NIGHT",
        "EROTIC"
      ];
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
    if (_activationDurationHours < 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _activationTime + (_activationDurationHours * 3600000);
    return now > expiresAt;
  }

  String get expirationDateFormatted {
    if (_activationDurationHours < 0) return "مدى الحياة";
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        _activationTime + (_activationDurationHours * 3600000));
    return "${expiresAt.day}/${expiresAt.month}/${expiresAt.year}";
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // تشغيل نظام الحماية بشكل دوري لضمان عدم تشغيل VPN في الخلفية لاحقاً
    _checkVpnAndProxyStatus();
    checkSecurity();
    checkRemoteBlocking();
    Timer.periodic(const Duration(seconds: 15), (_) {
      _checkVpnAndProxyStatus();
      checkSecurity();
      checkRemoteBlocking();
    });

    final prefs = await SharedPreferences.getInstance();

    // التحقق من تلاعب أو تغيير اسم الحزمة / التطبيق
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersionStr = packageInfo.version;
      _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 212;
      final nameClean = packageInfo.appName.toLowerCase().replaceAll(' ', '');
      if (!nameClean.contains("livefootball") &&
          !nameClean.contains("livestrempro")) {
        // في حال تغيير اسم التطبيق يمكن إيقافه
        // _isVersionBlocked = true;
      }
    } catch (_) {}

    final savedFavs = prefs.getStringList('favorites');
    if (savedFavs != null) {
      _favorites = savedFavs;
    }
    loadRecentlyPlayed();

    final playlistsJson = prefs.getString('saved_playlists');
    if (playlistsJson != null) {
      try {
        final List decoded = json.decode(playlistsJson);
        _savedPlaylists =
            decoded.map((item) => UserPlaylist.fromJson(item)).toList();
      } catch (_) {}
    }

    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _showMoviesSeries = prefs.getBool('filter_show_movies_series') ?? true;
    _channelFilter = prefs.getString('channel_filter') ?? "الكل";
    _parentalPin = prefs.getString('parental_pin') ?? "";
    _lockedCategories = prefs.getStringList('locked_categories') ?? [];
    _activationCode = prefs.getString('active_code') ?? "";
    _activationTime = prefs.getInt('active_code_activated_at') ?? 0;
    _activationDurationHours = prefs.getInt('active_code_duration_hours') ?? -1;
    _subscriptionType = prefs.getString('active_code_sub_name') ?? "";
    _blockAdultContent = prefs.getBool('block_adult_content') ?? true;
    _appLanguage = prefs.getString('app_language') ?? 'العربية';
    _premiumTheme = prefs.getString('premium_theme') ?? 'البنفسجي الملكي';
    _profileName = prefs.getString('profile_name') ?? 'Premium User';
    _profileLogo = prefs.getString('profile_logo') ?? 'play';
    _profileImagePath = prefs.getString('profile_image_path') ?? '';
    _tvBoxFocusEnabled = prefs.getBool('tv_box_focus_enabled') ?? true;

    // تشغيل فحوصات الأمان النشطة ضد الهندسة العكسية
    await runActiveSecurityChecks();

    if (_activationCode.trim() == "69743190") {
      _isVersionBlocked = true;
    }

    if (_isLoggedIn && _savedPlaylists.isNotEmpty && _isSecured) {
      _activePlaylistId = _savedPlaylists.first.id;
      loadPlaylistStreams(_activePlaylistId!);
    }

    // تفعيل إعدادات بروكسي الحماية الصارمة
    HttpOverrides.global = MyHttpOverrides("");

    _isLoading = false;
    notifyListeners();
  }

    Future<void> runActiveSecurityChecks() async {
    try {
      await checkSecurity();
      if (_snifferDetected) {
        _isSecured = false;
        _securityMessage = "تم كشف برنامج التقاط حزم أو بيئة تشغيل غير آمنة! (Sniffer Detected)";
        notifyListeners();
        return;
      }
      if (Platform.isAndroid) {
        final List<String> rootPaths = [
          "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su",
          "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su",
          "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su", "/system/xbin/daemonsu"
        ];
        for (final path in rootPaths) {
          if (File(path).existsSync()) {
            _isSecured = false;
            _securityMessage = "تم كشف صلاحيات الروت (Root Access Detected). كإجراء أمان، تم إيقاف عمل التطبيق.";
            notifyListeners();
            return;
          }
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // دوال الحماية وفحص الشبكة (Anti-Proxy, VPN, Canary)
  // ==========================================

  static bool isVersionLowerThan(String versionA, String versionB) {
    try {
      final cleanA = versionA.toLowerCase().replaceAll('v', '').trim();
      final cleanB = versionB.toLowerCase().replaceAll('v', '').trim();

      final partsA =
          cleanA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final partsB =
          cleanB.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength =
          partsA.length > partsB.length ? partsA.length : partsB.length;
      for (int i = 0; i < maxLength; i++) {
        final valA = i < partsA.length ? partsA[i] : 0;
        final valB = i < partsB.length ? partsB[i] : 0;
        if (valA < valB) return true;
        if (valA > valB) return false;
      }
    } catch (_) {}
    return false;
  }

  bool isOutdatedVersion(String versionStr, int versionCode) {
    if (versionCode > 0) {
      if (versionCode < 211) {
        return true;
      } else if (versionCode >= 211) {
        return false;
      }
    }
    return isVersionLowerThan(versionStr, "2.2.11");
  }

  Future<void> checkRemoteBlocking() async {
    try {
      final configRes = await http
          .get(Uri.parse(
              "https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}"))
          .timeout(const Duration(seconds: 5));
      if (configRes.statusCode == 200) {
        final Map<String, dynamic> configData = json.decode(configRes.body);
        final updateData = configData['update'];
        if (updateData is Map) {
          _latestVersion =
              updateData['latest_version']?.toString() ?? _latestVersion;
          _updateUrl = updateData['apk_url']?.toString() ?? _updateUrl;
          _updateMessage =
              updateData['update_message']?.toString() ?? _updateMessage;
          _updateAvailable = _latestVersion.isNotEmpty &&
              _updateUrl.isNotEmpty &&
              isVersionLowerThan(_currentVersionStr, _latestVersion);
        }

        Map<String, dynamic>? blockData;
        if (configData.containsKey('blocking')) {
          blockData = Map<String, dynamic>.from(configData['blocking']);
        }

        // Parse remote announcements & security overrides dynamically
        if (configData.containsKey('announcement')) {
          final String newAnn = configData['announcement'].toString();
          if (_announcementText != newAnn) {
            _announcementText = newAnn;
            notifyListeners();
          }
        }

        final newDisableVpn = configData['disable_vpn_check'] == true;
        final newDisableSniffer = configData['disable_sniffer_check'] == true;
        if (_disableVpnCheck != newDisableVpn ||
            _disableSnifferCheck != newDisableSniffer) {
          _disableVpnCheck = newDisableVpn;
          _disableSnifferCheck = newDisableSniffer;
          if (_disableVpnCheck) _vpnDetected = false;
          if (_disableSnifferCheck) _snifferDetected = false;
          notifyListeners();
        }

        if (blockData != null) {
          bool isBlocked = false;

          if (blockData.containsKey('blocked_version_codes')) {
            final List codes = blockData['blocked_version_codes'] as List;
            if (codes.contains(_currentVersionCode)) {
              isBlocked = true;
            }
          }
          if (blockData.containsKey('min_version_code')) {
            final int minVer =
                int.tryParse(blockData['min_version_code'].toString()) ?? 0;
            if (_currentVersionCode < minVer) {
              isBlocked = true;
            }
          }

          // Force block any version lower than 2.2.11 (outdated versions)
          if (isOutdatedVersion(_currentVersionStr, _currentVersionCode)) {
            isBlocked = true;
            _remoteBlockMessage =
                "🚨 تم إيقاف هذا الإصدار القديم نهائياً لدواعي الأمان والتشغيل.\nيرجى التحديث إلى الإصدار 2.2.11 أو أعلى للاستمرار.";
          }

          if (blockData.containsKey('block_message') &&
              !isOutdatedVersion(_currentVersionStr, _currentVersionCode)) {
            _remoteBlockMessage = blockData['block_message'].toString();
          }

          if (_isVersionBlocked != isBlocked) {
            _isVersionBlocked = isBlocked;
            notifyListeners();
          }
        }

        await _validateActiveSubscription();
      }
    } catch (_) {
      debugPrint('Remote block check failed');
    }
  }

  DateTime? _lastSubscriptionValidationAt;
  bool _isSubscriptionValidationInProgress = false;

  Future<void> _validateActiveSubscription() async {
    if (!_isLoggedIn ||
        _activationCode.isEmpty ||
        _isSubscriptionValidationInProgress) {
      return;
    }

    final now = DateTime.now();
    if (_lastSubscriptionValidationAt != null &&
        now.difference(_lastSubscriptionValidationAt!) <
            const Duration(minutes: 5)) {
      return;
    }

    _isSubscriptionValidationInProgress = true;
    _lastSubscriptionValidationAt = now;
    try {
      final deviceId = await _getDeviceId();
      final response = await http
          .post(
            Uri.parse(
                'https://iptv-subscription-api.tvkora56.workers.dev/v1/login'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'code': _activationCode,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 401 || response.statusCode == 403) {
        lastError = 'هذا الاشتراك لم يعد صالحاً أو تم تجاوز حد الأجهزة';
        await logout();
        notifyListeners();
      }
    } catch (_) {
      // لا نلغي جلسة المستخدم عند انقطاع مؤقت في الإنترنت.
    } finally {
      _isSubscriptionValidationInProgress = false;
    }
  }

  Future<void> checkSecurity() async {
    if (_disableSnifferCheck && _disableVpnCheck) {
      if (_snifferDetected || _vpnDetected) {
        _snifferDetected = false;
        _vpnDetected = false;
        notifyListeners();
      }
      return;
    }
    try {
      // فحص أمني فائق القوة عبر الجافا (Android) لوقف التطبيق فورا إذا تم اكتشاف تعديل أو بيئة مشبوهة
      final Map? result =
          await _securityChannel.invokeMapMethod('checkSecurity');
      if (result != null) {
        final shouldBlock = _disableSnifferCheck
            ? false
            : (result['shouldBlock'] == true ||
                result['snifferInstalled'] == true);
        final vpnActive =
            _disableVpnCheck ? false : result['vpnActive'] == true;
        final proxyActive =
            _disableVpnCheck ? false : result['proxyActive'] == true;

        bool updated = false;
        if (_snifferDetected != shouldBlock) {
          _snifferDetected = shouldBlock;
          updated = true;
        }
        if (_vpnDetected != (vpnActive || proxyActive)) {
          _vpnDetected = vpnActive || proxyActive;
          updated = true;
        }
        if (updated) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Security channel unavailable");
    }
  }

  Future<void> _checkVpnAndProxyStatus() async {
    try {
      // فحص أمني فائق شامل لكافة القنوات (نظام أندرويد + شبكة Dart)
      await checkSecurity();

      if (_disableVpnCheck && _disableSnifferCheck) {
        if (_vpnDetected || _snifferDetected) {
          _vpnDetected = false;
          _snifferDetected = false;
          notifyListeners();
        }
        return;
      }

      bool detected = (_disableVpnCheck ? false : _vpnDetected) ||
          (_disableSnifferCheck ? false : _snifferDetected);

      if (!detected && !_disableVpnCheck) {
        // 1. فحص إعدادات البروكسي (Proxy) لمنع برامج مثل Charles Proxy أو Reqable أو HttpCanary
        try {
          final systemProxy = HttpClient.findProxyFromEnvironment(
              Uri.parse("https://google.com"));
          if (systemProxy != "DIRECT" && systemProxy.trim().isNotEmpty) {
            detected = true;
          }
        } catch (_) {}
      }

      if (!detected && !_disableVpnCheck) {
        // 2. فحص واجهات الشبكة الفعالة للبحث عن VPN أو أدوات التقاط الحزم (Packet Sniffers)
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.any,
        );
        for (var interface in interfaces) {
          final name = interface.name.toLowerCase();
          if (name.contains('tun') ||
              name.contains('ppp') ||
              name.contains('vpn') ||
              name.contains('ipsec') ||
              name.contains('wireguard') ||
              name.contains('wg0') ||
              name.contains('wg1') ||
              name.contains('tap') ||
              name.contains('pcap')) {
            detected = true;
            break;
          }
        }
      }

      if (_vpnDetected != detected) {
        _vpnDetected = detected;
        notifyListeners();
      }
    } catch (_) {
      _vpnDetected = false;
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_unknown";
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    String? localId = prefs.getString('persistent_client_device_id');
    if (localId == null) {
      localId =
          "device_${DateTime.now().millisecondsSinceEpoch}_${(100000 + (DateTime.now().microsecond % 900000))}";
      await prefs.setString('persistent_client_device_id', localId);
    }
    return localId;
  }

  // ==========================================

  String _appName = "Live Football";
  String get appName => _appName;

  bool _updateAvailable = false;
  bool get updateAvailable => _updateAvailable;

  String _latestVersion = "";
  String get latestVersion => _latestVersion;

  String _updateUrl = "";
  String get updateUrl => _updateUrl;

  String _updateMessage = "";
  String get updateMessage => _updateMessage;

    Future<bool> loginWithCode(String code) async {
    lastError = null;
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      lastError = 'رمز الدخول فارغ';
      return false;
    }
    await _checkVpnAndProxyStatus();
    if (_vpnDetected) {
      lastError = 'يرجى إيقاف الـ VPN أو البروكسي قبل المتابعة';
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final deviceId = await _getDeviceId();
      final response = await http
          .post(
            Uri.parse('https://iptv-subscription-api.tvkora56.workers.dev/v1/login'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'code': cleanCode,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        lastError = 'رمز الدخول غير صالح أو غير مصرح به';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final data = json.decode(response.body);
      if (data['ok'] != true) {
        lastError = data['message'] ?? 'تعذر الاتصال. تأكد من الإنترنت وصحة الاشتراك';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final userData = data['user'];
      _activationCode = userData['code'] ?? cleanCode;
      _subscriptionType = userData['server_type'] ?? 'premium';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_code', _activationCode);
      await prefs.setString('subscription_type', _subscriptionType);
      await prefs.setBool('is_logged_in', true);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      await checkRemoteBlocking();
      final list = UserPlaylist(
        id: 'main_subscription',
        name: _appName,
        type: userData['server_type'] ?? 'xtream',
        host: userData['host'],
        username: userData['username'],
        password: userData['password'],
      );
      if (userData['server_type'] == 'stalker') {
        _globalUserAgent = "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3";
      }
      _savedPlaylists = [list];
      _activePlaylistId = list.id;
      await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((p) => p.toJson()).toList()));
      await loadPlaylistStreams(list.id);
      return true;
    } on TimeoutException {
      lastError = 'انتهت مهلة الاتصال. تحقق من الإنترنت ثم أعد المحاولة';
    } catch (e) {
      lastError = 'خطأ في الاتصال: ${e.toString()}';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

List<PlaylistItem> _parseStalkerChannels(
    dynamic payload,
    List<Map<String, String>> categories, {
    String itemType = "stalker",
  }) {
    final dynamic js = payload is Map ? payload['js'] : null;
    final List<dynamic> items = js is List
        ? List<dynamic>.from(js)
        : (js is Map && js['data'] is List
            ? List<dynamic>.from(js['data'] as List)
            : <dynamic>[]);

    return items.whereType<Map>().map<PlaylistItem>((item) {
      final catId = item['tv_genre_id']?.toString() ?? '';
      final category = categories.firstWhere(
        (entry) => entry['category_id'] == catId,
        orElse: () => const <String, String>{},
      );
      return PlaylistItem(
        num: int.tryParse(item['number']?.toString() ?? '0'),
        streamId: 'live_${item['id']?.toString() ?? ''}',
        name: item['name']?.toString() ?? '',
        streamIcon: item['logo']?.toString() ?? '',
        categoryId: catId,
        categoryName: category.isNotEmpty
            ? (category['category_name'] ?? 'بث مباشر')
            : 'بث مباشر',
        url: item['cmd']?.toString() ?? '',
        type: 'stalker',
      );
    }).toList();
  }

  Future<void> _loadFullStalkerCatalogueInBackground({
    required String playlistId,
    required String host,
    required Map<String, String> headers,
    required List<Map<String, String>> categories,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$host/server/load.php?type=itv&action=get_all_channels&JsHttpRequest=1-xml',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200 ||
          _activePlaylistId != playlistId ||
          !_isLoggedIn) {
        return;
      }

      final fullCatalogue = _parseStalkerChannels(
        json.decode(response.body),
        categories,
      );
      if (fullCatalogue.isEmpty) return;

      _allStreams = FilterService.interceptAndFilterStreams(
        fullCatalogue,
        blockAdult: _blockAdultContent,
        channelFilter: _channelFilter,
      );
      _applyFilters();
      notifyListeners();
    } catch (_) {
      // تبقى الصفحة السريعة متاحة حتى لو تأخر الخادم في إرسال القائمة الكاملة.
    }
  }

  Future<String> _getStalkerToken(String host, String mac) async {
    try {
      final handshakeUrl = '$host/server/load.php?type=stb&action=handshake&JsHttpRequest=1-xml';
      final response = await http.get(Uri.parse(handshakeUrl), headers: {'Cookie': 'mac=$mac', 'User-Agent': 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3'}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['js']['token']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<void> _loginStalker(String host, String mac) async {
    try {
      _stalkerToken = await _getStalkerToken(host, mac);
      final loginUrl = '$host/server/load.php?type=stb&action=get_profile&JsHttpRequest=1-xml';
      await http.get(Uri.parse(loginUrl), headers: {
        'Cookie': 'mac=$mac',
        'Authorization': 'Bearer $_stalkerToken',
        'User-Agent': 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3'
      }).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> loadPlaylistStreams(String id) async {
    _isFetchingData = true;
    notifyListeners();

    final playlist = _savedPlaylists.firstWhere((p) => p.id == id,
        orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) {
      _isFetchingData = false;
      notifyListeners();
      return;
    }
    _activePlaylistId = id;

    if (playlist.type == 'custom') {
      try {
        final url = Uri.parse(
            "https://raw.githubusercontent.com/mahmoudhwhwhwh/live-stream-premium/main/Main_menu.json?t=${DateTime.now().millisecondsSinceEpoch}");
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final List<dynamic> data = json.decode(res.body);
          List<Map<String, String>> tempCats = [];
          List<PlaylistItem> tempStreams = [];
          Set<String> catNames = {};

          for (int i = 0; i < data.length; i++) {
            final item = data[i];
            final catName = item['category_name']?.toString() ?? 'Other';
            final catId = item['category_id']?.toString() ?? catName;
            if (!catNames.contains(catId)) {
              catNames.add(catId);
              tempCats.add({
                'category_id': catId,
                'category_name': catName,
                'parent_id': '0'
              });
            }

            Map<String, String>? clearKeys;
            if (item['keys'] != null && item['keys'] is Map) {
              clearKeys = (item['keys'] as Map)
                  .map((k, v) => MapEntry(k.toString(), v.toString()));
            } else if (item['clearKeys'] != null && item['clearKeys'] is Map) {
              clearKeys = (item['clearKeys'] as Map)
                  .map((k, v) => MapEntry(k.toString(), v.toString()));
            }

            tempStreams.add(PlaylistItem(
              num: i,
              streamId: "custom_$i",
              name: item['name']?.toString() ?? '',
              streamIcon: item['icon']?.toString() ?? '',
              categoryId: catId,
              categoryName: catName,
              url: item['url']?.toString() ?? '',
              type: 'live',
              customUserAgent: item['user_agent']?.toString() ??
                  item['customUserAgent']?.toString(),
              customReferer: item['referer']?.toString() ??
                  item['customReferer']?.toString(),
              clearKeys: clearKeys,
            ));
          }

          // اعتراض وتصفية من المصدر المركزي
          _liveCategories = FilterService.interceptAndFilterCategories(tempCats,
              blockAdult: _blockAdultContent);
          _allStreams = FilterService.interceptAndFilterStreams(tempStreams,
              blockAdult: _blockAdultContent, channelFilter: _channelFilter);
          _movieCategories = [];
          _seriesCategories = [];

          _applyFilters();
        }
      } catch (e) {
        debugPrint("Configured streams could not be loaded");
      }
      _isFetchingData = false;
      notifyListeners();
      return;
    }

    try {
      final host = (playlist.host ?? '').trim();
      final user = (playlist.username ?? '').trim();
      final pass = (playlist.password ?? '').trim();

            if (playlist.type == 'stalker' && host.isNotEmpty && user.isNotEmpty) {
        await _loginStalker(host, user);
        final headers = <String, String>{
          'Cookie': 'mac=$user',
          'Authorization': 'Bearer $_stalkerToken',
          'User-Agent': 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3',
        };
        
        // Fetch Live Categories
        final liveCatsRes = await http.get(Uri.parse('$host/server/load.php?type=itv&action=get_genres&JsHttpRequest=1-xml'), headers: headers).timeout(const Duration(seconds: 15));
        List<Map<String, String>> tempLiveCats = [];
        if (liveCatsRes.statusCode == 200) {
          final data = json.decode(liveCatsRes.body);
          if (data['js'] is List) {
            for (final item in data['js']) {
              tempLiveCats.add({'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? ''});
            }
          }
        }
        _liveCategories = FilterService.interceptAndFilterCategories(tempLiveCats, blockAdult: _blockAdultContent);

        // Fetch VOD Categories
        final vodCatsRes = await http.get(Uri.parse('$host/server/load.php?type=vod&action=get_categories&JsHttpRequest=1-xml'), headers: headers).timeout(const Duration(seconds: 15));
        if (vodCatsRes.statusCode == 200) {
          final data = json.decode(vodCatsRes.body);
          List<Map<String, String>> tempVodCats = [];
          if (data['js'] is List) {
            for (final item in data['js']) {
              tempVodCats.add({'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? ''});
            }
          }
          _movieCategories = FilterService.interceptAndFilterCategories(tempVodCats, blockAdult: _blockAdultContent);
        }

        // Fetch Series Categories
        final seriesCatsRes = await http.get(Uri.parse('$host/server/load.php?type=series&action=get_categories&JsHttpRequest=1-xml'), headers: headers).timeout(const Duration(seconds: 15));
        if (seriesCatsRes.statusCode == 200) {
          final data = json.decode(seriesCatsRes.body);
          List<Map<String, String>> tempSeriesCats = [];
          if (data['js'] is List) {
            for (final item in data['js']) {
              tempSeriesCats.add({'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? ''});
            }
          }
          _seriesCategories = FilterService.interceptAndFilterCategories(tempSeriesCats, blockAdult: _blockAdultContent);
        }

        // Fetch All Streams (Live, VOD, Series)
        List<PlaylistItem> allStalkerItems = [];
        
        // 1. Initial Live Page
        try {
          final firstPageRes = await http.get(Uri.parse('$host/server/load.php?type=itv&action=get_ordered_list&genre=0&force_ch_link_check=0&p=1&JsHttpRequest=1-xml'), headers: headers).timeout(const Duration(seconds: 15));
          if (firstPageRes.statusCode == 200) {
            allStalkerItems.addAll(_parseStalkerChannels(json.decode(firstPageRes.body), _liveCategories, itemType: 'stalker'));
          }
        } catch (_) {}

        // 2. Initial VOD (Movies) Page
        try {
          final vodRes = await http.get(Uri.parse('$host/server/load.php?type=vod&action=get_vod_list&p=1&JsHttpRequest=1-xml'), headers: headers).timeout(const Duration(seconds: 15));
          if (vodRes.statusCode == 200) {
            allStalkerItems.addAll(_parseStalkerChannels(json.decode(vodRes.body), _movieCategories, itemType: 'stalker_movie'));
          }
        } catch (_) {}

        // 3. Initial Series Page
        try {
          final seriesRes = await http.get(Uri.parse('$host/server/load.php?type=series&action=get_series_list&p=1&JsHttpRequest=1-xml'), headers: headers).timeout(const Duration(seconds: 15));
          if (seriesRes.statusCode == 200) {
            allStalkerItems.addAll(_parseStalkerChannels(json.decode(seriesRes.body), _seriesCategories, itemType: 'stalker_series'));
          }
        } catch (_) {}

        _allStreams = FilterService.interceptAndFilterStreams(allStalkerItems, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
        _applyFilters();
        _isFetchingData = false;
        notifyListeners();

        // Background full load
        _loadFullStalkerCatalogueInBackground(playlistId: id, host: host, headers: headers, categories: List<Map<String, String>>.from(_liveCategories));
        return;
      } else if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
        final liveCatsRes = await http
            .get(Uri.parse(
                "$host/player_api.php?username=$user&password=$pass&action=get_live_categories"))
            .timeout(const Duration(seconds: 15));
        final liveStreamsRes = await http
            .get(Uri.parse(
                "$host/player_api.php?username=$user&password=$pass&action=get_live_streams"))
            .timeout(const Duration(seconds: 25));

        List<Map<String, String>> tempLiveCats = [];
        if (liveCatsRes.statusCode == 200) {
          final List decoded = json.decode(liveCatsRes.body);
          tempLiveCats = decoded
              .map<Map<String, String>>((item) => {
                    'category_id': item['category_id']?.toString() ?? '',
                    'category_name': item['category_name']?.toString() ?? '',
                  })
              .toList();
        }

        // اعتراض وتصفية فئات البث المباشر
        tempLiveCats = FilterService.interceptAndFilterCategories(tempLiveCats,
            blockAdult: _blockAdultContent);

        List<PlaylistItem> tempStreams = [];
        if (liveStreamsRes.statusCode == 200) {
          final List decoded = json.decode(liveStreamsRes.body);
          for (final item in decoded) {
            final catId = item['category_id']?.toString() ?? '';
            final cat = tempLiveCats
                .firstWhere((c) => c['category_id'] == catId, orElse: () => {});
            final catName = cat.isNotEmpty ? cat['category_name']! : 'بث مباشر';
            final streamId = item['stream_id']?.toString() ?? '';
            tempStreams.add(PlaylistItem(
              num: item['num'] is int ? item['num'] : null,
              streamId: "live_$streamId",
              name: item['name']?.toString() ?? '',
              streamIcon: item['stream_icon']?.toString() ?? '',
              categoryId: catId,
              categoryName: catName,
              url: "$host/live/$user/$pass/$streamId.ts",
              type: "live",
            ));
          }
        }

        // اعتراض وتصفية قنوات البث المباشر
        _allStreams = FilterService.interceptAndFilterStreams(tempStreams,
            blockAdult: _blockAdultContent, channelFilter: _channelFilter);
        _liveCategories = tempLiveCats;

        // Fetch VOD and Series
        http
            .get(Uri.parse(
                "$host/player_api.php?username=$user&password=$pass&action=get_vod_categories"))
            .then((vodCatsRes) {
          if (vodCatsRes.statusCode == 200) {
            final List decoded = json.decode(vodCatsRes.body);
            final List<Map<String, String>> parsedCats = decoded
                .map<Map<String, String>>((item) => {
                      'category_id': item['category_id']?.toString() ?? '',
                      'category_name': item['category_name']?.toString() ?? '',
                    })
                .toList();
            // اعتراض وتصفية فئات الأفلام
            _movieCategories = FilterService.interceptAndFilterCategories(
                parsedCats,
                blockAdult: _blockAdultContent);
          }
          http
              .get(Uri.parse(
                  "$host/player_api.php?username=$user&password=$pass&action=get_vod_streams"))
              .then((vodStreamsRes) {
            if (vodStreamsRes.statusCode == 200) {
              final List decoded = json.decode(vodStreamsRes.body);
              List<PlaylistItem> tempMovies = [];
              for (final item in decoded) {
                final catId = item['category_id']?.toString() ?? '';
                final cat = _movieCategories.firstWhere(
                    (c) => c['category_id'] == catId,
                    orElse: () => {});
                final catName =
                    cat.isNotEmpty ? cat['category_name']! : 'أفلام';
                final streamId = item['stream_id']?.toString() ?? '';
                final container =
                    item['container_extension']?.toString() ?? 'mp4';
                tempMovies.add(PlaylistItem(
                  num: item['num'] is int ? item['num'] : null,
                  streamId: "movie_$streamId",
                  name: item['name']?.toString() ?? '',
                  streamIcon: item['stream_icon']?.toString() ?? '',
                  categoryId: catId,
                  categoryName: catName,
                  url: "$host/movie/$user/$pass/$streamId.$container",
                  type: "movie",
                ));
              }
              // اعتراض وتصفية قنوات الأفلام
              final filteredMovies = FilterService.interceptAndFilterStreams(
                  tempMovies,
                  blockAdult: _blockAdultContent,
                  channelFilter: _channelFilter);
              _allStreams.addAll(filteredMovies);
            }
            _applyFilters();
            notifyListeners();
          });
        });

        http
            .get(Uri.parse(
                "$host/player_api.php?username=$user&password=$pass&action=get_series_categories"))
            .then((seriesCatsRes) {
          if (seriesCatsRes.statusCode == 200) {
            final List decoded = json.decode(seriesCatsRes.body);
            final List<Map<String, String>> parsedCats = decoded
                .map<Map<String, String>>((item) => {
                      'category_id': item['category_id']?.toString() ?? '',
                      'category_name': item['category_name']?.toString() ?? '',
                    })
                .toList();
            // اعتراض وتصفية فئات المسلسلات
            _seriesCategories = FilterService.interceptAndFilterCategories(
                parsedCats,
                blockAdult: _blockAdultContent);
          }
          http
              .get(Uri.parse(
                  "$host/player_api.php?username=$user&password=$pass&action=get_series"))
              .then((seriesRes) {
            if (seriesRes.statusCode == 200) {
              final List decoded = json.decode(seriesRes.body);
              List<PlaylistItem> tempSeries = [];
              for (final item in decoded) {
                final catId = item['category_id']?.toString() ?? '';
                final cat = _seriesCategories.firstWhere(
                    (c) => c['category_id'] == catId,
                    orElse: () => {});
                final catName =
                    cat.isNotEmpty ? cat['category_name']! : 'مسلسلات';
                final streamId = item['series_id']?.toString() ?? '';
                tempSeries.add(PlaylistItem(
                  num: item['num'] is int ? item['num'] : null,
                  streamId: "series_$streamId",
                  name: item['name']?.toString() ?? '',
                  streamIcon: item['cover']?.toString() ?? '',
                  categoryId: catId,
                  categoryName: catName,
                  url: "$host/series/$user/$pass/$streamId.mp4",
                  type: "series",
                ));
              }
              // اعتراض وتصفية قنوات المسلسلات
              final filteredSeries = FilterService.interceptAndFilterStreams(
                  tempSeries,
                  blockAdult: _blockAdultContent,
                  channelFilter: _channelFilter);
              _allStreams.addAll(filteredSeries);
            }
            _applyFilters();
            notifyListeners();
          });
        });
      }
    } catch (e) {
      debugPrint("Streams could not be loaded");
    }

    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
  }

  void setTab(String tab) {
    _activeTab = tab;
    _selectedCategory = "all";
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _applyFilters();
      notifyListeners();
      return;
    }
    // يمنع إعادة فلترة آلاف العناصر عند كل حرف أثناء الكتابة.
    _searchDebounce = Timer(const Duration(milliseconds: 130), () {
      _applyFilters();
      notifyListeners();
    });
  }

  bool isArabicStream(PlaylistItem stream) {
    return FilterService.isArabicStream(stream.name, stream.categoryName);
  }

  bool isSportsStream(PlaylistItem stream) {
    return FilterService.isSportsStream(stream.name, stream.categoryName);
  }

  bool isNewsStream(PlaylistItem stream) {
    return FilterService.isNewsStream(stream.name, stream.categoryName);
  }

  bool isAlwanStream(PlaylistItem stream) {
    return FilterService.isAlwanStream(stream.name, stream.categoryName);
  }

  bool isAdultStream(PlaylistItem stream) {
    return FilterService.isAdultStream(stream.name, stream.categoryName);
  }

  void _applyFilters() {
    if (!_isSecured) {
      _filteredStreams = [];
      return;
    }

    _filteredStreams = _allStreams.where((stream) {
      // Filter out movies and series if configured to be hidden
      if (!_showMoviesSeries) {
        if (stream.type == "movie" ||
            stream.type == "series" ||
            stream.type == "stalker_movie" ||
            stream.type == "stalker_series") {
          return false;
        }
      }

      // Filter out 18+ content if enabled
      if (_blockAdultContent && isAdultStream(stream)) {
        return false;
      }

      // Filter Arabic / Foreign channels / Sports / News / Alwan
      if (_channelFilter != "الكل") {
        final isArab = isArabicStream(stream);
        if (_channelFilter == "القنوات العربية فقط") {
          if (!isArab) return false;
        } else if (_channelFilter == "القنوات الأجنبية فقط") {
          if (isArab) return false;
        } else if (_channelFilter == "قنوات الرياضة فقط") {
          if (!isSportsStream(stream)) return false;
        } else if (_channelFilter == "القنوات الرياضية العربية فقط") {
          if (!isSportsStream(stream) || !isArab) return false;
        } else if (_channelFilter == "القنوات الإخبارية فقط") {
          if (!isNewsStream(stream)) return false;
        } else if (_channelFilter == "قنوات Alwan فقط") {
          if (!isAlwanStream(stream)) return false;
        }
      }

      if (_activeTab != "favorites") {
        if (_activeTab == "live") {
          if (stream.type != "live" && stream.type != "stalker") return false;
        } else {
          if (stream.type != _activeTab) return false;
        }
      }
      if (_activeTab == "favorites" && !_favorites.contains(stream.streamId))
        return false;
      if (_selectedCategory != "all" &&
          stream.categoryName != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty &&
          !stream.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        return false;
      return true;
    }).toList();
  }

  void selectStream(PlaylistItem item) {
    _currentStream = item;
    addToRecentlyPlayed(item);
    notifyListeners();
  }

  void zapChannel(bool next) {
    if (_currentStream == null || _filteredStreams.isEmpty) return;
    int currentIndex = _filteredStreams
        .indexWhere((s) => s.streamId == _currentStream!.streamId);
    if (currentIndex == -1) return;
    if (next) {
      if (currentIndex < _filteredStreams.length - 1) {
        _currentStream = _filteredStreams[currentIndex + 1];
      } else {
        _currentStream = _filteredStreams[0];
      }
    } else {
      if (currentIndex > 0) {
        _currentStream = _filteredStreams[currentIndex - 1];
      } else {
        _currentStream = _filteredStreams[_filteredStreams.length - 1];
      }
    }
    notifyListeners();
  }

  void toggleFavorite(String streamId) {
    if (_favorites.contains(streamId)) {
      _favorites.remove(streamId);
    } else {
      _favorites.add(streamId);
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('favorites', _favorites);
    });
    if (_activeTab == "favorites") {
      _applyFilters();
    }
    notifyListeners();
  }

  Future<void> setCategory(String category) async {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  Future<void> changeSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    // امسح الجلسة وبيانات المحتوى المرتبطة بالكود فقط، مع الاحتفاظ
    // باللغة والثيم وإعدادات المشغّل وملف الحساب الخاص بالمستخدم.
    for (final key in <String>[
      'active_code',
      'active_code_activated_at',
      'active_code_duration_hours',
      'active_code_sub_name',
      'app_name_cached',
      'saved_playlists',
      'is_logged_in',
      'show_welcome_after_login',
      'favorites',
      'recently_played_streams',
    ]) {
      await prefs.remove(key);
    }
    _isLoggedIn = false;
    _activationCode = '';
    _activationTime = 0;
    _activationDurationHours = -1;
    _subscriptionType = '';
    _savedPlaylists.clear();
    _allStreams.clear();
    _filteredStreams.clear();
    _liveCategories.clear();
    _movieCategories.clear();
    _seriesCategories.clear();
    _favorites.clear();
    _recentlyPlayed.clear();
    _currentStream = null;
    _activePlaylistId = null;
    _selectedCategory = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _savedPlaylists.clear();
    _allStreams.clear();
    _liveCategories.clear();
    _movieCategories.clear();
    _seriesCategories.clear();
    _activePlaylistId = null;
    notifyListeners();
  }
}
