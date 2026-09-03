import re

with open("lib/providers/iptv_provider.dart", "r") as f:
    content = f.read()

# Add import for main_menu_data.dart
if "import 'main_menu_data.dart';" not in content:
    content = content.replace("import 'package:http/http.dart' as http;", "import 'package:http/http.dart' as http;\nimport 'main_menu_data.dart';")

# 1. Replace `_loginUsingGitHubConfig` function completely.
old_login_start = r'  Future<bool> _loginUsingGitHubConfig(String code) async \{'
old_login_end = r'  Future<void> loadPlaylistStreams\(String id\) async \{'

new_login = r'''  Future<bool> _loginUsingGitHubConfig(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      lastError = "الرجاء إدخال رمز صحيح";
      return false;
    }

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
      
      if (configRes.statusCode == 200) {
         try {
            final config = await Isolate.run(() => json.decode(configRes.body));
            _appName = config['app_name'] ?? _appName;
            
            _latestVersion = config['app_version'] ?? "";
            _updateUrl = config['apk_url'] ?? "";
            _updateMessage = config['update_message'] ?? "";
            
            String currentVersion = _currentVersionStr;
            if (_latestVersion.isNotEmpty && isVersionLowerThan(currentVersion, _latestVersion) && _updateUrl.isNotEmpty) {
                _updateAvailable = true;
            }
         } catch (e) {
            debugPrint("Config parse error");
         }
      }

      final deviceId = await _getDeviceId();
      final loginUrl = Uri.parse("https://iptv-subscription-api.tvkora56.workers.dev/v1/login");
      final loginRes = await http.post(loginUrl,
          headers: {"Content-Type": "application/json"},
          body: json.encode({"code": cleanCode, "device_id": deviceId})
      ).timeout(const Duration(seconds: 15));

      if (loginRes.statusCode == 200) {
          final loginData = json.decode(loginRes.body);
          if (loginData['ok'] == true) {
              final userObj = loginData['user'];
              String host = userObj['host'] ?? "";
              String user = userObj['username'] ?? "";
              String pass = userObj['password'] ?? "";
              String sType = userObj['server_type'] ?? "xtream";
              
              if (sType == 'stalker') {
                  pass = 'stalker';
              }
              
              bool isAuthenticated = false;
              String pType = pass == 'stalker' ? 'stalker' : 'xtream';
              
              if (sType == 'custom') {
                 isAuthenticated = true;
                 pType = 'custom';
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
                  
                  int durationHours = -1;
                  String subName = "اشتراك $cleanCode";
                  
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
                  if (lastError == null || lastError!.isEmpty) {
                      lastError = "الاشتراك غير فعال أو بيانات السيرفر خاطئة";
                  }
              }
          } else {
              lastError = loginData['message'] ?? "رمز الدخول غير صالح أو غير مصرح به";
          }
      } else if (loginRes.statusCode == 401 || loginRes.statusCode == 403) {
          try {
             final errData = json.decode(loginRes.body);
             lastError = errData['message'] ?? "رمز الدخول غير صالح أو غير مصرح به";
          } catch (_) {
             lastError = "رمز الدخول غير صالح أو غير مصرح به";
          }
      } else {
          lastError = "تعذر الاتصال بالخادم. رمز الخطأ: ${loginRes.statusCode}";
      }
    } catch (e) {
      lastError = "تعذر الاتصال. تأكد من الإنترنت وصحة الاشتراك";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadPlaylistStreams(String id) async {'''

content = re.sub(old_login_start + r'.*?' + old_login_end, new_login, content, flags=re.DOTALL)

# 2. Fix `loadPlaylistStreams` for custom type
old_load_custom = r'''    if \(_activationCode == "2027"\) \{
       try \{
         final url = Uri.parse\("https://iptv-subscription-api.tvkora56.workers.dev/v1/menu\?t=\$\{DateTime.now\(\).millisecondsSinceEpoch\}"\);
         final res = await http.get\(url\);
         if \(res.statusCode == 200\) \{
            final List<dynamic> data = await Isolate.run\(\(\) => json.decode\(res.body\)\);'''

new_load_custom = r'''    if (playlist.type == "custom") {
       try {
            final List<dynamic> data = await Isolate.run(() => json.decode(mainMenuJsonData));'''

content = re.sub(old_load_custom, new_load_custom, content)

with open("lib/providers/iptv_provider.dart", "w") as f:
    f.write(content)

print("Patched.")
