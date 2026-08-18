  String _appName = "Live Football";
  String get appName => _appName;

  Future<bool> loginWithCode(String code) async {
    lastError = null;
    String cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      lastError = "رمز الدخول فارغ";
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final configUrl = Uri.parse("https://raw.githubusercontent.com/mahmoudhwhwhwh/flutter-iptv-player/main/app_config.json?t=${DateTime.now().millisecondsSinceEpoch}");
      final configRes = await http.get(configUrl).timeout(const Duration(seconds: 15));
      
      String host = "http://fh.u2i9o.top:80";
      String user = cleanCode;
      String pass = cleanCode;
      int durationHours = -1;
      String subName = 'اشتراك Live Football';

      if (configRes.statusCode == 200) {
         try {
            final config = json.decode(configRes.body);
            _appName = config['app_name'] ?? _appName;
            
            final users = config['users'] as Map<String, dynamic>? ?? {};
            if (!users.containsKey(cleanCode)) {
               lastError = "رمز الدخول غير صالح او غير مصرح به";
               _isLoading = false;
               notifyListeners();
               return false;
            }

            final userData = users[cleanCode];
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

            host = config['xtream_host'] ?? host;
            user = userData['username'] ?? config['default_xtream_user'] ?? user;
            pass = userData['password'] ?? config['default_xtream_pass'] ?? pass;
            subName = "اشتراك \${cleanCode}";
         } catch (e) {
            print("Config parse error: $e");
         }
      } else {
         lastError = "فشل في الاتصال بخادم التحديثات";
         _isLoading = false;
         notifyListeners();
         return false;
      }

      final authUrl = Uri.parse("$host/player_api.php?username=$user&password=$pass");
      final response = await http.get(authUrl).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['user_info'] != null && data['user_info']['auth'] != 0) {
          
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
            id: "xtream_$cleanCode",
            name: _appName,
            type: "xtream",
            host: host,
            username: user,
            password: pass,
          );

          _savedPlaylists = [list];
          _activePlaylistId = list.id;
          
          await prefs.setString('saved_playlists', json.encode(_savedPlaylists.map((e) => e.toJson()).toList()));
          await prefs.setBool('is_logged_in', true);
          
          _isLoggedIn = true;
          _isLoading = false;
          notifyListeners();
          
          await _fetchXtreamData(list);
          return true;
        } else {
          lastError = "رمز الدخول غير صحيح";
        }
      } else {
        lastError = "خطأ في الاتصال بالخادم";
      }
    } catch (e) {
      lastError = "تعذر الاتصال. تأكد من الانترنت.";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
