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
  static String get githubToken => "ghp_" "MXz69m4S76rqv7xRMYaJ7njXXAmoch4UjE3E";
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
  String _stalkerToken = "";
  String get stalkerToken => _stalkerToken;
  int _activationTime = 0;
  int _activationDurationHours = -1;
  String _subscriptionType = "";

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

  static const int APP_VERSION_CODE = 144;
  bool _isVersionBlocked = false;
  String _remoteBlockMessage = "🚨 تحديث إجباري مطلوب فوراً 🚨\n\nلقد تم إيقاف هذا الإصدار القديم نهائياً لدواعي صيانة وتحديث الأمان. يرجى تنزيل الإصدار الأخير للاستمرار في مشاهدة القنوات والاشتراكات. شكراً لكم!";
  String get remoteBlockMessage => _remoteBlockMessage;
  bool get isVersionBlocked => _isVersionBlocked;

  bool _vpnDetected = false;
  bool get vpnDetected => _vpnDetected;

  String _globalProxy = "";
  String get globalProxy => _globalProxy;

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
  List<String> get categories {
    if (_activeTab == "live") {
      return _liveCategories.map((c) => c['category_name'] ?? '').toList();
    } else if (_activeTab == "movie") {
      return _movieCategories.map((c) => c['category_name'] ?? '').toList();
    } else if (_activeTab == "series") {
      return _seriesCategories.map((c) => c['category_name'] ?? '').toList();
    }
    return [];
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

    final playlistsJson = prefs.getString('saved_playlists');
    if (playlistsJson != null) {
      try {
        final List decoded = json.decode(playlistsJson);
        _savedPlaylists = decoded.map((item) => UserPlaylist.fromJson(item)).toList();
      } catch (_) {}
    }

    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _activationCode = prefs.getString('active_code') ?? "";
    _activationTime = prefs.getInt('active_code_activated_at') ?? 0;
    _activationDurationHours = prefs.getInt('active_code_duration_hours') ?? -1;
    _subscriptionType = prefs.getString('active_code_sub_name') ?? "";

    if (_activationCode.trim() == "69743190") {
      _isVersionBlocked = true;
    }

    if (_isLoggedIn && _savedPlaylists.isNotEmpty) {
      _activePlaylistId = _savedPlaylists.first.id;
      loadPlaylistStreams(_activePlaylistId!);
    }

    // تفعيل إعدادات بروكسي الحماية الصارمة
    HttpOverrides.global = MyHttpOverrides("");

    _isLoading = false;
    notifyListeners();
  }

  // ==========================================
  // دوال الحماية وفحص الشبكة (Anti-Proxy, VPN, Canary)
  // ==========================================

  Future<void> checkRemoteBlocking() async {
    try {
      final configRes = await http.get(Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}"), headers: {"Authorization": "token $githubToken"}).timeout(const Duration(seconds: 5));
      if (configRes.statusCode == 200) {
        final Map<String, dynamic> configData = json.decode(configRes.body);
        Map<String, dynamic>? blockData;
        if (configData.containsKey('blocking')) {
          blockData = Map<String, dynamic>.from(configData['blocking']);
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

          if (blockData.containsKey('block_message')) {
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
                    _isVersionBlocked = true;
                    _remoteBlockMessage = "تم حضر الاشتراك عنك بسبب عدم الانصياغ ل القواعد والقوانين";
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
                _isVersionBlocked = true;
                _remoteBlockMessage = "هذا الاشتراك غير صالح أو تم حذفه";
                logout();
                notifyListeners();
            }
        }

      }
    } catch (e) {
      debugPrint("Remote block check failed: $e");
    }
  }

  bool _isRegisteringDevice = false;

  Future<void> _registerDeviceOrBlock(String code, String deviceId) async {
    if (_isRegisteringDevice) return;
    _isRegisteringDevice = true;
    try {
        final url = Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}");
        final res = await http.get(url, headers: {"Authorization": "token $githubToken"});
        if (res.statusCode == 200) {
            final Map<String, dynamic> configData = json.decode(res.body);
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
                        _isVersionBlocked = true;
                        _remoteBlockMessage = "تم حضر الاشتراك عنك بسبب تجاوز الحد الأقصى للأجهزة (جهازين فقط)";
                        logout();
                        notifyListeners();
                    } else {
                        devices.add(deviceId);
                        u['devices'] = devices;
                    }
                    await _updateGithubConfig(configData);
                }
            }
        }
    } catch (e) {
        print("Error registering device: $e");
    }
    _isRegisteringDevice = false;
  }

  Future<void> _updateGithubConfig(Map<String, dynamic> configData) async {
    try {
        final getUrl = Uri.parse("https://api.github.com/repos/mahmoudhwhwhwh/flutter-iptv-player/contents/app_config.json");
        final getRes = await http.get(getUrl, headers: {"Authorization": "token $githubToken"});
        if (getRes.statusCode == 200) {
            final fileData = json.decode(getRes.body);
            final sha = fileData['sha'];
            
            final putUrl = Uri.parse("https://api.github.com/repos/mahmoudhwhwhwh/flutter-iptv-player/contents/app_config.json");
            final newContent = base64Encode(utf8.encode(json.encode(configData)));
            final putBody = json.encode({
                "message": "Update devices/blocking from app",
                "content": newContent,
                "sha": sha
            });
            await http.put(putUrl, headers: {"Authorization": "token $githubToken", "Content-Type": "application/json"}, body: putBody);
        }
    } catch (e) {
        print("Failed to update github config: $e");
    }
  }

  Future<void> checkSecurity() async {
    try {
      // فحص أمني فائق القوة عبر الجافا (Android) لوقف التطبيق فورا إذا تم اكتشاف تعديل أو بيئة مشبوهة
      final Map? result = await _securityChannel.invokeMapMethod('checkSecurity');
      if (result != null) {
        final shouldBlock = result['shouldBlock'] == true;
        final snifferInstalled = result['snifferInstalled'] == true;
        final vpnActive = result['vpnActive'] == true;
        final proxyActive = result['proxyActive'] == true;

        bool updated = false;
        if (_snifferDetected != (shouldBlock || snifferInstalled)) {
          _snifferDetected = shouldBlock || snifferInstalled;
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
      debugPrint("Security method channel not implemented: $e");
    }
  }

  Future<void> _checkVpnAndProxyStatus() async {
    try {
      // فحص أمني فائق شامل لكافة القنوات (نظام أندرويد + شبكة Dart)
      await checkSecurity();
      
      bool detected = _vpnDetected || _snifferDetected;
      
      if (!detected) {
        // 1. فحص إعدادات البروكسي (Proxy) لمنع برامج مثل Charles Proxy أو Reqable أو HttpCanary
        try {
          final systemProxy = HttpClient.findProxyFromEnvironment(Uri.parse("https://google.com"));
          if (systemProxy != "DIRECT" && systemProxy.trim().isNotEmpty) {
            detected = true;
          }
        } catch (_) {}
      }

      if (!detected) {
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
      final configUrl = Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}");
      final configRes = await http.get(configUrl, headers: {"Authorization": "token $githubToken"}).timeout(const Duration(seconds: 15));
      
      String host = "http://fh.u2i9o.top:80";
      String user = cleanCode;
      String pass = cleanCode;
      int durationHours = -1;
      String subName = 'اشتراك Live Football';

      if (configRes.statusCode == 200) {
         try {
            final config = json.decode(configRes.body);
            _appName = config['app_name'] ?? _appName;
            
            _latestVersion = config['app_version'] ?? "";
            _updateUrl = config['apk_url'] ?? "";
            _updateMessage = config['update_message'] ?? "";
            
            // Compare with current version (hardcoded "v1.8.0" for example)
            String currentVersion = "v1.8.0"; // You can use package_info_plus for dynamic versioning
            if (_latestVersion.isNotEmpty && _latestVersion != currentVersion && _updateUrl.isNotEmpty) {
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

               final expiryStr = userData['expiry_date'];
               if (expiryStr != null) {
                  final expiryDate = DateTime.parse(expiryStr);
                  if (DateTime.now().isAfter(expiryDate)) {
                     lastError = "انتهت صلاحية الاشتراك";
                     _isLoading = false;
                     notifyListeners();
                     return false;
                 }
                 durationHours = expiryDate.difference(DateTime.now()).inHours;
               }


               subName = "اشتراك $cleanCode";
            } else {
               subName = "اشتراك مجاني";
               durationHours = -1;
            }
         } catch (e) {
            print("Config parse error: $e");
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
                  final data = json.decode(response.body);
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
               final data = json.decode(response.body);
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
         final url = Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/Main_menu.json?t=${DateTime.now().millisecondsSinceEpoch}");
         final res = await http.get(url, headers: {"Authorization": "token $githubToken"});
         if (res.statusCode == 200) {
            final List<dynamic> data = json.decode(res.body);
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
            _allStreams = List.from(tempStreams);
            _liveCategories = tempCats;
            _movieCategories = [];
            _seriesCategories = [];
            
            _applyFilters();
         }
       } catch (e) {
          print("Error loading 2027 streams: $e");
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
        final headers = {
          "Cookie": "mac=$user", 
          "Authorization": "Bearer $_stalkerToken",
          "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3"
        };
        final liveCatsRes = await http.get(Uri.parse("$host/server/load.php?type=itv&action=get_genres&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 15));
        final liveStreamsRes = await http.get(Uri.parse("$host/server/load.php?type=itv&action=get_all_channels&JsHttpRequest=1-xml"), headers: headers).timeout(const Duration(seconds: 25));

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

        List<PlaylistItem> tempStreams = [];
        if (liveStreamsRes.statusCode == 200) {
          final data = json.decode(liveStreamsRes.body);
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
        _allStreams = List.from(tempStreams);
        _liveCategories = tempLiveCats;
        _isFetchingData = false;
        notifyListeners();
        return;
      } else if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
        final liveCatsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_categories")).timeout(const Duration(seconds: 15));
        final liveStreamsRes = await http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_live_streams")).timeout(const Duration(seconds: 25));

        List<Map<String, String>> tempLiveCats = [];
        if (liveCatsRes.statusCode == 200) {
          final List decoded = json.decode(liveCatsRes.body);
          tempLiveCats = decoded.map<Map<String, String>>((item) => {
            'category_id': item['category_id']?.toString() ?? '',
            'category_name': item['category_name']?.toString() ?? '',
          }).toList();
        }

        List<PlaylistItem> tempStreams = [];
        if (liveStreamsRes.statusCode == 200) {
          final List decoded = json.decode(liveStreamsRes.body);
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

        _allStreams = List.from(tempStreams);
        _liveCategories = tempLiveCats;
        
        // Fetch VOD and Series
        http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_categories")).then((vodCatsRes) {
           if (vodCatsRes.statusCode == 200) {
              final List decoded = json.decode(vodCatsRes.body);
              _movieCategories = decoded.map<Map<String, String>>((item) => {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              }).toList();
           }
           http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_vod_streams")).then((vodStreamsRes) {
              if (vodStreamsRes.statusCode == 200) {
                final List decoded = json.decode(vodStreamsRes.body);
                for (final item in decoded) {
                  final catId = item['category_id']?.toString() ?? '';
                  final cat = _movieCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                  final catName = cat.isNotEmpty ? cat['category_name']! : 'أفلام';
                  final streamId = item['stream_id']?.toString() ?? '';
                  final container = item['container_extension']?.toString() ?? 'mp4';
                  _allStreams.add(PlaylistItem(
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
              }
              _applyFilters();
              notifyListeners();
           });
        });

        http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series_categories")).then((seriesCatsRes) {
           if (seriesCatsRes.statusCode == 200) {
              final List decoded = json.decode(seriesCatsRes.body);
              _seriesCategories = decoded.map<Map<String, String>>((item) => {
                'category_id': item['category_id']?.toString() ?? '',
                'category_name': item['category_name']?.toString() ?? '',
              }).toList();
           }
           http.get(Uri.parse("$host/player_api.php?username=$user&password=$pass&action=get_series")).then((seriesRes) {
              if (seriesRes.statusCode == 200) {
                final List decoded = json.decode(seriesRes.body);
                for (final item in decoded) {
                  final catId = item['category_id']?.toString() ?? '';
                  final cat = _seriesCategories.firstWhere((c) => c['category_id'] == catId, orElse: () => {});
                  final catName = cat.isNotEmpty ? cat['category_name']! : 'مسلسلات';
                  final streamId = item['series_id']?.toString() ?? '';
                  _allStreams.add(PlaylistItem(
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
              }
              _applyFilters();
              notifyListeners();
           });
        });

      }
    } catch (e) {
      debugPrint("Error loading streams: $e");
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
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredStreams = _allStreams.where((stream) {
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
