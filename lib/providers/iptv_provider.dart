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
import '../models/saved_subscription_code.dart';
import '../services/filter_service.dart';
import '../services/subscription_profile.dart';

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
  static const String _workerBase =
      'https://iptv-subscription-api.tvkora56.workers.dev';
  static const String _loginUrl = '$_workerBase/v1/login';
  static const String _savedSubscriptionCodesKey = 'saved_subscription_codes';
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  bool _liteMode = false;
  bool get liteMode => _liteMode;
  bool _liteModeUserSet = false;
  bool _autoLiteModeNoticePending = false;
  bool get autoLiteModeNoticePending => _autoLiteModeNoticePending;

  Future<void> consumeAutoLiteModeNotice() async {
    if (!_autoLiteModeNoticePending) return;
    _autoLiteModeNoticePending = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lite_mode_auto_notice_shown', true);
    notifyListeners();
  }

  Future<void> setLiteMode(bool value) async {
    if (_liteMode == value && _liteModeUserSet) return;
    _liteMode = value;
    _liteModeUserSet = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lite_mode', value);
    await prefs.setBool('lite_mode_user_set', true);
  }

  static bool shouldShowAutoLiteModeNotice({
    required bool autoEnabled,
    required bool noticeShown,
  }) {
    return autoEnabled && !noticeShown;
  }

  static bool shouldAutoEnableLiteMode({
    required bool isLowRamDevice,
    required int sdkInt,
    required bool has64BitAbi,
  }) {
    // Conservative detection: only low-RAM devices or very old 32-bit Android.
    return isLowRamDevice || (sdkInt <= 25 && !has64BitAbi);
  }

  Future<bool> _detectWeakDevice() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return shouldAutoEnableLiteMode(
        isLowRamDevice: info.isLowRamDevice,
        sdkInt: info.version.sdkInt,
        has64BitAbi: info.supported64BitAbis.isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

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
  List<SavedSubscriptionCode> _savedSubscriptionCodes = [];
  List<SavedSubscriptionCode> get savedSubscriptionCodes =>
      List.unmodifiable(_savedSubscriptionCodes);
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

  SavedSubscriptionCode? savedSubscriptionCode(String code) {
    final cleanCode = code.trim();
    for (final saved in _savedSubscriptionCodes) {
      if (saved.code == cleanCode) return saved;
    }
    return null;
  }

  Future<void> _persistSavedSubscriptionCodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedSubscriptionCodesKey,
      jsonEncode(_savedSubscriptionCodes.map((item) => item.toJson()).toList()),
    );
  }

  void _upsertSavedSubscriptionCode(
    String code, {
    String? label,
    String status = 'unknown',
    String? message,
  }) {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;
    final index =
        _savedSubscriptionCodes.indexWhere((item) => item.code == cleanCode);
    final old = index >= 0 ? _savedSubscriptionCodes[index] : null;
    final next = SavedSubscriptionCode(
      code: cleanCode,
      label:
          label?.trim().isNotEmpty == true ? label!.trim() : old?.label ?? '',
      status: status,
      lastCheckedAt: DateTime.now().millisecondsSinceEpoch,
      message: message,
    );
    if (index >= 0) {
      _savedSubscriptionCodes[index] = next;
    } else {
      _savedSubscriptionCodes.add(next);
    }
  }

  Future<bool> addSavedSubscriptionCode(String code,
      {String label = ''}) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      lastError = 'أدخل كود الاشتراك أولاً';
      notifyListeners();
      return false;
    }
    _upsertSavedSubscriptionCode(cleanCode, label: label, status: 'checking');
    await _persistSavedSubscriptionCodes();
    notifyListeners();
    final success = await loginWithCode(cleanCode);
    _upsertSavedSubscriptionCode(
      cleanCode,
      label: label,
      status: success ? 'active' : 'invalid',
      message: success ? null : lastError,
    );
    await _persistSavedSubscriptionCodes();
    notifyListeners();
    return success;
  }

  Future<bool> switchToSavedSubscription(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;
    if (_isLoggedIn && _activationCode == cleanCode) return true;
    final saved = savedSubscriptionCode(cleanCode);
    _upsertSavedSubscriptionCode(cleanCode,
        label: saved?.label, status: 'checking');
    await _persistSavedSubscriptionCodes();
    notifyListeners();
    final success = await loginWithCode(cleanCode);
    _upsertSavedSubscriptionCode(
      cleanCode,
      label: saved?.label,
      status: success ? 'active' : 'invalid',
      message: success ? null : lastError,
    );
    await _persistSavedSubscriptionCodes();
    notifyListeners();
    return success;
  }

  Future<void> renameSavedSubscriptionCode(String code, String label) async {
    final index =
        _savedSubscriptionCodes.indexWhere((item) => item.code == code.trim());
    if (index < 0) return;
    _savedSubscriptionCodes[index] =
        _savedSubscriptionCodes[index].copyWith(label: label.trim());
    await _persistSavedSubscriptionCodes();
    notifyListeners();
  }

  Future<void> removeSavedSubscriptionCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode == _activationCode.trim() && _isLoggedIn) {
      lastError = 'بدّل إلى اشتراك آخر قبل حذف الكود الحالي';
      notifyListeners();
      return;
    }
    _savedSubscriptionCodes.removeWhere((item) => item.code == cleanCode);
    await _persistSavedSubscriptionCodes();
    notifyListeners();
  }

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

  // The repository stays private; production menu delivery goes through Worker/D1.
  // Playback URLs inside the menu still point to the authenticated Worker proxy.
  static const String _menuUrl = '$_workerBase/v1/custom/menu';

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // فحص الحماية مرة واحدة عند بدء الجلسة؛ المؤقت الدوري أزيل لتقليل الثقل وإعادة البناء
    _checkVpnAndProxyStatus();
    checkSecurity();
    checkRemoteBlocking();

    final prefs = await SharedPreferences.getInstance();
    _liteModeUserSet = prefs.getBool('lite_mode_user_set') ?? false;
    if (_liteModeUserSet) {
      _liteMode = prefs.getBool('lite_mode') ?? false;
    } else {
      _liteMode = await _detectWeakDevice();
      _autoLiteModeNoticePending = shouldShowAutoLiteModeNotice(
        autoEnabled: _liteMode,
        noticeShown: prefs.getBool('lite_mode_auto_notice_shown') ?? false,
      );
    }

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
    // إعادة تفعيل أقسام الأفلام والمسلسلات بعد الإصدارات القديمة التي كانت تخفيها.
    // يمكن للمستخدم تعطيلها لاحقاً من الإعدادات إذا أراد.
    _showMoviesSeries = true;
    await prefs.setBool('filter_show_movies_series', true);
    _channelFilter = prefs.getString('channel_filter') ?? "الكل";
    _parentalPin = prefs.getString('parental_pin') ?? "";
    _lockedCategories = prefs.getStringList('locked_categories') ?? [];
    _activationCode = prefs.getString('active_code') ?? "";
    _activationTime = prefs.getInt('active_code_activated_at') ?? 0;
    _activationDurationHours = prefs.getInt('active_code_duration_hours') ?? -1;
    _subscriptionType = prefs.getString('active_code_sub_name') ?? "";

    // Migrate legacy saved origins to the HTTPS Worker gateway. Older APKs
    // persisted raw HTTP Xtream/Stalker hosts; Android 9+ blocks those URLs.
    // Xtream sessions also need the managed code/password expected by Worker.
    var playlistsMigrated = false;
    _savedPlaylists = _savedPlaylists.map((playlist) {
      final host = (playlist.host ?? '').trim();
      final isXtream = playlist.type.toLowerCase() == 'xtream';
      final isStalker = playlist.type.toLowerCase() == 'stalker';
      if (!isXtream && !isStalker) return playlist;
      final gateway =
          isStalker ? '$_workerBase/v1/stalker' : '$_workerBase/v1/xtream';
      final isWorkerHost = host.startsWith(_workerBase);
      if (isWorkerHost &&
          (!isXtream ||
              (playlist.username == _activationCode &&
                  playlist.password == 'managed'))) {
        return playlist;
      }
      playlistsMigrated = true;
      return UserPlaylist(
        id: playlist.id,
        name: playlist.name,
        type: playlist.type,
        url: playlist.url,
        host: gateway,
        username: isXtream && _activationCode.isNotEmpty
            ? _activationCode
            : playlist.username,
        password: isXtream ? 'managed' : playlist.password,
      );
    }).toList();
    if (playlistsMigrated) {
      await prefs.setString('saved_playlists',
          json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
    }

    final savedCodesJson = prefs.getString(_savedSubscriptionCodesKey);
    if (savedCodesJson != null) {
      try {
        final decodedCodes = jsonDecode(savedCodesJson);
        if (decodedCodes is List) {
          _savedSubscriptionCodes = decodedCodes
              .whereType<Map>()
              .map((item) => SavedSubscriptionCode.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.code.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    if (_activationCode.isNotEmpty &&
        savedSubscriptionCode(_activationCode) == null) {
      _upsertSavedSubscriptionCode(_activationCode, status: 'active');
      await _persistSavedSubscriptionCodes();
    }
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
            _securityMessage =
                "تم كشف صلاحيات الروت أو كسر حماية نظام الهاتف (Root Access Detected). كإجراء أمان، تم إيقاف عمل التطبيق.";
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

  bool _isValidatingSubscription = false;

  Future<Map<String, dynamic>?> _validateSubscriptionWithWorker() async {
    final code = _activationCode.trim();
    if (code.isEmpty) return null;
    try {
      final deviceId = await _getDeviceId();
      final response = await http
          .post(Uri.parse(_loginUrl),
              headers: const {'Content-Type': 'application/json'},
              body: json.encode({'code': code, 'device_id': deviceId}))
          .timeout(const Duration(seconds: 8));
      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (response.statusCode == 200 && data['ok'] == true) return data;
      if (response.statusCode == 401 || response.statusCode == 403) {
        return <String, dynamic>{
          '_invalid': true,
          'message':
              data['message']?.toString() ?? 'رمز الاشتراك غير صالح أو منتهي',
        };
      }
    } catch (e) {
      debugPrint('Worker subscription validation failed: $e');
    }
    return null;
  }

  Future<bool> _refreshSubscriptionProfile(Map<String, dynamic> data) async {
    final rawServer = data['server'] ?? data['user'];
    if (rawServer is! Map) return false;
    final server = Map<String, dynamic>.from(rawServer);
    final type = (server['type'] ?? server['server_type'] ?? 'xtream')
        .toString()
        .toLowerCase();
    final mode = (server['content_mode'] ?? 'iptv').toString().toLowerCase();
    final host = server['host']?.toString() ?? '';
    final username = server['username']?.toString() ?? '';
    final password = server['password']?.toString() ?? '';
    if (!hasCompleteWorkerSubscriptionProfile(data)) return false;

    var durationHours = -1;
    final subscription = data['subscription'];
    if (subscription is Map) {
      final expiry =
          DateTime.tryParse(subscription['expires_at']?.toString() ?? '');
      if (expiry != null)
        durationHours = expiry.difference(DateTime.now()).inHours;
    }
    final id = 'subscription_${_activationCode.trim()}';
    final refreshed = UserPlaylist(
      id: id,
      name: _appName,
      type: mode == 'custom_menu' ? 'custom' : type,
      host: host,
      username: username,
      password: type == 'stalker' ? '' : password,
    );
    final current = _savedPlaylists.isNotEmpty ? _savedPlaylists.first : null;
    final changed = current == null ||
        current.id != refreshed.id ||
        current.type != refreshed.type ||
        current.host != refreshed.host ||
        current.username != refreshed.username ||
        current.password != refreshed.password ||
        _activePlaylistId != refreshed.id;
    _activationDurationHours = durationHours;
    if (changed) {
      _savedPlaylists = [refreshed];
      _activePlaylistId = refreshed.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_playlists',
          json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
      await prefs.setInt('active_code_duration_hours', durationHours);
      notifyListeners();
    }
    return true;
  }

  Future<void> checkRemoteBlocking() async {
    if (_isValidatingSubscription) return;
    _isValidatingSubscription = true;
    try {
      final configRes = await http
          .get(Uri.parse(
              '$_workerBase/v1/config?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (configRes.statusCode == 200) {
        final decoded = json.decode(configRes.body);
        if (decoded is Map) {
          final configData = Map<String, dynamic>.from(decoded);
          final blockData = configData['blocking'] is Map
              ? Map<String, dynamic>.from(configData['blocking'])
              : <String, dynamic>{};
          if (configData.containsKey('announcement')) {
            final newAnn = configData['announcement'].toString();
            if (_announcementText != newAnn) {
              _announcementText = newAnn;
              notifyListeners();
            }
          }
          final isBlocked = (blockData['blocked_version_codes'] is List &&
                  (blockData['blocked_version_codes'] as List)
                      .contains(_currentVersionCode)) ||
              (_currentVersionCode <
                  (int.tryParse(
                          blockData['min_version_code']?.toString() ?? '0') ??
                      0)) ||
              isOutdatedVersion(_currentVersionStr, _currentVersionCode);
          if (_isVersionBlocked != isBlocked) {
            _isVersionBlocked = isBlocked;
            if (isBlocked &&
                isOutdatedVersion(_currentVersionStr, _currentVersionCode)) {
              _remoteBlockMessage =
                  'يرجى تحديث التطبيق إلى أحدث إصدار للاستمرار.';
            } else if (blockData['block_message'] != null) {
              _remoteBlockMessage = blockData['block_message'].toString();
            }
            notifyListeners();
          }
        }
      }

      if (_isLoggedIn && _activationCode.trim().isNotEmpty) {
        final validation = await _validateSubscriptionWithWorker();
        if (validation?['_invalid'] == true) {
          lastError = validation?['message']?.toString() ??
              'رمز الاشتراك غير صالح أو منتهي';
          await logout();
          notifyListeners();
        } else if (validation != null) {
          final complete = await _refreshSubscriptionProfile(validation);
          if (!complete) {
            // Do not destroy a working session because a response is temporarily incomplete.
            debugPrint('Worker returned an incomplete subscription profile');
          }
        }
      }
    } catch (e) {
      // Network/config failures must never log the user out.
      debugPrint('Remote Worker check failed: $e');
    } finally {
      _isValidatingSubscription = false;
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
    _isLoading = true;
    notifyListeners();
    try {
      final deviceId = await _getDeviceId();
      final response = await http
          .post(Uri.parse(_loginUrl),
              headers: const {'Content-Type': 'application/json'},
              body: json.encode({'code': cleanCode, 'device_id': deviceId}))
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> data = <String, dynamic>{};
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (response.statusCode != 200 || data['ok'] != true) {
        lastError =
            data['message']?.toString() ?? 'رمز الدخول غير صالح أو غير مصرح به';
        return false;
      }
      final rawServer = data['server'] ?? data['user'];
      if (rawServer is! Map) {
        lastError = 'بيانات السيرفر غير موجودة في الاستجابة';
        return false;
      }
      final server = Map<String, dynamic>.from(rawServer);
      final type = (server['type'] ?? server['server_type'] ?? 'xtream')
          .toString()
          .toLowerCase();
      final mode = (server['content_mode'] ?? 'iptv').toString().toLowerCase();
      final host = server['host']?.toString() ?? '';
      final username = server['username']?.toString() ?? '';
      final password = server['password']?.toString() ?? '';
      final isCustomMenu = mode == 'custom_menu';
      if (!isCustomMenu &&
          (host.isEmpty ||
              username.isEmpty ||
              (type != 'stalker' && password.isEmpty))) {
        lastError = 'بيانات الاشتراك غير مكتملة';
        return false;
      }
      var durationHours = -1;
      final subscription = data['subscription'];
      if (subscription is Map) {
        final expiry =
            DateTime.tryParse(subscription['expires_at']?.toString() ?? '');
        if (expiry != null) {
          durationHours = expiry.difference(DateTime.now()).inHours;
          if (durationHours < 0) {
            lastError = 'انتهت صلاحية الاشتراك';
            return false;
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      _activationCode = cleanCode;
      _activationTime = now;
      _activationDurationHours = durationHours;
      _subscriptionType = 'اشتراك $cleanCode';
      _isLoggedIn = true;
      final list = UserPlaylist(
          id: 'subscription_$cleanCode',
          name: _appName,
          type: mode == 'custom_menu' ? 'custom' : type,
          host: host,
          username: username,
          password: type == 'stalker' ? '' : password);
      _savedPlaylists = [list];
      _activePlaylistId = list.id;
      await prefs.setString('active_code', cleanCode);
      await prefs.setInt('active_code_activated_at', now);
      await prefs.setInt('active_code_duration_hours', durationHours);
      await prefs.setString('active_code_sub_name', _subscriptionType);
      await prefs.setString('saved_playlists',
          json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
      await prefs.setBool('is_logged_in', true);
      _upsertSavedSubscriptionCode(cleanCode, status: 'active');
      await _persistSavedSubscriptionCodes();
      if (type == 'stalker') {
        _globalUserAgent =
            'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';
      }
      notifyListeners();
      if (mode == 'custom_menu') {
        await _loadCuratedGitHubContent();
      } else {
        await loadPlaylistStreams(list.id);
      }
      return true;
    } on TimeoutException {
      lastError = 'انتهت مهلة الاتصال. تحقق من الإنترنت ثم أعد المحاولة';
    } catch (e) {
      lastError = 'تعذر الاتصال. تأكد من الإنترنت وصحة الاشتراك';
      debugPrint('Cloudflare login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> _loadCuratedGitHubContent() async {
    // القائمة المخصصة مستقلة عن فلاتر Xtream السابقة؛ لا نسمح بحالة قديمة بإخفاء القنوات.
    _selectedCategory = 'all';
    _searchQuery = '';
    _channelFilter = 'الكل';
    _isFetchingData = true;
    _allStreams = [];
    _liveCategories = [];
    try {
      final response = await http
          .get(Uri.parse(
            '$_menuUrl?t=${DateTime.now().millisecondsSinceEpoch}',
          ))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          final seen = <String>{};
          for (final raw in decoded) {
            if (raw is! Map) continue;
            final categoryId = raw['category_id']?.toString() ?? '99';
            final categoryName = raw['category_name']?.toString() ?? 'بث مباشر';
            if (seen.add(categoryId)) {
              _liveCategories.add(
                  {'category_id': categoryId, 'category_name': categoryName});
            }
            _allStreams.add(PlaylistItem(
              num: null,
              streamId: _allStreams.length.toString(),
              name: raw['name']?.toString() ?? 'قناة',
              streamIcon: raw['icon']?.toString() ?? '',
              categoryId: categoryId,
              categoryName: categoryName,
              url: raw['url']?.toString() ?? '',
              type: 'live',
            ));
          }
        }
      }
    } catch (_) {}
    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _fetchStalkerOrderedList(
      String host, Map<String, String> headers, String type) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$host/server/load.php?type=$type&action=get_ordered_list&genre=0&force_ch_link_check=0&p=1&JsHttpRequest=1-xml',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return [];
      final decoded = json.decode(response.body);
      final raw = decoded is Map ? decoded['js'] : null;
      final items = raw is List
          ? raw
          : raw is Map && raw['data'] is List
              ? raw['data']
              : const [];
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Stalker $type list unavailable: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _fetchStalkerCategories(
      String host, Map<String, String> headers, String type) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$host/server/load.php?type=$type&action=get_categories&JsHttpRequest=1-xml',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final decoded = json.decode(response.body);
      final raw = decoded is Map ? decoded['js'] : null;
      final items = raw is List
          ? raw
          : raw is Map && raw['data'] is List
              ? raw['data']
              : const [];
      return items
          .whereType<Map>()
          .map((item) {
            final id =
                (item['id'] ?? item['category_id'] ?? item['genre_id'] ?? '')
                    .toString();
            final name = (item['title'] ??
                    item['category_name'] ??
                    item['name'] ??
                    'غير مصنف')
                .toString();
            return {'category_id': id, 'category_name': name};
          })
          .where((item) => item['category_id']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Stalker $type categories unavailable: $e');
      return [];
    }
  }

  String _stalkerCommandFallback(String type, String streamId) {
    return base64Encode(utf8.encode(jsonEncode({
      'type': type,
      'stream_id': streamId,
      'stream_source': null,
      'target_container': ['mp4'],
    })));
  }

  Future<void> refreshCurrentPlaylist() async {
    if (_isFetchingData || _activePlaylistId == null) return;
    await loadPlaylistStreams(_activePlaylistId!, forceRefresh: true);
  }

  Future<void> loadPlaylistStreams(String id,
      {bool forceRefresh = false}) async {
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
    final refreshQuery =
        forceRefresh ? '&refresh=${DateTime.now().millisecondsSinceEpoch}' : '';

    if (playlist.type == 'custom') {
      await _loadCuratedGitHubContent();
      _isFetchingData = false;
      notifyListeners();
      return;
    }

    try {
      final host = (playlist.host ?? '').trim();
      final user = (playlist.username ?? '').trim();
      final pass = (playlist.password ?? '').trim();

      if (playlist.type == 'stalker' && host.isNotEmpty && user.isNotEmpty) {
        final headers = {
          "Cookie": "mac=$user",
          "Authorization": "Bearer $_stalkerToken",
          "User-Agent":
              "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3"
        };
        final liveResponses = await Future.wait([
          http
              .get(
                  Uri.parse(
                      "$host/server/load.php?type=itv&action=get_genres&JsHttpRequest=1-xml"),
                  headers: headers)
              .timeout(const Duration(seconds: 15)),
          http
              .get(
                  Uri.parse(
                      "$host/server/load.php?type=itv&action=get_all_channels&JsHttpRequest=1-xml"),
                  headers: headers)
              .timeout(const Duration(seconds: 25)),
        ]);
        final liveCatsRes = liveResponses[0];
        final liveStreamsRes = liveResponses[1];

        List<Map<String, String>> tempLiveCats = [];
        if (liveCatsRes.statusCode == 200) {
          final data = json.decode(liveCatsRes.body);
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
        tempLiveCats = FilterService.interceptAndFilterCategories(tempLiveCats,
            blockAdult: _blockAdultContent);

        List<PlaylistItem> tempStreams = [];
        if (liveStreamsRes.statusCode == 200) {
          final data = json.decode(liveStreamsRes.body);
          if (data['js'] != null) {
            final items = data['js'] is List
                ? data['js']
                : (data['js']['data'] is List ? data['js']['data'] : []);
            for (var item in items) {
              final catId = item['tv_genre_id']?.toString() ?? '';
              final cat = tempLiveCats.firstWhere(
                  (c) => c['category_id'] == catId,
                  orElse: () => {});
              final catName =
                  cat.isNotEmpty ? cat['category_name']! : 'بث مباشر';
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
        _allStreams = FilterService.interceptAndFilterStreams(tempStreams,
            blockAdult: _blockAdultContent, channelFilter: _channelFilter);
        _liveCategories = tempLiveCats;

        final vodCats = await _fetchStalkerCategories(host, headers, 'vod');
        final seriesCats =
            await _fetchStalkerCategories(host, headers, 'series');
        _movieCategories = FilterService.interceptAndFilterCategories(vodCats,
            blockAdult: _blockAdultContent);
        _seriesCategories = FilterService.interceptAndFilterCategories(
            seriesCats,
            blockAdult: _blockAdultContent);

        final vodItems = await _fetchStalkerOrderedList(host, headers, 'vod');
        final seriesItems =
            await _fetchStalkerOrderedList(host, headers, 'series');
        final movieStreams = <PlaylistItem>[];
        for (final item in vodItems) {
          final streamId =
              (item['id'] ?? item['movie_id'] ?? item['stream_id'] ?? '')
                  .toString();
          if (streamId.isEmpty) continue;
          final categoryId = (item['category_id'] ??
                  item['genre_id'] ??
                  item['tv_genre_id'] ??
                  '')
              .toString();
          final category = _movieCategories.firstWhere(
            (entry) => entry['category_id'] == categoryId,
            orElse: () => {'category_id': categoryId, 'category_name': 'أفلام'},
          );
          final command = (item['cmd'] ??
                  item['stream_url'] ??
                  item['streamUrl'] ??
                  item['url'] ??
                  '')
              .toString()
              .trim();
          movieStreams.add(PlaylistItem(
            num: int.tryParse(item['number']?.toString() ?? ''),
            streamId: 'stalker_movie_$streamId',
            name: (item['name'] ?? item['o_name'] ?? 'فيلم').toString(),
            streamIcon: (item['pic'] ?? '').toString(),
            categoryId: categoryId,
            categoryName: category['category_name'] ?? 'أفلام',
            url: command.isNotEmpty
                ? command
                : _stalkerCommandFallback('movie', streamId),
            type: 'stalker_movie',
            year: item['year']?.toString(),
            plot: item['description']?.toString(),
            rating: item['rating_imdb']?.toString() ?? item['rate']?.toString(),
          ));
        }
        final seriesStreams = <PlaylistItem>[];
        for (final item in seriesItems) {
          final streamId =
              (item['id'] ?? item['series_id'] ?? item['stream_id'] ?? '')
                  .toString();
          if (streamId.isEmpty) continue;
          final categoryId = (item['category_id'] ??
                  item['genre_id'] ??
                  item['tv_genre_id'] ??
                  '')
              .toString();
          final category = _seriesCategories.firstWhere(
            (entry) => entry['category_id'] == categoryId,
            orElse: () =>
                {'category_id': categoryId, 'category_name': 'مسلسلات'},
          );
          final command = (item['cmd'] ??
                  item['stream_url'] ??
                  item['streamUrl'] ??
                  item['url'] ??
                  '')
              .toString()
              .trim();
          seriesStreams.add(PlaylistItem(
            num: int.tryParse(item['number']?.toString() ?? ''),
            streamId: 'stalker_series_$streamId',
            name: (item['name'] ?? item['o_name'] ?? 'مسلسل').toString(),
            streamIcon: (item['pic'] ?? '').toString(),
            categoryId: categoryId,
            categoryName: category['category_name'] ?? 'مسلسلات',
            url: command.isNotEmpty
                ? command
                : _stalkerCommandFallback('series', streamId),
            type: 'stalker_series',
            year: item['year']?.toString(),
            plot: item['description']?.toString(),
            rating: item['rating_imdb']?.toString() ?? item['rate']?.toString(),
          ));
        }
        _allStreams.addAll(FilterService.interceptAndFilterStreams(
          movieStreams,
          blockAdult: _blockAdultContent,
          channelFilter: _channelFilter,
        ));
        _allStreams.addAll(FilterService.interceptAndFilterStreams(
          seriesStreams,
          blockAdult: _blockAdultContent,
          channelFilter: _channelFilter,
        ));
        _applyFilters();
        _isFetchingData = false;
        notifyListeners();
        return;
      } else if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
        final liveResponses = await Future.wait([
          http
              .get(Uri.parse(
                  "$host/player_api.php?username=$user&password=$pass&action=get_live_categories$refreshQuery"))
              .timeout(const Duration(seconds: 15)),
          http
              .get(Uri.parse(
                  "$host/player_api.php?username=$user&password=$pass&action=get_live_streams$refreshQuery"))
              .timeout(const Duration(seconds: 25)),
        ]);
        final liveCatsRes = liveResponses[0];
        final liveStreamsRes = liveResponses[1];

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
                "$host/player_api.php?username=$user&password=$pass&action=get_vod_categories$refreshQuery"))
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
                  "$host/player_api.php?username=$user&password=$pass&action=get_vod_streams$refreshQuery"))
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
                "$host/player_api.php?username=$user&password=$pass&action=get_series_categories$refreshQuery"))
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
                  "$host/player_api.php?username=$user&password=$pass&action=get_series$refreshQuery"))
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
        } else if (_activeTab == "movie") {
          if (stream.type != "movie" && stream.type != "stalker_movie")
            return false;
        } else if (_activeTab == "series") {
          if (stream.type != "series" && stream.type != "stalker_series")
            return false;
        } else if (stream.type != _activeTab) {
          return false;
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
    for (final key in <String>[
      'active_code',
      'active_code_activated_at',
      'active_code_duration_hours',
      'active_code_sub_name',
      'saved_playlists',
      'is_logged_in',
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
    _activePlaylistId = null;
    _selectedCategory = 'all';
    _searchQuery = '';
    notifyListeners();
  }
}
