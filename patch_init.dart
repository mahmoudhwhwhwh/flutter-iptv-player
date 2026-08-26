  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _appName = prefs.getString('app_name_cached') ?? "تطبيق البث المميز";

    if (_isLoggedIn) {
      _activationCode = prefs.getString('active_code');
