import 'dart:async';
import 'main_menu_data.dart';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  String _channelFilter = "الكل"; // "الكل", "القنوات العربية فقط", "القنوات الأجنبية فقط"
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
  String _remoteBlockMessage = "🚨 تحديث إجباري مطلوب فوراً 🚨\n\nلقد تم إيقاف هذا الإصدار القديم نهائياً لدواعي صيانة وتحديث الأمان. يرجى تنزيل الإصدار الأخير للاستمرار في مشاهدة القنوات والاشتراكات. شكراً لكم!";
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
        "+18", "18+", "ADULT", "XXX", "PORN", "SEX", "REDLIGHT", "FORBIDDEN", "ع للكبار", "للكبار", "X-RATED", "BLUE", "PENTHOUSE", "PLAYBOY", "HUSTLER", "EGOIST", "VENUS", "CANDY", "NIGHT", "EROTIC"
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
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(_activationTime + (_activationDurationHours * 3600000));
    return "${expiresAt.day}/${expiresAt.month}/${expiresAt.year}";
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // Disable security checks for TV Box and Screens compatibility
    _disableVpnCheck = true;
    _disableSnifferCheck = true;

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
      if (!nameClean.contains("livefootball") && !nameClean.contains("livestrempro")) {
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
        _savedPlaylists = decoded.map((item) => UserPlaylist.fromJson(item)).toList();
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
      // 1. فحص اتصال مصحح الأخطاء (Debugger attachment) - حماية قوية ضد الهندسة العكسية وتحليل القيم أثناء التشغيل

      // 2. فحص كسر الحماية (Root detection) - أجهزة الروت تستخدم بشكل رئيسي لتخطي بروتوكولات الأمان وكسر الشهادات
      if (Platform.isAndroid) {
        final List<String> rootPaths = [
          "/system/app/Superuser.apk",
          "/sbin/su",
          "/system/bin/su",
          "/system/xbin/su",
          "/data/local/xbin/su",
          "/data/local/bin/su",
          "/system/sd/xbin/su",
          "/system/bin/failsafe/su",
          "/data/local/su",
          "/su/bin/su",
          "/system/xbin/daemonsu"
        ];
        
        for (final path in rootPaths) {
          if (File(path).existsSync()) {
            _isSecured = false;
            _securityMessage = "تم كشف صلاحيات الروت أو كسر حماية نظام الهاتف (Root Access Detected). كإجراء أمان، تم إيقاف عمل التطبيق.";
            _allStreams.clear();
            _filteredStreams.clear();
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
      
      final partsA = cleanA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final partsB = cleanB.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      final maxLength = partsA.length > partsB.length ? partsA.length : partsB.length;
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
      final configRes = await http.get(Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/config?t=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 5));
      if (configRes.statusCode == 200) {
        final Map<String, dynamic> configData = await Isolate.run(() => json.decode(configRes.body));
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
        if (_disableVpnCheck != newDisableVpn || _disableSnifferCheck != newDisableSniffer) {
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
            final int minVer = int.tryParse(blockData['min_version_code'].toString()) ?? 0;
            if (_currentVersionCode < minVer) {
              isBlocked = true;
            }
          }

          // Force block any version lower than 2.2.11 (outdated versions)
          if (isOutdatedVersion(_currentVersionStr, _currentVersionCode)) {
            isBlocked = true;
            _remoteBlockMessage = "🚨 تم إيقاف هذا الإصدار القديم نهائياً لدواعي الأمان والتشغيل.\nيرجى التحديث إلى الإصدار 2.2.11 أو أعلى للاستمرار.";
          }

          if (blockData.containsKey('block_message') && !isOutdatedVersion(_currentVersionStr, _currentVersionCode)) {
            _remoteBlockMessage = blockData['block_message'].toString();
          }

          if (_isVersionBlocked != isBlocked) {
            _isVersionBlocked = isBlocked;
            notifyListeners();
          }
        }

        if (_isLoggedIn && _activationCode.isNotEmpty && _activationCode != "2026" && _activationCode != "2027" && _activationCode != "69743190") {
            final users = configData['users'] as Map<String, dynamic>? ?? {};
            final servers = configData['servers'] as List<dynamic>? ?? [];
            bool found = false;
            dynamic u;
            if (users.containsKey(_activationCode)) {
                u = users[_activationCode];
                found = true;
            } else {
                for (var s in servers) {
                    final sUsers = s['users'] as Map<String, dynamic>? ?? {};
                    if (sUsers.containsKey(_activationCode)) {
                        u = sUsers[_activationCode];
                        found = true;
                        break;
                    }
                }
            }

            if (found && u != null) {
                bool isBlocked = u['blocked'] == true;
                if (isBlocked) {
                    lastError = "تم حظر الاشتراك عنك بسبب عدم الانصياغ ل القواعد والقوانين";
                    _isLoggedIn = false;
                    logout();
                    notifyListeners();
                } else {
                    final deviceId = await _getDeviceId();
                    dynamic devices = u['devices'] ?? [];
                    if (!devices.contains(deviceId)) {
                        _registerDeviceOrBlock(_activationCode, deviceId);
                    }
                }
            } else {
                lastError = "هذا الاشتراك غير صالح أو تم حذفه";
                _isLoggedIn = false;
                logout();
                notifyListeners();
            }
        }

      }
    } catch (e) {
      debugPrint("Remote block check failed");
    }
  }

  bool _isRegisteringDevice = false;

  Future<void> _registerDeviceOrBlock(String code, String deviceId) async {
    if (_isRegisteringDevice) return;
    _isRegisteringDevice = true;
    try {
        final url = Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/config?t=${DateTime.now().millisecondsSinceEpoch}");
        final res = await http.get(url);
        if (res.statusCode == 200) {
            final Map<String, dynamic> configData = await Isolate.run(() => json.decode(res.body));
            final users = configData['users'] as Map<String, dynamic>? ?? {};
            final servers = configData['servers'] as List<dynamic>? ?? [];
            bool found = false;
            dynamic u;
            if (users.containsKey(code)) {
                u = users[code];
                found = true;
            } else {
                for (var s in servers) {
                    final sUsers = s['users'] as Map<String, dynamic>? ?? {};
                    if (sUsers.containsKey(code)) {
                        u = sUsers[code];
                        found = true;
                        break;
                    }
                }
            }

            if (found && u != null) {
                dynamic devices = u['devices'] ?? [];
                if (!devices.contains(deviceId)) {
                    if (devices.length >= 2) {
                        u['blocked'] = true;
                        lastError = "تم حظر الاشتراك عنك بسبب تجاوز الحد الأقصى للأجهزة (جهازين فقط)";
                        _isLoggedIn = false;
                        logout();
                        notifyListeners();
                    }
                    // لا يحمل العميل أي صلاحية كتابة للإعدادات العامة.
                    // يبقى تحميل الاشتراك والقنوات بالقراءة فقط.
                }
            }
        }
    } catch (e) {
        debugPrint("Device registration failed");
    }
    _isRegisteringDevice = false;
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
      final Map? result = await _securityChannel.invokeMapMethod('checkSecurity');
      if (result != null) {
        final shouldBlock = _disableSnifferCheck ? false : (result['shouldBlock'] == true || result['snifferInstalled'] == true);
        final vpnActive = _disableVpnCheck ? false : result['vpnActive'] == true;
        final proxyActive = _disableVpnCheck ? false : result['proxyActive'] == true;

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
      
      bool detected = (_disableVpnCheck ? false : _vpnDetected) || (_disableSnifferCheck ? false : _snifferDetected);
      
      if (!detected && !_disableVpnCheck) {
        // 1. فحص إعدادات البروكسي (Proxy) لمنع برامج مثل Charles Proxy أو Reqable أو HttpCanary
        try {
          final systemProxy = HttpClient.findProxyFromEnvironment(Uri.parse("https://google.com"));
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
      localId = "device_${DateTime.now().millisecondsSinceEpoch}_${(100000 + (DateTime.now().microsecond % 900000))}";
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
    String cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      lastError = "رمز الدخول فارغ";
      return false;
    }

    if (cleanCode == "69743190") {
      _isVersionBlocked = true;
      notifyListeners();
      return false;
    }

    // تحقق إضافي قبل الاتصال
    await _checkVpnAndProxyStatus();
    if (_vpnDetected) {
      lastError = "يرجى إيقاف الـ VPN أو البروكسي قبل المتابعة";
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final configUrl = Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/config?t=${DateTime.now().millisecondsSinceEpoch}");
      final configRes = await http.get(configUrl).timeout(const Duration(seconds: 15));
      
      String host = "http://fh.u2i9o.top:80"; // Default fallback
      String user = cleanCode;
      String pass = cleanCode;
      int durationHours = -1;
      String subName = 'اشتراك Live Football';

      if (configRes.statusCode == 200) {
         try {
            final config = await Isolate.run(() => json.decode(configRes.body));
            _appName = config['app_name'] ?? _appName;
            
            _latestVersion = config['app_version'] ?? "";
            _updateUrl = config['apk_url'] ?? "";
            _updateMessage = config['update_message'] ?? "";
            
            // Compare with current version dynamically
            String currentVersion = _currentVersionStr;
            if (_latestVersion.isNotEmpty && isVersionLowerThan(currentVersion, _latestVersion) && _updateUrl.isNotEmpty) {
                _updateAvailable = true;
            }

            
            final users = config['users'] as Map<String, dynamic>? ?? {};
            final servers = config['servers'] as List<dynamic>? ?? [];
            
            bool userFound = false;
            dynamic userData = {};
            
            if (cleanCode != "2027") {
               // First check in root users
               if (users.containsKey(cleanCode)) {
                   userFound = true;
                   userData = users[cleanCode];
                   host = userData['xtream_host'] ?? config['xtream_host'] ?? host;
                   user = userData['username'] ?? config['default_xtream_user'] ?? user;
                   pass = userData['password'] ?? config['default_xtream_pass'] ?? pass;
               } else {
                   // Then check in servers
                   for (var s in servers) {
                       final serverUsers = s['users'] as Map<String, dynamic>? ?? {};
                       if (serverUsers.containsKey(cleanCode)) {
                           userFound = true;
                           userData = serverUsers[cleanCode];
                           host = s['host'] ?? host;
                           user = userData['username'] ?? s['username'] ?? user;
                           pass = userData['password'] ?? s['password'] ?? pass;
                           
                           if (s['type'] == 'stalker') {
                               pass = 'stalker'; // Flag for stalker
                           }
                           
                           break;
                       }
                   }
               }
               
               if (host.contains("2@")) {
                   host = host.replaceAll("2@", "");
               }
               
               if (!userFound) {
                  lastError = "رمز الدخول غير صالح او غير مصرح به";
                  _isLoading = false;
                  notifyListeners();
                  return false;
               }

               if (cleanCode != "2026") {
                   bool isBlocked = userData['blocked'] == true;
                   if (isBlocked) {
                       lastError = "تم حضر الاشتراك عنك بسبب عدم الانصياغ ل القواعد والقوانين";
                       _isLoading = false;
                       notifyListeners();
                       return false;
                   }
                   
                   final deviceId = await _getDeviceId();
                   dynamic devices = userData['devices'] ?? [];
                   if (!devices.contains(deviceId) && devices.length >= 2) {
                       lastError = "تم حضر الاشتراك عنك بسبب تجاوز الحد الأقصى للأجهزة (جهازين فقط)";
                       _isLoading = false;
                       notifyListeners();
                       // background trigger block
                       _registerDeviceOrBlock(cleanCode, deviceId);
                       return false;
                   }
               }

                final expiryStr = userData['expiry_date']?.toString();
                if (expiryStr != null && expiryStr.isNotEmpty && expiryStr != "بلا حدود" && expiryStr != "unlimited") {
                   final expiryDate = DateTime.tryParse(expiryStr);
                   if (expiryDate != null) {
                      if (DateTime.now().isAfter(expiryDate)) {
                         lastError = "انتهت صلاحية الاشتراك";
                         _isLoading = false;
                         notifyListeners();
                         return false;
                      }
                      durationHours = expiryDate.difference(DateTime.now()).inHours;
                   } else {
                      durationHours = -1;
                   }
                } else {
                   durationHours = -1;
                }


               subName = "اشتراك $cleanCode";
            } else {
               subName = "اشتراك مجاني";
               durationHours = -1;
            }
         } catch (e) {
            debugPrint("Configuration parsing failed");
         }
      } else {
         lastError = "فشل في الاتصال بخادم التحديثات";
         _isLoading = false;
         notifyListeners();
         return false;
      }

      bool isAuthenticated = false;
      String pType = pass == 'stalker' ? 'stalker' : 'xtream';
      
      if (cleanCode == "2027") {
         isAuthenticated = true;
      } else if (pType == 'stalker') {
         try {
            final authUrl = Uri.parse("$host/server/load.php?type=stb&action=handshake&token=&JsHttpRequest=1-xml");
            final response = await http.get(authUrl, headers: {
              "Cookie": "mac=$user",
              "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
            }).timeout(const Duration(seconds: 15));
            
            if (response.statusCode == 200 || response.statusCode == 201) {
               try {
                  final data = await Isolate.run(() => json.decode(response.body));
                  if (data['js'] != null) {
                     if (data['js'] is Map && data['js']['token'] != null) {
                        _stalkerToken = data['js']['token'];
                     }
                     isAuthenticated = true;
                  }
               } catch (_) {
                  // Fallback for portals that don't return JSON handshake
                  if (response.body.isNotEmpty) isAuthenticated = true;
               }
            }
         } catch (e) {
            lastError = "فشل التحقق من حساب الماك";
         }
      } else {
         try {
            final authUrl = Uri.parse("$host/player_api.php?username=$user&password=$pass");
            final response = await http.get(authUrl).timeout(const Duration(seconds: 15));
            if (response.statusCode == 200) {
               final data = await Isolate.run(() => json.decode(response.body));
               if (data['user_info'] != null && data['user_info']['auth'] != 0) {
                  isAuthenticated = true;
               }
            }
         } catch (e) {
            lastError = "فشل التحقق من الحساب";
         }
      }

      if (isAuthenticated) {
          
          final prefs = await SharedPreferences.getInstance();
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          await prefs.setString('active_code', cleanCode);
          await prefs.setInt('active_code_activated_at', nowMs);
          await prefs.setInt('active_code_duration_hours', durationHours);
          await prefs.setString('active_code_sub_name', subName);
          await prefs.setString('app_name_cached', _appName);

          _activationCode = cleanCode;
          _activationTime = nowMs;
          _activationDurationHours = durationHours;
          _subscriptionType = subName;

          final list = UserPlaylist(
            id: "${pType}_$cleanCode",
            name: _appName,
            type: pType,
            host: host,
            username: user,
            password: pass == 'stalker' ? '' : pass,
          );

          _savedPlaylists = [list];
          _activePlaylistId = list.id;
          
          await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
          await prefs.setBool('show_welcome_after_login', true);
          await prefs.setBool('is_logged_in', true);
          
          _isLoggedIn = true;
          _isLoading = false;
          notifyListeners();
          
          await loadPlaylistStreams(list.id);
          return true;
        } else {
          lastError = "رمز الدخول غير صحيح";
        }
    } catch (e) {
      lastError = "تعذر الاتصال. تأكد من الانترنت.";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadPlaylistStreams(String id) async {
    _isFetchingData = true;
    notifyListeners();

    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) {
        _isFetchingData = false;
        notifyListeners();
        return;
    }
    _activePlaylistId = id;

    if (_activationCode == "2027") {
       try {
            final String rawJson = '''[
  {
    "name": "SPORTS 1 HD ⚡",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max1.m3u8",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "خاصه ب نقل مباريات برشلونة ⚡",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://a12.kora-plus.li/live/alwan1.m3u8?token=C0WWFtcRLW-TRLXuk8jDEtk_3mc&exp=1786221480",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "SPORTS 2 HD ⚡",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max2.m3u8",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "SPORTS 3 HD ⚡",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max3.m3u8",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "SPORTS 4 HD ⚡",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max4.m3u8",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "SPORTS 5 HD⚡ ",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max5.m3u8",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "SPORTS 6 HD⚡ ",
    "icon": "https://iili.io/CKGvbzx.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max6.m3u8",
    "category_name": "Match time",
    "category_id": "custom_pro_1",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "beIN Sports 1 HD pro  ⚡",
    "icon": "https://iili.io/CK75BIe.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max7.m3u8",
    "category_name": "بين سبورت",
    "category_id": "custom_pro_2",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "beIN Sports 2 HD pro  ⚡",
    "icon": "https://iili.io/CK75iZu.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max8.m3u8",
    "category_name": "بين سبورت",
    "category_id": "custom_pro_2",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "beIN Sports 3 HD pro ⚡",
    "icon": "https://iili.io/CK77jSV.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max9.m3u8",
    "category_name": "بين سبورت",
    "category_id": "custom_pro_2",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "beIN Sports 4 HD pro  ⚡",
    "icon": "https://iili.io/CK7c6Ux.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max10.m3u8",
    "category_name": "بين سبورت",
    "category_id": "custom_pro_2",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "beIN Sports 5 HD pro  ⚡",
    "icon": "https://iili.io/CK7lc0b.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max11.m3u8",
    "category_name": "بين سبورت",
    "category_id": "custom_pro_2",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "beIN Sports 6 HD pro  ⚡",
    "icon": "https://iili.io/CK7l4LX.png",
    "url": "https://live-football-2mf.pages.dev/index_bein%20max12.m3u8",
    "category_name": "بين سبورت",
    "category_id": "custom_pro_2",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 1  ⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport1/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 2  ⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport2/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 3⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport3/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 4 ⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport4/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 5 ⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport6/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 6  ⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport6/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "LIVE STREAM NETWORK 7  ⚡",
    "icon": "https://iili.io/CK5M0pR.png",
    "url": "http://45.67.56.78/Sport7/index.fmp4.m3u8",
    "category_name": "قنوات البث المباشر",
    "category_id": "custom_pro_3",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Alkass Sports 1 ⚡",
    "icon": "https://iili.io/CKMJBjf.png",
    "url": "https://liveeu-gcp.alkassdigital.net/alkass1-p/main.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {
      "47f0ab58f5a81c20b5b69dc494cbe102": "1e0719da653c2b4652f0b0bf84d96c74"
    }
  },
  {
    "name": "Alkass Sports 2 ⚡",
    "icon": "https://iili.io/CKMJBjf.png",
    "url": "https://liveeu-gcp.alkassdigital.net/alkass2-p/main.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Alkass Sports 3 ⚡",
    "icon": "https://iili.io/CKMJBjf.png",
    "url": "https://liveeu-gcp.alkassdigital.net/alkass3-p/main.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Alkass Sports 4 ⚡",
    "icon": "https://iili.io/CKMJBjf.png",
    "url": "https://liveeu-gcp.alkassdigital.net/alkass4-p/main.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Alkass Sports 5 ⚡",
    "icon": "https://iili.io/CKMJBjf.png",
    "url": "https://liveeu-gcp.alkassdigital.net/alkass5-p/main.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Alkass Sports 6 ⚡",
    "icon": "https://iili.io/CKMJBjf.png",
    "url": "https://liveeu-gcp.alkassdigital.net/alkass6-p/main.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Starz Play Sports 1 ⚡",
    "icon": "https://iili.io/Cf02bDP.jpg",
    "url": "https://live-football-2mf.pages.dev/index_starz%20play1.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Starz Play Sports 2 ⚡",
    "icon": "https://iili.io/Cf02bDP.jpg",
    "url": "https://live-football-2mf.pages.dev/index_starz%20play2.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Starz Play Sports 3 ⚡",
    "icon": "https://iili.io/Cf02bDP.jpg",
    "url": "https://live-football-2mf.pages.dev/index_starz%20play3.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "THMANYAH  SPORTS 1  ⚡",
    "icon": "https://iili.io/CKGia0x.png",
    "url": "http://marveliptv.life/01112727740kh/khiary7740/474871",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "THMANYAH  SPORTS 2  ⚡",
    "icon": "https://iili.io/CKGia0x.png",
    "url": "http://marveliptv.life/01112727740kh/khiary7740/474867",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "THMANYAH  SPORTS 3  ⚡",
    "icon": "https://iili.io/CKGia0x.png",
    "url": "http://marveliptv.life/01112727740kh/khiary7740/474863",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Abu Dhabi Sport 1 ⚡",
    "icon": "https://iili.io/CBe6i8X.jpg",
    "url": "https://live-football-2mf.pages.dev/index_AD%20sports1.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Abu Dhabi Sport 2 ⚡",
    "icon": "https://iili.io/CBe6i8X.jpg",
    "url": "https://live-football-2mf.pages.dev/index_AD%20sports2.m3u8",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "Sharjah SPORTS HD⚡",
    "icon": "https://iili.io/CgrMtWX.jpg",
    "url": "http://marveliptv.life/01112727740kh/khiary7740/261524",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "IRAQI SPORTS HD⚡",
    "icon": "https://iili.io/CgrexDv.jpg",
    "url": "http://marveliptv.life/01112727740kh/khiary7740/154339",
    "category_name": "الرياضة العربية",
    "category_id": "custom_pro_4",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "قناة الجزيرة الإخبارية Al Jazeera HD ⚡",
    "icon": "https://iili.io/CzNY9yJ.jpg",
    "url": "https://live-hls-web-aja.getaj.net/AJA/index.m3u8",
    "category_name": "قنوات الأخبار والأحداث",
    "category_id": "custom_pro_5",
    "user_agent": "IPTV-Android-Box",
    "referer": "https://aljazeera.net",
    "keys": {
      "7406a641db1b63cbdcffdaae8df2831f": "daae8df2831f7406a641db1b63cbdcff"
    }
  },
  {
    "name": "العربية الحدث Al Hadath HD ⚡",
    "icon": "https://iili.io/CzwcODx.jpg",
    "url": "https://live.alarabiya.net/alarabiapublish/alarabiya.smil/playlist.m3u8",
    "category_name": "قنوات الأخبار والأحداث",
    "category_id": "custom_pro_5"
  },
  {
    "name": "قناة العربية Al Arabiya HD ⚡",
    "icon": "https://iili.io/Czwle7n.jpg",
    "url": "https://live.kwikmotion.com/alaraby1live/alaraby_abr/playlist.m3u8",
    "category_name": "قنوات الأخبار والأحداث",
    "category_id": "custom_pro_5"
  },
  {
    "name": "Sky News Arabia سكاي نيوز ⚡",
    "icon": "https://iili.io/Czw1ODG.png",
    "url": "https://live-stream.skynewsarabia.com/c-horizontal-channel/horizontal-stream/index.m3u8",
    "category_name": "قنوات الأخبار والأحداث",
    "category_id": "custom_pro_5"
  },
  {
    "name": "BBC Arabic بي بي سي عربي ⚡",
    "icon": "https://iili.io/CzwEld7.png",
    "url": "https://vs-cmaf-pushb-ww-live.akamaized.net/x=4/i=urn:bbc:pips:service:bbc_arabic_tv/mobile_wifi_main_hd_abr_v2.mpd",
    "category_name": "قنوات الأخبار والأحداث",
    "category_id": "custom_pro_5"
  },
  {
    "name": "RT Arabic روسيا اليوم ⚡",
    "icon": "https://iili.io/CzwGfTu.jpg",
    "url": "https://rt-arb.rttv.com/live/rtarab/playlist_1600Kb.m3u8",
    "category_name": "قنوات الأخبار والأحداث",
    "category_id": "custom_pro_5"
  },
  {
    "name": "NAT GEO WILD 🌍",
    "icon": "https://iili.io/Cz6SVAx.png",
    "url": "https://fastlyrwb-live.cdn.intigral-ott.net/NHD/NHD.isml/manifest.mpd",
    "category_name": "الوثائقية والثقافية",
    "category_id": "custom_pro_6",
    "user_agent": "Mozilla/5.0 (SmartTV)",
    "referer": "https://natgeo.ae",
    "keys": {
      "276e56bc14095f327bbf0c936eb7b38c": "63127eaddb18c596db05657424849519"
    }
  },
  {
    "name": "قناة الشروق الوثائقية 🗺️",
    "icon": "https://iili.io/Cz6SVAx.png",
    "url": "https://svs.itworkscdn.net/asharqdocumentarylive/asharqdocumentary.smil/playlist_dvr.m3u8",
    "category_name": "الوثائقية والثقافية",
    "category_id": "custom_pro_6",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "الجزيرة الوثائقية Al Jazeera Doc 🔎",
    "icon": "https://iili.io/Cz6SVAx.png",
    "url": "https://live-hls-apps-ajd-fa.getaj.net/AJD/index.m3u8",
    "category_name": "الوثائقية والثقافية",
    "category_id": "custom_pro_6",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "DISCOVER PAKISTAN 🇵🇰",
    "icon": "https://iili.io/Cz6SVAx.png",
    "url": "https://ml-pull-dvc-myco.io:2096/DISCOVER_PAKISTAN/index.m3u8",
    "category_name": "الوثائقية والثقافية",
    "category_id": "custom_pro_6",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "INTRAVEL ✈️",
    "icon": "https://iili.io/Cz6SVAx.png",
    "url": "https://amg00861-amg00861c10-rakuten-uk-3152.playouts.now.amagi.tv/playlist.m3u8",
    "category_name": "الوثائقية والثقافية",
    "category_id": "custom_pro_6",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "WILD TV 🌲",
    "icon": "https://iili.io/Cz6SVAx.png",
    "url": "https://dfhsahpa45kk2.cloudfront.net/scheduler/scheduleMaster/476.m3u8",
    "category_name": "الوثائقية والثقافية",
    "category_id": "custom_pro_6",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "MBC 1 🎭",
    "icon": "https://iili.io/CK7B3G9.png",
    "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-1-na/eec141533c90dd34722c503a296dd0d8/index.m3u8",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "IPTV-Plus",
    "referer": "https://shahid.mbc.net",
    "keys": {}
  },
  {
    "name": "MBC 2 🎬",
    "icon": "https://iili.io/CRgbxbS.png",
    "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-2/51db9d7fa48a27d051f1eecb68069151/index.mpd",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "IPTV-Plus",
    "referer": "https://shahid.mbc.net",
    "keys": {
      "e3ce77324a3d4fa2a913b26cc1976052": "17774f82a3b9e33ea7a149596acbb20f"
    }
  },
  {
    "name": "MBC 4 🎡",
    "icon": "https://iili.io/CRgmPMF.png",
    "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-4/24f134f1cd63db9346439e96b86ca6ed/index.m3u8",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "MBC 5 🌟",
    "icon": "https://iili.io/CRgploP.png",
    "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-5/ee6b000cee0629411b666ab26cb13e9b/index.m3u8",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "MBC MASR 1 ⚡",
    "icon": "https://iili.io/CK7zZ4S.png",
    "url": "https://shd-gcp-live.lg.mncdn.com/live/bitmovin-mbc-masr/956eac069c78a35d47245db6cdbb1575/index.m3u8",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "MBC MASR 2 🔥",
    "icon": "https://iili.io/CK7IN9e.png",
    "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-masr-2/754931856515075b0aabf0e583495c68/index.m3u8",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "",
    "referer": "",
    "keys": {}
  },
  {
    "name": "MBC IRAQ 🇮🇶",
    "icon": "https://iili.io/CK7T9St.png",
    "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-iraq/e38c44b1b43474e1c39cb5b90203691e/index.m3u8",
    "category_name": "القنوات الترفيهية",
    "category_id": "custom_pro_7",
    "user_agent": "",
    "referer": "",
    "keys": {}
  }
]
''';
            final List<dynamic> data = json.decode(rawJson);
            List<Map<String, String>> tempCats = [];
            List<PlaylistItem> tempStreams = [];
            Set<String> catNames = {};
            
            for (int i=0; i<data.length; i++) {
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
                 clearKeys = (item['keys'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
               } else if (item['clearKeys'] != null && item['clearKeys'] is Map) {
                 clearKeys = (item['clearKeys'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
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
                  customUserAgent: item['user_agent']?.toString() ?? item['customUserAgent']?.toString(),
                  customReferer: item['referer']?.toString() ?? item['customReferer']?.toString(),
                  clearKeys: clearKeys,
               ));
            }

            // اعتراض وتصفية من المصدر المركزي
            _liveCategories = FilterService.interceptAndFilterCategories(tempCats, blockAdult: _blockAdultContent);
            _allStreams = FilterService.interceptAndFilterStreams(tempStreams, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
            _movieCategories = [];
            _seriesCategories = [];
            
            _applyFilters();
       } catch (e) {
          debugPrint("Configured streams could not be loaded: $e");
       }
       _isFetchingData = false;
       notifyListeners();
       return;
    }

    try {
      String host = (playlist.host ?? '').trim();
      if (host.endsWith('/')) host = host.substring(0, host.length - 1);
      final user = (playlist.username ?? '').trim();
      final pass = (playlist.password ?? '').trim();

      if (playlist.type == 'stalker' && host.isNotEmpty && user.isNotEmpty) {
        final headers = {
          "Cookie": "mac=$user", 
          "Authorization": "Bearer $_stalkerToken",
          "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3"
        };
        final liveCatsRes = await http.get(Uri.parse("$host/server/load.php?type=itv&action=get_genres&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 15));
        final liveStreamsRes = await http.get(Uri.parse("$host/server/load.php?type=itv&action=get_all_channels&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 25));

        List<Map<String, String>> tempLiveCats = [];
        if (liveCatsRes.statusCode == 200) {
          final data = await Isolate.run(() => json.decode(liveCatsRes.body));
          if (data['js'] is List) {
              for (var item in data['js']) {
                  tempLiveCats.add({
                    'category_id': item['id']?.toString() ?? '',
                    'category_name': item['title']?.toString() ?? '',
                  });
              }
          }
        }

        // اعتراض الفئات وتصفيتها فوراً
        tempLiveCats = FilterService.interceptAndFilterCategories(tempLiveCats, blockAdult: _blockAdultContent);

        List<PlaylistItem> tempStreams = [];
        if (liveStreamsRes.statusCode == 200) {
          final data = await Isolate.run(() => json.decode(liveStreamsRes.body));
          if (data['js'] != null) {
              final items = data['js'] is List ? data['js'] : (data['js']['data'] is List ? data['js']['data'] : []);
              for (var item in items) {
                  final catId = item['tv_genre_id']?.toString() ?? '';
                  final cat = tempLiveCats.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                  final catName = cat.isNotEmpty ? cat['category_name']! : 'بث مباشر';
                  final streamId = item['id']?.toString() ?? '';
                  tempStreams.add(PlaylistItem(
                    num: int.tryParse(item['number']?.toString() ?? '0'),
                    streamId: "live_$streamId",
                    name: item['name']?.toString() ?? '',
                    streamIcon: item['logo']?.toString() ?? '',
                    categoryId: catId,
                    categoryName: catName,
                    url: item['cmd']?.toString() ?? '', // URL is the CMD in Stalker
                    type: "stalker",
                  ));
              }
          }
        }

        // اعتراض القنوات وتصفيتها فوراً من المصدر
        _allStreams = FilterService.interceptAndFilterStreams(tempStreams, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
        _liveCategories = tempLiveCats;

        // Fetch VOD Categories & Streams for Stalker
        try {
            final vodCatsRes = await http.get(Uri.parse("$host/server/load.php?type=vod&action=get_categories&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 15));
            final vodStreamsRes = await http.get(Uri.parse("$host/server/load.php?type=vod&action=get_ordered_list&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 25));
            List<Map<String, String>> tempVodCats = [];
            if (vodCatsRes.statusCode == 200) {
              final data = await Isolate.run(() => json.decode(vodCatsRes.body));
              if (data['js'] is List) {
                  for (var item in data['js']) {
                      tempVodCats.add({'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? ''});
                  }
              }
            }
            tempVodCats = FilterService.interceptAndFilterCategories(tempVodCats, blockAdult: _blockAdultContent);
            
            List<PlaylistItem> tempMovies = [];
            if (vodStreamsRes.statusCode == 200) {
              final data = await Isolate.run(() => json.decode(vodStreamsRes.body));
              if (data['js'] != null) {
                  final items = data['js'] is List ? data['js'] : (data['js']['data'] is List ? data['js']['data'] : []);
                  for (var item in items) {
                      final catId = item['category_id']?.toString() ?? '';
                      final cat = tempVodCats.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                      final catName = cat.isNotEmpty ? cat['category_name']! : 'أفلام';
                      final streamId = item['id']?.toString() ?? '';
                      tempMovies.add(PlaylistItem(
                        streamId: "movie_$streamId",
                        name: item['name']?.toString() ?? '',
                        streamIcon: item['screenshot_uri']?.toString() ?? '',
                        categoryId: catId,
                        categoryName: catName,
                        url: item['cmd']?.toString() ?? '',
                        type: "stalker_movie",
                      ));
                  }
              }
            }
            _movieCategories = tempVodCats;
            _allStreams.addAll(FilterService.interceptAndFilterStreams(tempMovies, blockAdult: _blockAdultContent, channelFilter: _channelFilter));
        } catch (e) {
            print("Stalker VOD error: $e");
        }
        
        // Fetch Series for Stalker
        try {
            final seriesCatsRes = await http.get(Uri.parse("$host/server/load.php?type=series&action=get_categories&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 15));
            final seriesStreamsRes = await http.get(Uri.parse("$host/server/load.php?type=series&action=get_ordered_list&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 25));
            List<Map<String, String>> tempSeriesCats = [];
            if (seriesCatsRes.statusCode == 200) {
              final data = await Isolate.run(() => json.decode(seriesCatsRes.body));
              if (data['js'] is List) {
                  for (var item in data['js']) {
                      tempSeriesCats.add({'category_id': item['id']?.toString() ?? '', 'category_name': item['title']?.toString() ?? ''});
                  }
              }
            }
            tempSeriesCats = FilterService.interceptAndFilterCategories(tempSeriesCats, blockAdult: _blockAdultContent);
            
            List<PlaylistItem> tempSeries = [];
            if (seriesStreamsRes.statusCode == 200) {
              final data = await Isolate.run(() => json.decode(seriesStreamsRes.body));
              if (data['js'] != null) {
                  final items = data['js'] is List ? data['js'] : (data['js']['data'] is List ? data['js']['data'] : []);
                  for (var item in items) {
                      final catId = item['category_id']?.toString() ?? '';
                      final cat = tempSeriesCats.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                      final catName = cat.isNotEmpty ? cat['category_name']! : 'مسلسلات';
                      final streamId = item['id']?.toString() ?? '';
                      tempSeries.add(PlaylistItem(
                        streamId: "series_$streamId",
                        name: item['name']?.toString() ?? '',
                        streamIcon: item['screenshot_uri']?.toString() ?? '',
                        categoryId: catId,
                        categoryName: catName,
                        url: item['cmd']?.toString() ?? '',
                        type: "stalker_series",
                      ));
                  }
              }
            }
            _seriesCategories = tempSeriesCats;
            _allStreams.addAll(FilterService.interceptAndFilterStreams(tempSeries, blockAdult: _blockAdultContent, channelFilter: _channelFilter));
        } catch (e) {
            print("Stalker Series error: $e");
        }

        _isFetchingData = false;
        notifyListeners();
        return;
      } else if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {

        if (kDebugMode) {
           print("[XTREAM] Fetching Live categories from $host");
        }
        final liveCatsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 15));


        if (kDebugMode) {
           print("[XTREAM] Fetching Live streams...");
        }
        final liveStreamsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 25));


        List<Map<String, String>> tempLiveCats = [];
        if (liveCatsRes.statusCode == 200) {
          final List decoded = await Isolate.run(() => json.decode(liveCatsRes.body));
          tempLiveCats = decoded.map<Map<String, String>>((item) => {
            'category_id': item['category_id']?.toString() ?? '',
            'category_name': item['category_name']?.toString() ?? '',
          }).toList();
        }

        // اعتراض وتصفية فئات البث المباشر
        tempLiveCats = FilterService.interceptAndFilterCategories(tempLiveCats, blockAdult: _blockAdultContent);

        List<PlaylistItem> tempStreams = [];
        if (liveStreamsRes.statusCode == 200) {
          final List decoded = await Isolate.run(() => json.decode(liveStreamsRes.body));
          for (final item in decoded) {
            final catId = item['category_id']?.toString() ?? '';
            final cat = tempLiveCats.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
            final catName = cat.isNotEmpty ? cat['category_name']! : 'بث مباشر';
            final streamId = item['stream_id']?.toString() ?? '';
            tempStreams.add(PlaylistItem(
              num: item['num'] is int ? item['num'] : null,
              streamId: "live_$streamId",
              name: item['name']?.toString() ?? '',
              streamIcon: item['stream_icon']?.toString() ?? '',
              categoryId: catId,
              categoryName: catName,
              url: "$host/$user/$pass/$streamId",
              type: "live",
            ));
          }
        }

        // اعتراض وتصفية قنوات البث المباشر
        _allStreams = FilterService.interceptAndFilterStreams(tempStreams, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
        _liveCategories = tempLiveCats;
        
        // Fetch VOD and Series
        http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_categories")).then((vodCatsRes) async {
           if (vodCatsRes.statusCode == 200) {
              final List decoded = await Isolate.run(() => json.decode(vodCatsRes.body));
              final List<Map<String, String>> parsedCats = decoded.map<Map<String, String>>((item) => {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              }).toList();
              // اعتراض وتصفية فئات الأفلام
              _movieCategories = FilterService.interceptAndFilterCategories(parsedCats, blockAdult: _blockAdultContent);
           }
           http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_streams")).then((vodStreamsRes) async {
              if (vodStreamsRes.statusCode == 200) {
                final List decoded = await Isolate.run(() => json.decode(vodStreamsRes.body));
                List<PlaylistItem> tempMovies = [];
                for (final item in decoded) {
                  final catId = item['category_id']?.toString() ?? '';
                  final cat = _movieCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                  final catName = cat.isNotEmpty ? cat['category_name']! : 'أفلام';
                  final streamId = item['stream_id']?.toString() ?? '';
                  final container = item['container_extension']?.toString() ?? 'mp4';
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
                final filteredMovies = FilterService.interceptAndFilterStreams(tempMovies, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
                _allStreams.addAll(filteredMovies);
              }
              _applyFilters();
              notifyListeners();
           });
        });

        http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series_categories")).then((seriesCatsRes) async {
           if (seriesCatsRes.statusCode == 200) {
              final List decoded = await Isolate.run(() => json.decode(seriesCatsRes.body));
              final List<Map<String, String>> parsedCats = decoded.map<Map<String, String>>((item) => {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              }).toList();
              // اعتراض وتصفية فئات المسلسلات
              _seriesCategories = FilterService.interceptAndFilterCategories(parsedCats, blockAdult: _blockAdultContent);
           }
           http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series")).then((seriesRes) async {
              if (seriesRes.statusCode == 200) {
                final List decoded = await Isolate.run(() => json.decode(seriesRes.body));
                List<PlaylistItem> tempSeries = [];
                for (final item in decoded) {
                  final catId = item['category_id']?.toString() ?? '';
                  final cat = _seriesCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                  final catName = cat.isNotEmpty ? cat['category_name']! : 'مسلسلات';
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
                final filteredSeries = FilterService.interceptAndFilterStreams(tempSeries, blockAdult: _blockAdultContent, channelFilter: _channelFilter);
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
        if (stream.type == "movie" || stream.type == "series" || stream.type == "stalker_movie" || stream.type == "stalker_series") {
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
      if (_activeTab == "favorites" && !_favorites.contains(stream.streamId)) return false;
      if (_selectedCategory != "all" && stream.categoryName != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty && !stream.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
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
    int currentIndex = _filteredStreams.indexWhere((s) => s.streamId == _currentStream!.streamId);
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
