import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../models/playlist_item.dart';
import '../services/m3u_parser.dart';

class MyHttpOverrides extends HttpOverrides {
  final String proxyAddress;
  MyHttpOverrides(this.proxyAddress);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        return "PROXY $proxyAddress;";
      }
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String date;
  final String type; // 'info', 'update', 'alert'

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
    );
  }
}

class IPTVProvider with ChangeNotifier {
  List<PlaylistItem> _allStreams = [];
  List<PlaylistItem> _filteredStreams = [];
  List<UserPlaylist> _savedPlaylists = [];
  String? _activePlaylistId;
  PlaylistItem? _currentStream;
  List<String> _favorites = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String _activeTab = "live"; // live, movie, series, favorites, playlists, custom_pro
  String _selectedCategory = "all";
  String _searchQuery = "";
  bool _isLoggedIn = false;

  // Custom Pro Stream properties & storage
  List<PlaylistItem> _customProStreams = [];
  List<AppNotification> _githubNotifications = [];
  bool _notificationsLoading = false;

  // Global Engine Headers & Proxies
  String _globalUserAgent = "";
  String _globalReferer = "";
  String _globalProxy = "";

  // Category on-demand loading stores
  List<Map<String, String>> _liveCategories = [];
  List<Map<String, String>> _movieCategories = [];
  List<Map<String, String>> _seriesCategories = [];
  final Set<String> _loadedCategoryIds = {};
  final Map<String, List<PlaylistItem>> _streamsByTypeAndCategory = {};
  bool _snifferDetected = false;
  bool get snifferDetected => _snifferDetected;

  static const _securityChannel = MethodChannel('com.mahmoud.iptv/security');

  // Security & Subscriptions state variables
  static const int APP_VERSION_CODE = 144;
  bool _isVersionBlocked = false;
  String _remoteBlockMessage = "🚨 تحديث إجباري مطلوب فوراً 🚨\n\nلقد تم إيقاف هذا الإصدار القديم نهائياً لدواعي صيانة وتحديث الأمان. يرجى تنزيل الإصدار الأخير للاستمرار في مشاهدة القنوات والاشتراكات. شكراً لكم!";
  String get remoteBlockMessage => _remoteBlockMessage;
  String _activationCode = "";
  int _activationTime = 0;
  int _activationDurationHours = 0;
  String _subscriptionType = "";
  bool _vpnDetected = false;

  // GitHub Data Repository configuration
  String _githubUsername = "mahmoudhwhwhwh";
  String _githubRepo = "flutter-iptv-player";

  static String _serverBaseUrl = "https://iptv-player-fa64f.web.app";
  static Future<void> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _serverBaseUrl = prefs.getString('server_base_url') ?? "https://iptv-player-fa64f.web.app";
  }

  List<PlaylistItem> get streams => _filteredStreams;
  PlaylistItem? get currentStream => _currentStream;
  List<String> get favorites => _favorites;
  
  List<String> get categories {
    if (_activePlaylistId != null) {
      final playlist = _savedPlaylists.firstWhere((p) => p.id == _activePlaylistId, orElse: () => UserPlaylist(id: '', name: '', type: ''));
      if (playlist.type == 'xtream') {
        if (_activeTab == "live") {
          return _liveCategories.map((c) => c['category_name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        } else if (_activeTab == "movie") {
          return _movieCategories.map((c) => c['category_name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        } else if (_activeTab == "series") {
          return _seriesCategories.map((c) => c['category_name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        }
      }
    }
    return _categories;
  }
  List<UserPlaylist> get savedPlaylists => _savedPlaylists;
  String? get activePlaylistId => _activePlaylistId;
  bool get isLoading => _isLoading;
  String get activeTab => _activeTab;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoggedIn => _isLoggedIn;

  // Subscriptions & Security getters
  bool get isVersionBlocked => _isVersionBlocked;
  String get activationCode => _activationCode;
  int get activationTime => _activationTime;
  int get activationDurationHours => _activationDurationHours;
  String get subscriptionType => _subscriptionType;
  bool get vpnDetected => _vpnDetected;
  bool get isVipMode {
    // Check if the subscription is dynamic lifetime, or based on backend-verified subscription
    return _subscriptionType.toLowerCase().contains("lifetime") || _subscriptionType.toLowerCase().contains("مدى الحياة");
  }

  String get githubUsername => _githubUsername;
  String get githubRepo => _githubRepo;

  Future<void> saveGithubConfig(String username, String repo) async {
    _githubUsername = username.trim().isEmpty ? "mahmoudhwhwhwh" : username.trim();
    _githubRepo = repo.trim().isEmpty ? "flutter-iptv-player" : repo.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_username', _githubUsername);
    await prefs.setString('github_repo', _githubRepo);
    notifyListeners();
  }

  bool get isSubscribed {
    if (!_isLoggedIn) return false;
    return true;
  }

  bool get isExpired {
    if (!_isLoggedIn) return false;
    if (_activationDurationHours == -1) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = now - _activationTime;
    final elapsedHours = elapsedMs / (1000 * 60 * 60);
    return elapsedHours >= _activationDurationHours;
  }

  double get subscriptionHoursRemaining {
    if (!_isLoggedIn) return 0.0;
    if (_activationDurationHours == -1) return 99999.0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = now - _activationTime;
    final elapsedHours = elapsedMs / (1000 * 60 * 60);
    final remaining = _activationDurationHours - elapsedHours;
    return remaining < 0.0 ? 0.0 : remaining;
  }

  // Getters for proxy, custom streams and notifications
  String get globalUserAgent => _globalUserAgent;
  String get globalReferer => _globalReferer;
  String get globalProxy => _globalProxy;
  List<PlaylistItem> get allStreams => _allStreams;
  List<PlaylistItem> get customProStreams => _customProStreams;
  List<AppNotification> get githubNotifications => _githubNotifications;
  bool get notificationsLoading => _notificationsLoading;

  // Save network engine settings (global headers and proxy)
  Future<void> saveEngineSettings(String ua, String ref, String proxy) async {
    _globalUserAgent = ua.trim();
    _globalReferer = ref.trim();
    _globalProxy = proxy.trim();
    
    // update system overrides proxy setup
    _updateProxySettings(_globalProxy);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('engine_user_agent', _globalUserAgent);
    await prefs.setString('engine_referer', _globalReferer);
    await prefs.setString('engine_proxy', _globalProxy);
    notifyListeners();
  }

  void _updateProxySettings(String proxy) {
    if (proxy.trim().isNotEmpty) {
      try {
        HttpOverrides.global = MyHttpOverrides(proxy.trim());
      } catch (_) {}
    } else {
      HttpOverrides.global = null;
    }
  }

  // Load engine settings from storage
  Future<void> _loadEngineSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _globalUserAgent = prefs.getString('engine_user_agent') ?? "";
    _globalReferer = prefs.getString('engine_referer') ?? "";
    _globalProxy = prefs.getString('engine_proxy') ?? "";
    _githubUsername = prefs.getString('github_username') ?? "mahmoudhwhwhwh";
    _githubRepo = prefs.getString('github_repo') ?? "flutter-iptv-player";
    _updateProxySettings(_globalProxy);
  }

  // Fetch Live Notifications from GitHub
  Future<void> fetchGitHubNotifications() async {
    _notificationsLoading = true;
    notifyListeners();
    try {
      final config = await _fetchGitHubConfig();
      if (config != null && config.containsKey('notifications')) {
        final List data = config['notifications'] as List;
        _githubNotifications = data.map((n) => AppNotification.fromJson(n)).toList();
        _notificationsLoading = false;
        notifyListeners();
        return;
      }
    } catch (_) {}

    try {
      final response = await http.get(Uri.parse(
        '$_serverBaseUrl/api/notifications?t=${DateTime.now().millisecondsSinceEpoch}'
      )).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _githubNotifications = data.map((n) => AppNotification.fromJson(n)).toList();
      } else {
        throw Exception();
      }
    } catch (_) {
      // If notifications fetch fails, just show empty
      _githubNotifications = [];
    }
    _notificationsLoading = false;
    notifyListeners();
  }

  static final Map<int, String> _customSections = {};
  static final Map<int, String> _customSectionLogos = {};

  static String getSectionName(int index) {
    if (_customSections.containsKey(index)) {
      return _customSections[index]!;
    }
    switch (index) {
      case 1:
        return "Match time";
      case 2:
        return "أفلام وقنوات أطفال";
      case 3:
        return "قنوات الأخبار والأحداث";
      case 4:
        return "الرياضة العربية";
      case 5:
        return "القنوات الإسلامية والقرآن";
      case 6:
        return "الوثائقية والثقافية";
      case 7:
        return "القنوات الترفيهية";
      case 8:
        return "الباقة العالمية الرياضية 🏆";
      default:
        return "المجموعة المخصصة";
    }
  }

  static String getSectionLogo(int index) {
    if (_customSectionLogos.containsKey(index)) {
      return _customSectionLogos[index]!;
    }
    return "";
  }

  Future<void> fetchDynamicSections() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Fetch config.json first from GitHub
      try {
        final configRes = await http.get(Uri.parse('$_serverBaseUrl/api/config?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 5));
        Map<String, dynamic>? blockData;
        if (configRes.statusCode == 200) {
          final Map<String, dynamic> configData = json.decode(configRes.body);
          if (configData.containsKey('blocking')) {
            blockData = Map<String, dynamic>.from(configData['blocking']);
          }
        }
        
        // Fallback to blocked_versions.json if config.json or blocking key is missing
        if (blockData == null) {
          final blockRes = await http.get(Uri.parse('$_serverBaseUrl/api/blocked-versions?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 5));
          if (blockRes.statusCode == 200) {
            blockData = json.decode(blockRes.body);
          }
        }

        if (blockData != null) {
          bool isBlocked = false;
          
          if (blockData.containsKey('blocked_version_codes')) {
            final List codes = blockData['blocked_version_codes'] as List;
            if (codes.contains(APP_VERSION_CODE)) {
              isBlocked = true;
            }
          }
          if (blockData.containsKey('min_version_code')) {
            final int minVer = int.tryParse(blockData['min_version_code'].toString()) ?? 0;
            if (APP_VERSION_CODE < minVer) {
              isBlocked = true;
            }
          }
          if (blockData.containsKey('block_all_old_versions')) {
            final bool blockAll = blockData['block_all_old_versions'] == true;
            if (blockAll && APP_VERSION_CODE < 144) {
              isBlocked = true;
            }
          }

          if (blockData.containsKey('block_message')) {
            _remoteBlockMessage = blockData['block_message'].toString();
          } else if (blockData.containsKey('message_body')) {
            _remoteBlockMessage = blockData['message_body'].toString();
          }

          if (_isVersionBlocked != isBlocked) {
            _isVersionBlocked = isBlocked;
            notifyListeners();
          }
        }
      } catch (e) {
        print("Error fetching config.json or blocked_versions.json: $e");
      }

      // Load cached sections first
      final cached = prefs.getString('custom_sections_config');
      if (cached != null) {
        final Map<String, dynamic> parsed = json.decode(cached);
        parsed.forEach((k, v) {
          final idx = int.tryParse(k.replaceAll('section_', ''));
          if (idx != null) {
            if (v is Map) {
              _customSections[idx] = v['name']?.toString() ?? "";
              _customSectionLogos[idx] = v['logo']?.toString() ?? "";
            } else {
              _customSections[idx] = v.toString();
              _customSectionLogos[idx] = "";
            }
          }
        });
      }

      // 2. Fetch freshly from GitHub sections.json (one central file!)
      final res = await http.get(Uri.parse('$_serverBaseUrl/api/sections?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(res.body);
        
        // Also support fallback local check if blocked_versions.json failed to load
        if (parsed.containsKey('min_version_code') && !_isVersionBlocked) {
          final minVer = int.tryParse(parsed['min_version_code'].toString()) ?? 125;
          if (APP_VERSION_CODE < minVer) {
            _isVersionBlocked = true;
            notifyListeners();
          }
        }

        bool changed = false;
        parsed.forEach((k, v) {
          final idx = int.tryParse(k.replaceAll('section_', ''));
          if (idx != null) {
            String name = "";
            String logo = "";
            if (v is Map) {
              name = v['name']?.toString() ?? "";
              logo = v['logo']?.toString() ?? "";
            } else {
              name = v.toString();
            }
            if (_customSections[idx] != name || _customSectionLogos[idx] != logo) {
              _customSections[idx] = name;
              _customSectionLogos[idx] = logo;
              changed = true;
            }
          }
        });

        if (changed || cached == null) {
          await prefs.setString('custom_sections_config', res.body);
          if (_activePlaylistId != null) {
            await loadPlaylistStreams(_activePlaylistId!);
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // Load Custom Pro Streams (سيرفرات البث الخاص)
  Future<void> _loadCustomProStreams() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('custom_pro_streams');
    if (raw != null) {
      try {
        final List parsed = json.decode(raw);
        _customProStreams = parsed.map((e) => PlaylistItem.fromJson(e)).toList();
      } catch (_) {
        _loadDefaultCustomProStreams();
      }
    } else {
      _loadDefaultCustomProStreams();
    }
  }

  Future<void> _loadDefaultCustomProStreams() async {
    // Dynamically fetch from backend instead of hardcoding
    try {
      final res = await http.get(Uri.parse('$_serverBaseUrl/api/custom-streams?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List parsed = json.decode(res.body);
        _customProStreams = parsed.map((e) => PlaylistItem.fromJson(e)).toList();
        await _saveCustomProStreams();
        notifyListeners();
      }
    } catch (_) {
      // If backend fails, clear instead of showing old hardcoded ones
      _customProStreams = [];
      await _saveCustomProStreams();
      notifyListeners();
    }
  }

  Future<void> _saveCustomProStreams() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(_customProStreams.map((e) => e.toJson()).toList());
    await prefs.setString('custom_pro_streams', raw);
  }

  Future<void> addCustomProStream({
    required String name,
    required String url,
    required String category,
    String? logo,
    String? userAgent,
    String? referer,
    String? categoryId,
  }) async {
    final newStream = PlaylistItem(
      num: _customProStreams.length + 1,
      streamId: 'local_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      streamIcon: logo?.trim().isNotEmpty == true ? logo!.trim() : 'https://i.postimg.cc/3JkK0vGw/be-IN-SPORTS-MAX1-DIGITAL-Mono.png',
      categoryId: categoryId ?? 'custom_pro_1',
      categoryName: category.trim().isNotEmpty ? category.trim() : '✅ قنوات مخصصة مضافة',
      url: url.trim(),
      type: 'live',
      customUserAgent: userAgent?.trim().isNotEmpty == true ? userAgent!.trim() : null,
      customReferer: referer?.trim().isNotEmpty == true ? referer!.trim() : null,
    );

    _customProStreams.insert(0, newStream);
    await _saveCustomProStreams();
    notifyListeners();
  }

  Future<void> deleteCustomProStream(String streamId) async {
    _customProStreams.removeWhere((item) => item.streamId == streamId);
    await _saveCustomProStreams();
    notifyListeners();
  }

  IPTVProvider() {
    _loadInitialState();
    _checkVpnStatus();
    checkSecurity();
    // Start periodic VPN and security checking every 10 seconds to prevent bypasses
    Timer.periodic(const Duration(seconds: 10), (_) {
      _checkVpnStatus();
      checkSecurity();
    });
  }

  void _buildStreamsCache() {
    _streamsByTypeAndCategory.clear();
    for (final stream in _allStreams) {
      final typeKey = stream.type; // "live", "movie", "series"
      final catIdKey = stream.categoryId;
      
      final compositeKey = "${typeKey}_$catIdKey";
      _streamsByTypeAndCategory.putIfAbsent(compositeKey, () => []).add(stream);
      _streamsByTypeAndCategory.putIfAbsent(typeKey, () => []).add(stream);
    }
  }

  Future<void> checkSecurity() async {
    try {
      final Map? result = await _securityChannel.invokeMapMethod('checkSecurity');
      if (result != null) {
        final shouldBlock = result['shouldBlock'] == true;
        if (_snifferDetected != shouldBlock) {
          _snifferDetected = shouldBlock;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Security check failed or not supported: $e");
    }
  }

  Future<void> _checkVpnStatus() async {
    try {
      bool detected = false;
      
      // 1. Detect System HTTP/HTTPS Proxies (Fiddler, Charles, Reqable, etc.)
      try {
        final systemProxy = HttpClient.findProxyFromEnvironment(Uri.parse(_serverBaseUrl));
        if (systemProxy != "DIRECT" && systemProxy.trim().isNotEmpty) {
          detected = true;
        }
      } catch (_) {}

      // 2. Detect VPN and Sniffing Network Interfaces (Excluding 'tap' and 'proxy' to prevent false-positives on TV boxes, Firesticks, and Emulators)
      if (!detected) {
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
              name.contains('wg1')) {
            detected = true;
            break;
          }
        }
      }

      if (_vpnDetected != detected) {
        _vpnDetected = detected;
        notifyListeners();
      }
      
      if (detected) {
        exit(0);
      }
    } catch (_) {
      _vpnDetected = false;
    }
  }

  Future<void> retryVpnCheck() async {
    await _checkVpnStatus();
    await checkSecurity();
    notifyListeners();
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

  Future<void> _checkRemoteActivationStatus() async {
    if (_activationCode.isEmpty) return;
    try {
      final deviceId = await _getDeviceId();
      final url = Uri.parse("https://iptv-player-fa64f.web.app/api/check-status");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "code": _activationCode,
          "deviceId": deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data['kill_switch'] == true || data['status'] == 'disabled' || data['status'] == 'expired') {
            final prefs = await SharedPreferences.getInstance();
            _isLoggedIn = false;
            await prefs.setBool('is_logged_in', false);
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  String _decryptUrl(String input) {
    final cleanInput = input.trim();
    String result = cleanInput;
    if (cleanInput.startsWith("enc:")) {
      try {
        final encBody = cleanInput.substring(4).trim();
        final decodedBytes = base64.decode(encBody);
        // Obfuscated key representation of "@IPTV_Secure_Key_2026_@"
        final List<int> kParts = [64, 73, 80, 84, 86, 95, 83, 101, 99, 117, 114, 101, 95, 75, 101, 121, 95, 50, 48, 50, 54, 95, 64];
        final key = String.fromCharCodes(kParts);
        final decryptedBytes = List<int>.generate(decodedBytes.length, (i) {
          return decodedBytes[i] ^ key.codeUnitAt(i % key.length);
        });
        result = utf8.decode(decryptedBytes);
      } catch (_) {
        result = cleanInput;
      }
    }
    return result;
  }

  Future<void> _loadInitialState() async {
    _isLoading = true;
    notifyListeners();

    await fetchDynamicSections();
    await _loadFavorites();
    await _loadPlaylists();

    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // Load active subscription configuration
    _activationCode = prefs.getString('active_code') ?? "";
    _activationTime = prefs.getInt('active_code_activated_at') ?? 0;
    _activationDurationHours = prefs.getInt('active_code_duration_hours') ?? 0;
    _subscriptionType = prefs.getString('active_code_sub_name') ?? "";

    // Block any version that has activation code 69743190
    if (_activationCode.trim() == "69743190") {
      _isVersionBlocked = true;
    }

    // Verify app name - Block if not "live strem pro"
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final nameClean = packageInfo.appName.toLowerCase().replaceAll(' ', '');
      if (!nameClean.contains("livestrempro") && !nameClean.contains("livestreampro")) {
        _isVersionBlocked = true;
      }
    } catch (_) {}

    if (_isLoggedIn && isExpired) {
      // Log out immediately if expired
      _isLoggedIn = false;
      await prefs.setBool('is_logged_in', false);
    }

    // Ensure default VIP playlist is restored and loaded regardless of login status
    UserPlaylist? vipList;
    if (_activationCode.isNotEmpty) {
      try {
        final xtreamsMap = await _fetchGitHubXtreamsMap();
        if (xtreamsMap != null && xtreamsMap.containsKey(_activationCode)) {
          final serverConfig = xtreamsMap[_activationCode];
          if (serverConfig is Map) {
            final isGithubType = serverConfig['type'] == 'github';
            if (isGithubType) {
              vipList = UserPlaylist(
                id: "vip_9xtream",
                name: serverConfig['name']?.toString() ?? "live strem pro ⚡",
                type: "github",
                host: "https://github.com",
                username: "github_user",
                password: "github_password",
              );
            } else {
              final host = _decryptUrl(serverConfig['host']?.toString() ?? '');
              final username = _decryptUrl(serverConfig['username']?.toString() ?? '');
              final password = _decryptUrl(serverConfig['password']?.toString() ?? '');
              vipList = UserPlaylist(
                id: "vip_9xtream",
                name: serverConfig['name']?.toString() ?? "سيرفر VIP السحابي 💎",
                type: "xtream",
                host: host,
                username: username,
                password: password,
              );
            }
          }
        }
      } catch (_) {}
    }

    if (vipList != null) {
      _savedPlaylists.removeWhere((p) => p.id == "vip_9xtream");
      _savedPlaylists.insert(0, vipList);
      await _savePlaylists();
      
      if (_activePlaylistId == null || !_savedPlaylists.any((p) => p.id == _activePlaylistId)) {
        _activePlaylistId = "vip_9xtream";
      }
    }

    // Always load active streams to support unlocked/no-login configurations gracefully
    await loadPlaylistStreams(_activePlaylistId!);

    await _loadEngineSettings();
    await _loadCustomProStreams();
    fetchGitHubNotifications();
    if (_isLoggedIn && _activationCode.isNotEmpty) {
      _checkRemoteActivationStatus();
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setTab(String tab) {
    _activeTab = tab;
    _selectedCategory = "all";
    _applyFilters();
    notifyListeners();
  }

  Future<void> setCategory(String category) async {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
    await _loadCategoryStreamsIfNeeded(category);
  }

  Future<void> _loadCategoryStreamsIfNeeded(String categoryName) async {
    // Both 8 sections and M3U streams are fully preloaded at startup, no lazy load needed.
    return;
  }

  void selectStream(PlaylistItem item) {
    _currentStream = item;
    notifyListeners();
  }

  void toggleFavorite(String streamId) {
    if (_favorites.contains(streamId)) {
      _favorites.remove(streamId);
    } else {
      _favorites.add(streamId);
    }
    _saveFavorites();
    _applyFilters();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _fetchGitHubConfig() async {
    try {
      final res = await http.get(Uri.parse('$_serverBaseUrl/api/config?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(res.body);
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchGitHubXtreamsMap() async {
    try {
      final config = await _fetchGitHubConfig();
      if (config != null && config.containsKey('xtreams')) {
        return Map<String, dynamic>.from(config['xtreams']);
      }
    } catch (_) {}
    // Fallback to config endpoint as well for unified API config
    try {
      final res = await http.get(Uri.parse('$_serverBaseUrl/api/config?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(res.body);
        if (decoded.containsKey('xtreams')) {
          return Map<String, dynamic>.from(decoded['xtreams']);
        }
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> loginWithActivation(String code) async {
    String cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      final deviceId = await _getDeviceId();
      final url = Uri.parse("https://iptv-player-fa64f.web.app/api/activate");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "code": cleanCode,
          "deviceId": deviceId,
          "versionCode": APP_VERSION_CODE,
        }),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 202 || data['isPending'] == true) {
        _activationError = data['message'] ?? "تم استلام طلب تسجيل الدخول بنجاح. تم إرسال طلبك إلى الإدارة، يرجى الانتظار حتى تتم الموافقة على حسابك.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (response.statusCode == 403 && data['isRejected'] == true) {
        _activationError = data['error'] ?? "تم رفض طلب تسجيل الدخول. يرجى التواصل مع الإدارة إذا كنت تعتقد أن ذلك حدث بالخطأ.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (response.statusCode == 200 && data['success'] == true) {
          final int durationHours = data['durationHours'] ?? -1;
          final String subName = data['subName'] ?? "سيرفر VIP السحابي 💎";
          final String name = data['name'] ?? "live strem pro ⚡";
          
          UserPlaylist list;
          if (data['type'] == 'xtream') {
            final host = _decryptUrl(data['host']);
            final username = _decryptUrl(data['username']);
            final password = _decryptUrl(data['password']);
            
            list = UserPlaylist(
              id: "vip_9xtream",
              name: name,
              type: "xtream",
              host: host,
              username: username,
              password: password,
            );
          } else {
            list = UserPlaylist(
              id: "vip_9xtream",
              name: name,
              type: "github",
              host: "https://github.com",
              username: "github_user",
              password: "github_password",
            );
          }

          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now().millisecondsSinceEpoch;
          
          await prefs.setString('active_code', cleanCode);
          await prefs.setInt('active_code_activated_at', data['activatedAt'] ?? now);
          await prefs.setInt('active_code_duration_hours', durationHours);
          await prefs.setString('active_code_sub_name', subName);
          await prefs.setInt('active_code_expires_at', data['expiresAt'] ?? -1);

          _activationCode = cleanCode;
          _activationTime = data['activatedAt'] ?? now;
          _activationDurationHours = durationHours;
          _subscriptionType = subName;

          _savedPlaylists.removeWhere((p) => p.id == "vip_9xtream");
          _savedPlaylists.insert(0, list);
          _activePlaylistId = list.id;
          await _savePlaylists();
          await prefs.setBool('is_logged_in', true);
          _isLoggedIn = true;

          await loadPlaylistStreams(list.id);

          _isLoading = false;
          notifyListeners();
          return true;
      }
    } catch (e) {
      debugPrint("Secure activation error: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String host, String username, String password, {String name = ""}) async {
    // Deprecated Custom Xtream Code Setup
    return false;
  }

  Future<void> loginM3u(String name, String m3uContent) async {
    final list = UserPlaylist(
      id: "m3u_${DateTime.now().millisecondsSinceEpoch}",
      name: name.isNotEmpty ? name : "My M3U Playlist",
      type: "m3u",
    );

    _isLoading = true;
    notifyListeners();

    _savedPlaylists.removeWhere((p) => p.id == list.id);
    _savedPlaylists.insert(0, list);
    _activePlaylistId = list.id;
    await _savePlaylists();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('m3u_content_${list.id}', m3uContent);
    await prefs.setBool('is_logged_in', true);

    await prefs.setString('active_code', "GUEST_M3U");
    await prefs.setInt('active_code_activated_at', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('active_code_duration_hours', -1);
    await prefs.setString('active_code_sub_name', "قائمة تشغيل ملف M3U");

    _activationCode = "GUEST_M3U";
    _activationTime = DateTime.now().millisecondsSinceEpoch;
    _activationDurationHours = -1;
    _subscriptionType = "قائمة تشغيل ملف M3U";

    _isLoggedIn = true;
    await loadPlaylistStreams(list.id);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loginAsGuest() async {
    _isLoading = true;
    notifyListeners();

    _savedPlaylists.removeWhere((p) => p.id == "demo_playlists");
    final list = UserPlaylist(
      id: "demo_playlists",
      name: "IPTV Demo Streams",
      type: "m3u",
    );
    _savedPlaylists.insert(0, list);
    _activePlaylistId = list.id;
    await _savePlaylists();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);

    await prefs.setString('active_code', "FREE_GUEST");
    await prefs.setInt('active_code_activated_at', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('active_code_duration_hours', -1);
    await prefs.setString('active_code_sub_name', "الولوج كزائر مجاني");

    _activationCode = "FREE_GUEST";
    _activationTime = DateTime.now().millisecondsSinceEpoch;
    _activationDurationHours = -1;
    _subscriptionType = "الولوج كزائر مجاني";

    _isLoggedIn = true;
    await loadDemoPlaylist();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('active_playlist_id');
    await prefs.remove('active_code');
    await prefs.remove('active_code_activated_at');
    await prefs.remove('active_code_duration_hours');
    await prefs.remove('active_code_sub_name');

    _isLoggedIn = false;
    _activePlaylistId = null;
    _activationCode = "";
    _activationTime = 0;
    _activationDurationHours = 0;
    _subscriptionType = "";

    _allStreams.clear();
    _categories.clear();
    _currentStream = null;
    _applyFilters();
    notifyListeners();
  }

  Future<void> addPlaylist(UserPlaylist playlist, {String? m3uContent}) async {
    _savedPlaylists.add(playlist);
    _activePlaylistId = playlist.id;
    await _savePlaylists();

    final prefs = await SharedPreferences.getInstance();
    if (m3uContent != null) {
      await prefs.setString('m3u_content_${playlist.id}', m3uContent);
    }

    _isLoading = true;
    notifyListeners();
    await loadPlaylistStreams(playlist.id);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _savedPlaylists.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('m3u_content_$id');
    
    if (_activePlaylistId == id) {
      _activePlaylistId = _savedPlaylists.isNotEmpty ? _savedPlaylists[0].id : null;
    }
    await _savePlaylists();

    if (_activePlaylistId != null) {
      await loadPlaylistStreams(_activePlaylistId!);
    } else {
      _allStreams.clear();
      _categories.clear();
      _currentStream = null;
      _applyFilters();
    }
    notifyListeners();
  }

  Future<Map<String, String>?> _fetchGitHubXtream() async {
    try {
      final res = await http.get(Uri.parse('$_serverBaseUrl/api/xtream-credentials?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(res.body);
        return {
          'host': _decryptUrl(decoded['host']?.toString() ?? ''),
          'username': _decryptUrl(decoded['username']?.toString() ?? ''),
          'password': _decryptUrl(decoded['password']?.toString() ?? ''),
        };
      }
    } catch (_) {}
    return null;
  }

  Future<List<PlaylistItem>> _fetchGitHubPlaylist(String url, String type) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List decoded = json.decode(res.body);
        return decoded.map<PlaylistItem>((item) {
          return PlaylistItem(
            num: item['num'] is int ? item['num'] : null,
            streamId: 'git_${type}_${item['stream_id'] ?? item['streamId'] ?? (item['name'] ?? item['url'] ?? 'ch').toString().hashCode}',
            name: item['name']?.toString() ?? 'قناة GitHub مخصصة',
            streamIcon: item['stream_icon']?.toString() ?? item['streamIcon']?.toString() ?? '',
            categoryId: item['category_id']?.toString() ?? item['categoryId']?.toString() ?? 'git_custom',
            categoryName: item['category_name']?.toString() ?? item['categoryName']?.toString() ?? 'قنوات GitHub',
            url: _decryptUrl(item['url']?.toString() ?? ''),
            type: type,
            rating: item['rating']?.toString(),
            year: item['year']?.toString(),
            duration: item['duration']?.toString(),
            plot: item['plot']?.toString(),
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> loadPlaylistStreams(String id) async {
    final playlist = _savedPlaylists.firstWhere((p) => p.id == id, orElse: () => UserPlaylist(id: '', name: '', type: ''));
    if (playlist.id.isEmpty) return;

    _activePlaylistId = id;
    
    final prefs = await SharedPreferences.getInstance();

    if (playlist.type == "xtream") {
      // 1. Try to load cached streams and categories immediately for 0ms delay on weak internet
      final cachedStreamsJson = prefs.getString('cached_streams_$id');
      final cachedCatsJson = prefs.getString('cached_cats_$id');
      
      final cachedLiveCats = prefs.getString('cached_live_cats_$id');
      final cachedMovieCats = prefs.getString('cached_movie_cats_$id');
      final cachedSeriesCats = prefs.getString('cached_series_cats_$id');
      final cachedLoadedCatIds = prefs.getStringList('cached_loaded_cat_ids_$id');

      bool hasLocalCache = false;
      
      if (cachedLiveCats != null && cachedMovieCats != null && cachedSeriesCats != null) {
        try {
          final List decodedLive = json.decode(cachedLiveCats);
          final List decodedMovie = json.decode(cachedMovieCats);
          final List decodedSeries = json.decode(cachedSeriesCats);
          
          _liveCategories = decodedLive.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
          _movieCategories = decodedMovie.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
          _seriesCategories = decodedSeries.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
          
          if (cachedLoadedCatIds != null) {
            _loadedCategoryIds.clear();
            _loadedCategoryIds.addAll(cachedLoadedCatIds);
          }
        } catch (_) {}
      }

      if (cachedStreamsJson != null) {
        try {
          final List decodedStreams = json.decode(cachedStreamsJson);
          _allStreams = decodedStreams.map<PlaylistItem>((item) => PlaylistItem.fromJson(item)).toList();
          _buildStreamsCache();
          
          if (cachedCatsJson != null) {
            final List decodedCats = json.decode(cachedCatsJson);
            _categories = decodedCats.map<String>((e) => e.toString()).toList();
          }
          
          if (_allStreams.isNotEmpty) {
            _currentStream = _allStreams[0];
            hasLocalCache = true;
            _applyFilters();
            notifyListeners();
          }
        } catch (_) {}
      }

      if (!hasLocalCache) {
        _allStreams.clear();
        _streamsByTypeAndCategory.clear();
        _categories.clear();
        _liveCategories.clear();
        _movieCategories.clear();
        _seriesCategories.clear();
        _loadedCategoryIds.clear();
      }
      
      // 2. Fetch freshly from the Xtream server in the background using Player API
      try {
        final host = (playlist.host ?? '').trim();
        final user = (playlist.username ?? '').trim();
        final pass = (playlist.password ?? '').trim();
        
        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          final liveCatsFuture = http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 15));
          final liveStreamsFuture = http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 25));
          final vodCatsFuture = http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_categories")).timeout(const Duration(seconds: 15));
          final vodStreamsFuture = http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_streams")).timeout(const Duration(seconds: 25));
          final seriesCatsFuture = http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series_categories")).timeout(const Duration(seconds: 15));
          final seriesFuture = http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series")).timeout(const Duration(seconds: 25));

          final responses = await Future.wait([
            liveCatsFuture,
            liveStreamsFuture,
            vodCatsFuture,
            vodStreamsFuture,
            seriesCatsFuture,
            seriesFuture
          ]);

          List<Map<String, String>> tempLiveCats = [];
          if (responses[0].statusCode == 200) {
            final List decoded = json.decode(responses[0].body);
            tempLiveCats = decoded.map<Map<String, String>>((item) {
              return {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              };
            }).toList();
          }

          List<PlaylistItem> tempStreams = [];
          if (responses[1].statusCode == 200) {
            final List decoded = json.decode(responses[1].body);
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
                url: "$host/live/$user/$pass/$streamId.ts",
                type: "live",
              ));
            }
          }

          List<Map<String, String>> tempVodCats = [];
          if (responses[2].statusCode == 200) {
            final List decoded = json.decode(responses[2].body);
            tempVodCats = decoded.map<Map<String, String>>((item) {
              return {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              };
            }).toList();
          }

          if (responses[3].statusCode == 200) {
            final List decoded = json.decode(responses[3].body);
            for (final item in decoded) {
              final catId = item['category_id']?.toString() ?? '';
              final cat = tempVodCats.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
              final catName = cat.isNotEmpty ? cat['category_name']! : 'أفلام';
              final streamId = item['stream_id']?.toString() ?? '';
              final container = item['container_extension']?.toString() ?? 'mp4';
              tempStreams.add(PlaylistItem(
                num: item['num'] is int ? item['num'] : null,
                streamId: "movie_$streamId",
                name: item['name']?.toString() ?? '',
                streamIcon: item['stream_icon']?.toString() ?? '',
                categoryId: catId,
                categoryName: catName,
                url: "$host/movie/$user/$pass/$streamId.$container",
                type: "movie",
                rating: item['rating']?.toString(),
                plot: item['plot']?.toString(),
              ));
            }
          }

          List<Map<String, String>> tempSeriesCats = [];
          if (responses[4].statusCode == 200) {
            final List decoded = json.decode(responses[4].body);
            tempSeriesCats = decoded.map<Map<String, String>>((item) {
              return {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              };
            }).toList();
          }

          if (responses[5].statusCode == 200) {
            final List decoded = json.decode(responses[5].body);
            for (final item in decoded) {
              final catId = item['category_id']?.toString() ?? '';
              final cat = tempSeriesCats.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
              final catName = cat.isNotEmpty ? cat['category_name']! : 'مسلسلات';
              final seriesId = item['series_id']?.toString() ?? '';
              tempStreams.add(PlaylistItem(
                num: item['num'] is int ? item['num'] : null,
                streamId: "series_$seriesId",
                name: item['name']?.toString() ?? '',
                streamIcon: item['cover']?.toString() ?? item['stream_icon']?.toString() ?? '',
                categoryId: catId,
                categoryName: catName,
                url: "$host/series/$user/$pass/$seriesId",
                type: "series",
                rating: item['rating']?.toString(),
                plot: item['plot']?.toString(),
              ));
            }
          }

          if (tempStreams.isNotEmpty) {
            _allStreams = tempStreams;
            _buildStreamsCache();
            _liveCategories = tempLiveCats;
            _movieCategories = tempVodCats;
            _seriesCategories = tempSeriesCats;

            _categories = [];
            _categories.addAll(_liveCategories.map((c) => c['category_name']!));
            _categories.addAll(_movieCategories.map((c) => c['category_name']!));
            _categories.addAll(_seriesCategories.map((c) => c['category_name']!));

            _loadedCategoryIds.clear();
            _loadedCategoryIds.addAll(_liveCategories.map((c) => c['category_id']!));
            _loadedCategoryIds.addAll(_movieCategories.map((c) => c['category_id']!));
            _loadedCategoryIds.addAll(_seriesCategories.map((c) => c['category_id']!));
            _loadedCategoryIds.add('all');

            if (_allStreams.isNotEmpty && _currentStream == null) {
              _currentStream = _allStreams[0];
            }

            // Cache downloaded data
            await prefs.setString('cached_streams_$id', json.encode(_allStreams.map((e) => e.toJson()).toList()));
            await prefs.setString('cached_cats_$id', json.encode(_categories));
            await prefs.setString('cached_live_cats_$id', json.encode(_liveCategories));
            await prefs.setString('cached_movie_cats_$id', json.encode(_movieCategories));
            await prefs.setString('cached_series_cats_$id', json.encode(_seriesCategories));
            await prefs.setStringList('cached_loaded_cat_ids_$id', _loadedCategoryIds.toList());
          }
        }
      } catch (_) {}
      
      _applyFilters();
      notifyListeners();
      return;
    }

    if (id == "vip_9xtream" && playlist.type == "github") {
      // Force direct 8 layout sections loading.
      _liveCategories = [
        {'category_id': 'custom_pro_1', 'category_name': '${getSectionName(1)} ⚡'},
        {'category_id': 'custom_pro_2', 'category_name': '${getSectionName(2)} ⚡'},
        {'category_id': 'custom_pro_3', 'category_name': '${getSectionName(3)} ⚡'},
        {'category_id': 'custom_pro_4', 'category_name': '${getSectionName(4)} ⚡'},
        {'category_id': 'custom_pro_5', 'category_name': '${getSectionName(5)} ⚡'},
        {'category_id': 'custom_pro_6', 'category_name': '${getSectionName(6)} ⚡'},
        {'category_id': 'custom_pro_7', 'category_name': '${getSectionName(7)} ⚡'},
        {'category_id': 'custom_pro_8', 'category_name': '${getSectionName(8)} ⚡'},
      ];
      _movieCategories = [];
      _seriesCategories = [];
      
      _categories = _liveCategories.map((c) => c['category_name']!).toList();
      _allStreams = await _getCustomSportsStreams();
      _buildStreamsCache();
      _loadedCategoryIds.clear();
      _loadedCategoryIds.addAll({
        'all', 'custom_pro_1', 'custom_pro_2', 'custom_pro_3', 
        'custom_pro_4', 'custom_pro_5', 'custom_pro_6', 'custom_pro_7', 'custom_pro_8'
      });
      
      if (_allStreams.isNotEmpty) {
        _currentStream = _allStreams[0];
      }
      _applyFilters();
      notifyListeners();
      return;
    }
    
    // 1. Try to load cached streams and categories immediately for 0ms delay on weak internet
    final cachedStreamsJson = prefs.getString('cached_streams_$id');
    final cachedCatsJson = prefs.getString('cached_cats_$id');
    
    final cachedLiveCats = prefs.getString('cached_live_cats_$id');
    final cachedMovieCats = prefs.getString('cached_movie_cats_$id');
    final cachedSeriesCats = prefs.getString('cached_series_cats_$id');
    final cachedLoadedCatIds = prefs.getStringList('cached_loaded_cat_ids_$id');

    bool hasLocalCache = false;
    
    if (cachedLiveCats != null && cachedMovieCats != null && cachedSeriesCats != null) {
      try {
        final List decodedLive = json.decode(cachedLiveCats);
        final List decodedMovie = json.decode(cachedMovieCats);
        final List decodedSeries = json.decode(cachedSeriesCats);
        
        _liveCategories = decodedLive.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
        _movieCategories = decodedMovie.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
        _seriesCategories = decodedSeries.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
        
        if (!_liveCategories.any((c) => c['category_id'] == 'world_cup_2026')) {
          _liveCategories.insert(0, {
            'category_id': 'world_cup_2026',
            'category_name': '🏆 كاس العالم 2026',
          });
        }
        
        if (!_liveCategories.any((c) => c['category_id'] == 'my_custom_sports')) {
          _liveCategories.insert(1, {
            'category_id': 'my_custom_sports',
            'category_name': '✅ قنواتي الرياضية الخاصة',
          });
        }
        
        if (cachedLoadedCatIds != null) {
          _loadedCategoryIds.clear();
          _loadedCategoryIds.addAll(cachedLoadedCatIds);
        }
      } catch (_) {}
    }

    if (cachedStreamsJson != null) {
      try {
        final List decodedStreams = json.decode(cachedStreamsJson);
        
        _allStreams = decodedStreams.map<PlaylistItem>((item) => PlaylistItem(
          num: item['num'] is int ? item['num'] : null,
          streamId: item['stream_id']?.toString() ?? item['streamId']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          streamIcon: item['stream_icon']?.toString() ?? item['streamIcon']?.toString() ?? '',
          categoryId: item['category_id']?.toString() ?? item['categoryId']?.toString() ?? '',
          categoryName: item['category_name']?.toString() ?? item['categoryName']?.toString() ?? '',
          url: item['url']?.toString() ?? '',
          type: item['type']?.toString() ?? 'live',
          rating: item['rating']?.toString(),
          year: item['year']?.toString(),
          duration: item['duration']?.toString(),
          plot: item['plot']?.toString(),
        )).toList();
        _buildStreamsCache();
        
        if (cachedCatsJson != null) {
          final List decodedCats = json.decode(cachedCatsJson);
          _categories = decodedCats.map<String>((e) => e.toString()).toList();
        }
        
        if (_allStreams.isNotEmpty) {
          _currentStream = _allStreams[0];
          hasLocalCache = true;
          _applyFilters();
          notifyListeners();
        }
      } catch (_) {}
    }

    if (!hasLocalCache) {
      _allStreams.clear();
      _streamsByTypeAndCategory.clear();
      _categories.clear();
      _liveCategories.clear();
      _movieCategories.clear();
      _seriesCategories.clear();
      _loadedCategoryIds.clear();
    }
    
    // 2. Refresh or fetch the playlist from network in the background or foreground
    try {
      String? m3uContent = prefs.getString('m3u_content_$id');
      if (m3uContent != null) {
        final result = M3UParser.parse(m3uContent);
        _allStreams = List<PlaylistItem>.from(result['items']);
        _buildStreamsCache();
        _categories = List<String>.from(result['categories']);
      }

      if (_allStreams.isNotEmpty && _currentStream == null) {
        _currentStream = _allStreams[0];
      }
    } catch (_) { // fail safe fallback
    }
    _applyFilters();
  }

  Future<void> loadDemoPlaylist() async {
    final demoPlaylist = UserPlaylist(
      id: "vip_9xtream",
      name: "live strem pro ⚡",
      type: "github",
      host: "https://github.com",
      username: "github_user",
      password: "github_password",
    );

    _savedPlaylists.removeWhere((p) => p.id == "vip_9xtream" || p.id == "demo_list");
    _savedPlaylists.add(demoPlaylist);
    _activePlaylistId = "vip_9xtream";
    
    await _savePlaylists();
    await loadPlaylistStreams("vip_9xtream");
  }

  Future<List<PlaylistItem>> _getCustomSportsStreams() async {
    List<PlaylistItem> base = [];
    final prefs = await SharedPreferences.getInstance();
    final cachedSections = prefs.getString('custom_sections_config');
    
    bool loadedFromUnified = false;
    
    // Attempt high-performance single-request load from unified sections.json channels database
    if (cachedSections != null) {
      try {
        final Map<String, dynamic> parsed = json.decode(cachedSections);
        bool hasUnifiedChannels = false;
        parsed.forEach((k, v) {
          if (v is Map && v.containsKey('channels')) {
            hasUnifiedChannels = true;
          }
        });
        
        if (hasUnifiedChannels) {
          int streamCounter = 1;
          final Set<String> seenUrls = {};
          UserPlaylist? activePlaylist;
          if (_activePlaylistId != null) {
            activePlaylist = _savedPlaylists.firstWhere(
              (p) => p.id == _activePlaylistId,
              orElse: () => UserPlaylist(id: '', name: '', type: ''),
            );
          }
          
          parsed.forEach((k, v) {
            final idx = int.tryParse(k.replaceAll('section_', ''));
            if (idx != null && v is Map && v.containsKey('channels')) {
              final String catId = "custom_pro_$idx";
              final String catName = v['name']?.toString() ?? getSectionName(idx);
              final List channels = v['channels'] as List;
              
              for (final item in channels) {
                final rawUrl = (item['url'] ?? item['stream_url'] ?? '')?.toString().trim() ?? '';
                if (rawUrl.isEmpty) continue;
                String url = _decryptUrl(rawUrl);
                
                // Dynamic Xtream Credential Replacement!
                if (activePlaylist != null && activePlaylist.type == "xtream") {
                  final host = (activePlaylist.host ?? '').trim();
                  final user = (activePlaylist.username ?? '').trim();
                  final pass = (activePlaylist.password ?? '').trim();
                  if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      final pathSegments = uri.pathSegments;
                      final urlHost = uri.host.toLowerCase();
                      final isResellerHost = urlHost.contains("max-pro.vip") ||
                                             urlHost.contains("appluxera") ||
                                             urlHost.contains("kalaasmr.blog") ||
                                             urlHost.contains("active-pro");
                      if (pathSegments.length >= 4 && pathSegments[0] == "live" && isResellerHost) {
                        final streamIdAndExt = pathSegments.sublist(3).join('/');
                        url = "$host/live/$user/$pass/$streamIdAndExt";
                      }
                    }
                  }
                }
                
                final normUrl = url.toLowerCase();
                if (seenUrls.contains(normUrl)) continue;
                seenUrls.add(normUrl);
                
                // Parse headers
                final ua = (item['user_agent'] ?? item['userAgent'] ?? item['customUserAgent'] ?? item['User-Agent'])?.toString();
                final ref = (item['referer'] ?? item['customReferer'] ?? item['Referer'])?.toString();

                // Parse clear keys for DRM / MPD
                Map<String, String>? clearKeys;
                if (item['clearKeys'] != null || item['clear_keys'] != null || item['keys'] != null) {
                  final rawKeys = item['clearKeys'] ?? item['clear_keys'] ?? item['keys'];
                  if (rawKeys is Map) {
                    clearKeys = {};
                    rawKeys.forEach((k, v) {
                      clearKeys![k.toString()] = v.toString();
                    });
                  } else if (rawKeys is String && rawKeys.contains(':')) {
                    final parts = rawKeys.split(':');
                    if (parts.length >= 2) {
                      clearKeys = {parts[0].trim(): parts[1].trim()};
                    }
                  }
                }
                
                base.add(PlaylistItem(
                  num: streamCounter,
                  streamId: 'git_custom_stream_${streamCounter}_${(item['name'] ?? url).toString().hashCode}',
                  name: item['name']?.toString() ?? 'قناة مخصصة $streamCounter',
                  streamIcon: item['icon']?.toString() ?? item['stream_icon']?.toString() ?? item['streamIcon']?.toString() ?? 'https://i.postimg.cc/3JkK0vGw/be-IN-SPORTS-MAX1-DIGITAL-Mono.png',
                  categoryId: catId,
                  categoryName: '$catName ⚡',
                  url: url,
                  type: 'live',
                  customUserAgent: ua?.trim().isNotEmpty == true ? ua : null,
                  customReferer: ref?.trim().isNotEmpty == true ? ref : null,
                  clearKeys: clearKeys,
                ));
                streamCounter++;
              }
            }
          });
          
          if (base.isNotEmpty) {
            loadedFromUnified = true;
          }
        }
      } catch (_) {}
    }
    
    if (loadedFromUnified) {
      return base;
    }
    
    // Multiple customized files from GitHub containing dynamic IPTV lists (Legacy Fallback)
    final List<Map<String, String>> targets = [
      {
        'url': '$_serverBaseUrl/api/playlist/Match_time.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_1',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/kids.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_2',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/news.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_3',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/sports_arabic.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_4',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/islamic.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_5',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/cultural.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_6',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/entertainment.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_7',
      },
      {
        'url': '$_serverBaseUrl/api/playlist/bein.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'defaultCatId': 'custom_pro_8',
      },
    ];

    int streamCounter = 1;
    final Set<String> seenUrls = {};

    UserPlaylist? activePlaylist;
    if (_activePlaylistId != null) {
      activePlaylist = _savedPlaylists.firstWhere(
        (p) => p.id == _activePlaylistId,
        orElse: () => UserPlaylist(id: '', name: '', type: ''),
      );
    }

    for (final target in targets) {
      try {
        final res = await http.get(Uri.parse(target['url']!)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final List decoded = json.decode(res.body);
          for (final item in decoded) {
            final rawUrl = (item['url'] ?? item['stream_url'] ?? '')?.toString().trim() ?? '';
            if (rawUrl.isEmpty) continue;
            String url = _decryptUrl(rawUrl);

            // Dynamic Xtream Credential Replacement!
            if (activePlaylist != null && activePlaylist.type == "xtream") {
              final host = (activePlaylist.host ?? '').trim();
              final user = (activePlaylist.username ?? '').trim();
              final pass = (activePlaylist.password ?? '').trim();
              if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  final pathSegments = uri.pathSegments;
                  final urlHost = uri.host.toLowerCase();
                  final isResellerHost = urlHost.contains("max-pro.vip") ||
                                         urlHost.contains("appluxera") ||
                                         urlHost.contains("kalaasmr.blog") ||
                                         urlHost.contains("active-pro");
                  if (pathSegments.length >= 4 && pathSegments[0] == "live" && isResellerHost) {
                    final streamIdAndExt = pathSegments.sublist(3).join('/');
                    url = "$host/live/$user/$pass/$streamIdAndExt";
                  }
                }
              }
            }
            
            // Skip duplicates to prevent mixing categories with duplicate entries
            final normUrl = url.toLowerCase();
            if (seenUrls.contains(normUrl)) continue;
            seenUrls.add(normUrl);

            final catId = (item['category_id'] ?? item['categoryId'] ?? target['defaultCatId'])!.toString();
            
            // Parse dynamic section name
            final parsedIdx = int.tryParse(catId.replaceAll('custom_pro_', ''));
            String catName = parsedIdx != null ? getSectionName(parsedIdx) : 'قنوات مخصصة';
            final String? jsonCatName = (item['category_name'] ?? item['categoryName'] ?? item['category'] ?? item['categoryName_ar'])?.toString();
            if (jsonCatName != null && jsonCatName.trim().isNotEmpty) {
              catName = jsonCatName.trim();
            }

            // Parse headers
            final ua = (item['user_agent'] ?? item['userAgent'] ?? item['customUserAgent'] ?? item['User-Agent'])?.toString();
            final ref = (item['referer'] ?? item['customReferer'] ?? item['Referer'])?.toString();

            // Parse clear keys for DRM / MPD
            Map<String, String>? clearKeys;
            if (item['clearKeys'] != null || item['clear_keys'] != null || item['keys'] != null) {
              final rawKeys = item['clearKeys'] ?? item['clear_keys'] ?? item['keys'];
              if (rawKeys is Map) {
                clearKeys = {};
                rawKeys.forEach((k, v) {
                  clearKeys![k.toString()] = v.toString();
                });
              } else if (rawKeys is String && rawKeys.contains(':')) {
                final parts = rawKeys.split(':');
                if (parts.length >= 2) {
                  clearKeys = {parts[0].trim(): parts[1].trim()};
                }
              }
            }

            base.add(PlaylistItem(
              num: streamCounter,
              streamId: 'git_custom_stream_${streamCounter}_${(item['name'] ?? url).toString().hashCode}',
              name: item['name']?.toString() ?? 'قناة مخصصة ${streamCounter}',
              streamIcon: item['icon']?.toString() ?? item['stream_icon']?.toString() ?? item['streamIcon']?.toString() ?? 'https://i.postimg.cc/3JkK0vGw/be-IN-SPORTS-MAX1-DIGITAL-Mono.png',
              categoryId: catId,
              categoryName: '$catName ⚡',
              url: url,
              type: 'live',
              customUserAgent: ua?.trim().isNotEmpty == true ? ua : null,
              customReferer: ref?.trim().isNotEmpty == true ? ref : null,
              clearKeys: clearKeys,
            ));
            streamCounter++;
          }
        }
      } catch (_) {
        // Safe fail-fast wrapper per file
      }
    }

    final List<Map<String, dynamic>> fallbackData = [
      // Category 1: مباريات تعمل وقت المباريات (Sports 1-8)
      {
        'name': 'الرياضيه الاولى HD ⚡',
        'url': 'https://fra-prod-catalyst-0.lp-playback.studio/hls/video+0df1wiv0fh9wymbb/index.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه الثانيه HD ⚡',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه الثالثه HD ⚡',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه الرابعه HD ⚡',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه الخامسة HD ⚡',
        'url': 'https://a6.kora-plus.app/watch/tsn1.m3u8?token=rxLxv2MPZC4xS89AQuu7rWJ6Kb4&exp=1781716414',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه السادسه HD ⚡',
        'url': 'http://185.160.192.14/live/171348492752/5S6HGsea3j/255243.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه السابعه HD ⚡',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'الرياضيه الثامنه HD ⚡',
        'url': 'https://s3.us-east-2.amazonaws.com/cdnh118/hls/0/stream.m3u8',
        'catId': 'custom_pro_1',
        'icon': 'https://iili.io/CK5M0pR.png',
      },

      // Category 2: أفلام وقنوات أطفال
      {
        'name': 'سبيستون Spacetoon HD 🚀',
        'url': 'https://cn-arabic-live.fastly.gph.io/live/index.m3u8',
        'catId': 'custom_pro_2',
        'icon': 'https://i.postimg.cc/mD8zHjJ6/spacetoon.png',
      },
      {
        'name': 'قناة كرتون نتورك Cartoon Network 🎈',
        'url': 'https://cn-arabic-live.fastly.gph.io/live/index.m3u8',
        'catId': 'custom_pro_2',
        'icon': 'https://img.icons8.com/color/120/cartoon-network.png',
      },
      {
        'name': 'قناة ماجد للأطفال Majid Kids 🎮',
        'url': 'https://cn-arabic-live.fastly.gph.io/live/index.m3u8',
        'catId': 'custom_pro_2',
        'icon': 'https://img.icons8.com/color/120/children.png',
      },
      {
        'name': 'قناة طيور الجنة للأطفال 🦜',
        'url': 'https://cn-arabic-live.fastly.gph.io/live/index.m3u8',
        'catId': 'custom_pro_2',
        'icon': 'https://img.icons8.com/color/120/parrot.png',
      },
      {
        'name': 'قناة ام بي سي 3 للأطفال MBC 3 ⭐️',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/nat_geo.m3u8',
        'catId': 'custom_pro_2',
        'icon': 'https://img.icons8.com/color/120/star.png',
      },
      {
        'name': 'قناة براعم للأطفال Baraem 🧸',
        'url': 'https://cn-arabic-live.fastly.gph.io/live/index.m3u8',
        'catId': 'custom_pro_2',
        'icon': 'https://img.icons8.com/color/120/teddy-bear.png',
      },

      // Category 3: قنوات الأخبار والأحداث
      {
        'name': 'الجزيرة الإخبارية Al Jazeera News 🌍',
        'url': 'https://live-hls-web-aje.getaj.net/AJE/index.m3u8',
        'catId': 'custom_pro_3',
        'icon': 'https://img.icons8.com/color/120/al-jazeera.png',
      },
      {
        'name': 'العربية الإخبارية Al Arabiya HD 📣',
        'url': 'https://mbc-live-push.cdb.cdn.orange.com/mbc_alarabiya/index.m3u8',
        'catId': 'custom_pro_3',
        'icon': 'https://img.icons8.com/fluency/120/news.png',
      },
      {
        'name': 'الحدث الإخبارية Al Hadath News 🚨',
        'url': 'https://mbc-live-push.cdb.cdn.orange.com/mbc_alhadath/index.m3u8',
        'catId': 'custom_pro_3',
        'icon': 'https://img.icons8.com/color/120/hazard--v1.png',
      },
      {
        'name': 'بي بي سي عربي BBC Arabic Live 📺',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/nat_geo.m3u8',
        'catId': 'custom_pro_3',
        'icon': 'https://img.icons8.com/color/120/tv-show.png',
      },
      {
        'name': 'سكاي نيوز عربية Sky News Arabia HD 📡',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_3',
        'icon': 'https://img.icons8.com/color/120/satellite-dish.png',
      },
      {
        'name': 'فرانس 24 عربي France 24 Arabic 🗼',
        'url': 'https://dwstream4-lh.akamaihd.net/i/dwar_1@444109/master.m3u8',
        'catId': 'custom_pro_3',
        'icon': 'https://img.icons8.com/color/120/eiffel-tower.png',
      },

      // Category 4: الرياضة العربية
      {
        'name': 'قناة beIN SPORTS الإخبارية المفتوحة ⚽',
        'url': 'https://fra-prod-catalyst-0.lp-playback.studio/hls/video+0df1wiv0fh9wymbb/index.m3u8',
        'catId': 'custom_pro_4',
        'icon': 'https://iili.io/CK5M0pR.png',
      },
      {
        'name': 'دبي الرياضية Dubai Sports 🏆',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_4',
        'icon': 'https://img.icons8.com/color/120/trophy.png',
      },
      {
        'name': 'أبوظبي الرياضية AD Sports 🥇',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_4',
        'icon': 'https://img.icons8.com/color/120/gold-medal.png',
      },
      {
        'name': 'الكأس الرياضية الأولى Alkass ONE HD 🎯',
        'url': 'https://fra-prod-catalyst-0.lp-playback.studio/hls/video+0df1wiv0fh9wymbb/index.m3u8',
        'catId': 'custom_pro_4',
        'icon': 'https://img.icons8.com/color/120/bullseye.png',
      },
      {
        'name': 'السعودية الرياضية SSC Sports HD 🇸🇦',
        'url': 'https://s3.us-east-2.amazonaws.com/cdnh118/hls/0/stream.m3u8',
        'catId': 'custom_pro_4',
        'icon': 'https://img.icons8.com/color/120/saudi-arabia.png',
      },
      {
        'name': 'أون تايم سبورت ON Time HD 🇪🇬',
        'url': 'https://live.kooran53.cfd/goolato3.m3u8',
        'catId': 'custom_pro_4',
        'icon': 'https://img.icons8.com/color/120/egypt.png',
      },

      // Category 5: القنوات الإسلامية والقرآن
      {
        'name': 'بث مباشر الحرم المكي الشريف 🕋',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/quran_makkah.m3u8',
        'catId': 'custom_pro_5',
        'icon': 'https://img.icons8.com/color/120/kaaba.png',
      },
      {
        'name': 'بث مباشر المسجد النبوي الشريف 🕌',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/sunnah_madinah.m3u8',
        'catId': 'custom_pro_5',
        'icon': 'https://img.icons8.com/color/120/mosque.png',
      },
      {
        'name': 'قناة المجد للقرآن الكريم Almajd Quran 📖',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/almajd.m3u8',
        'catId': 'custom_pro_5',
        'icon': 'https://img.icons8.com/color/120/quran.png',
      },
      {
        'name': 'إذاعة القرآن الكريم من القاهرة 🎙️',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/quran_makkah.m3u8',
        'catId': 'custom_pro_5',
        'icon': 'https://img.icons8.com/color/120/microphone.png',
      },
      {
        'name': 'قناة اقرأ الفضائية Iqraa TV ✨',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/almajd.m3u8',
        'catId': 'custom_pro_5',
        'icon': 'https://img.icons8.com/color/120/sparkles.png',
      },
      {
        'name': 'قناة الرسالة الفضائية Al Resalah 🌟',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/sunnah_madinah.m3u8',
        'catId': 'custom_pro_5',
        'icon': 'https://img.icons8.com/color/120/star--v1.png',
      },

      // Category 6: الوثائقية والثقافية
      {
        'name': 'الجزيرة الوثائقية Al Jazeera Doc 🦅',
        'url': 'https://live-hls-web-ajd.getaj.net/AJD/index.m3u8',
        'catId': 'custom_pro_6',
        'icon': 'https://img.icons8.com/color/120/falcon.png',
      },
      {
        'name': 'ناشيونال جيوغرافيك National Geographic AD 🐆',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/nat_geo.m3u8',
        'catId': 'custom_pro_6',
        'icon': 'https://img.icons8.com/color/120/adventure.png',
      },
      {
        'name': 'وثائقية أبوظبي AD Nat Geo HD 🌵',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/nat_geo.m3u8',
        'catId': 'custom_pro_6',
        'icon': 'https://img.icons8.com/color/120/desert.png',
      },
      {
        'name': 'الجزيرة الإنجليزية Al Jazeera English HD 🇬🇧',
        'url': 'https://live-hls-web-aje.getaj.net/AJE/index.m3u8',
        'catId': 'custom_pro_6',
        'icon': 'https://img.icons8.com/color/120/great-britain.png',
      },
      {
        'name': 'وثائقية بي بي سي BBC Earth HD 🌎',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/nat_geo.m3u8',
        'catId': 'custom_pro_6',
        'icon': 'https://img.icons8.com/color/120/earth.png',
      },
      {
        'name': 'ناشيونال جيوغرافيك وايلد Nat Geo Wild HD 🌾',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/nat_geo.m3u8',
        'catId': 'custom_pro_6',
        'icon': 'https://img.icons8.com/color/120/grass.png',
      },

      // Category 7: القنوات الترفيهية
      {
        'name': 'ام بي سي 1 MBC1 HD 📺',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/mbc1.m3u8',
        'catId': 'custom_pro_7',
        'icon': 'https://img.icons8.com/color/120/tv-show.png',
      },
      {
        'name': 'ام بي سي 2 MBC2 Movie Channel 🎬',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/mbc2.m3u8',
        'catId': 'custom_pro_7',
        'icon': 'https://img.icons8.com/color/120/movie.png',
      },
      {
        'name': 'روتانا سينما Rotana Cinema 🎉',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/rotana.m3u8',
        'catId': 'custom_pro_7',
        'icon': 'https://img.icons8.com/color/120/popcorn.png',
      },
      {
        'name': 'روتانا كلاسيك Rotana Classic 🎭',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/rotana.m3u8',
        'catId': 'custom_pro_7',
        'icon': 'https://img.icons8.com/color/120/theatre-mask.png',
      },
      {
        'name': 'ام بي سي 4 MBC4 HD ✨',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/mbc1.m3u8',
        'catId': 'custom_pro_7',
        'icon': 'https://img.icons8.com/color/120/star.png',
      },
      {
        'name': 'روتانا كوميدي Rotana Comedy HD 😂',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/rotana.m3u8',
        'catId': 'custom_pro_7',
        'icon': 'https://img.icons8.com/color/120/lol.png',
      },

      // Category 8: مسلسلات ودراما
      {
        'name': 'ام بي سي دراما MBC Drama 🎭',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/mbcdrama.m3u8',
        'catId': 'custom_pro_8',
        'icon': 'https://img.icons8.com/color/120/drama.png',
      },
      {
        'name': 'روتانا دراما Rotana Drama HD 🌹',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/rotanadrama.m3u8',
        'catId': 'custom_pro_8',
        'icon': 'https://img.icons8.com/color/120/theatre-mask.png',
      },
      {
        'name': 'زي ألوان Zee Alwan HD 💖',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/zeealwan.m3u8',
        'catId': 'custom_pro_8',
        'icon': 'https://img.icons8.com/color/120/rose.png',
      },
      {
        'name': 'زي أفلام Zee Aflam HD 📽️',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/zeealwan.m3u8',
        'catId': 'custom_pro_8',
        'icon': 'https://img.icons8.com/color/120/movie-projector.png',
      },
      {
        'name': 'سي بي سي دراما CBC Drama HD 🌟',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/mbcdrama.m3u8',
        'catId': 'custom_pro_8',
        'icon': 'https://img.icons8.com/color/120/star.png',
      },
      {
        'name': 'بانوراما دراما Panorama Drama 🎬',
        'url': 'https://pub-a55097de077b49cc98135767c0678d8a.r2.dev/rotanadrama.m3u8',
        'catId': 'custom_pro_8',
        'icon': 'https://img.icons8.com/color/120/movie.png',
      }
    ];

    base.addAll(_customProStreams);
    return base;
  }

  void zapChannel(bool next) {
    if (_filteredStreams.isEmpty || _currentStream == null) return;
    final currentIdx = _filteredStreams.indexWhere((i) => i.streamId == _currentStream!.streamId);
    if (currentIdx != -1) {
      int nextIdx = next ? currentIdx + 1 : currentIdx - 1;
      if (nextIdx >= _filteredStreams.length) nextIdx = 0;
      if (nextIdx < 0) nextIdx = _filteredStreams.length - 1;
      _currentStream = _filteredStreams[nextIdx];
      notifyListeners();
    }
  }

  void _applyFilters() {
    List<PlaylistItem> baseList;
    if (_activeTab == "favorites") {
      final combined = [..._allStreams, ..._customProStreams];
      final seen = <String>{};
      baseList = [];
      for (var s in combined) {
        if (_favorites.contains(s.streamId) && !seen.contains(s.streamId)) {
          seen.add(s.streamId);
          baseList.add(s);
        }
      }
    } else {
      baseList = _streamsByTypeAndCategory[_activeTab] ?? [];
    }

    if (_selectedCategory != "all") {
      // Map selected display category to unique category ID
      String? matchedCategoryId;
      if (_activeTab == "live") {
        final found = _liveCategories.firstWhere((c) => c['category_name'] == _selectedCategory, orElse: () => {});
        if (found.isNotEmpty) matchedCategoryId = found['category_id']?.toString();
      } else if (_activeTab == "movie") {
        final found = _movieCategories.firstWhere((c) => c['category_name'] == _selectedCategory, orElse: () => {});
        if (found.isNotEmpty) matchedCategoryId = found['category_id']?.toString();
      } else if (_activeTab == "series") {
        final found = _seriesCategories.firstWhere((c) => c['category_name'] == _selectedCategory, orElse: () => {});
        if (found.isNotEmpty) matchedCategoryId = found['category_id']?.toString();
      }

      final key = "${_activeTab}_${matchedCategoryId ?? _selectedCategory}";
      if (_streamsByTypeAndCategory.containsKey(key)) {
        baseList = _streamsByTypeAndCategory[key]!;
      } else {
        final cleanSelCat = _selectedCategory.replaceAll('⚡', '').trim().toLowerCase();
        baseList = baseList.where((s) {
          final cleanStreamCat = s.categoryName.replaceAll('⚡', '').trim().toLowerCase();
          return cleanStreamCat == cleanSelCat || 
                 s.categoryId == _selectedCategory || 
                 s.categoryId == cleanSelCat || 
                 s.categoryName == _selectedCategory ||
                 (matchedCategoryId != null && s.categoryId == matchedCategoryId);
        }).toList();
      }
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      baseList = baseList.where((s) => s.name.toLowerCase().contains(q) || s.categoryName.toLowerCase().contains(q)).toList();
    }

    _filteredStreams = baseList;
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites');
    _favorites = list != null ? List<String>.from(list) : [];
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites);
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    _activePlaylistId = prefs.getString('active_playlist_id');
    final playlistsRaw = prefs.getString('saved_playlists');
    if (playlistsRaw != null) {
      final List parsed = json.decode(playlistsRaw);
      _savedPlaylists = parsed.map((p) => UserPlaylist.fromJson(p)).toList();
    }
    
    // Ensure "vip_9xtream" always exists as the default fallback playlist, even without activation
    if (!_savedPlaylists.any((p) => p.id == "vip_9xtream")) {
      _savedPlaylists.insert(0, UserPlaylist(
        id: "vip_9xtream",
        name: "live strem pro ⚡",
        type: "github",
        host: "https://github.com",
        username: "github_user",
        password: "github_password",
      ));
    }
    
    if (_activePlaylistId == null || !_savedPlaylists.any((p) => p.id == _activePlaylistId)) {
      _activePlaylistId = "vip_9xtream";
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activePlaylistId != null) {
      await prefs.setString('active_playlist_id', _activePlaylistId!);
    } else {
      await prefs.remove('active_playlist_id');
    }
    final raw = json.encode(_savedPlaylists.map((p) => p.toJson()).toList());
    await prefs.setString('saved_playlists', raw);
  }
}
