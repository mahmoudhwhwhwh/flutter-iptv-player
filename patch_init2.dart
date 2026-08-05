  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    
    final savedFavs = prefs.getStringList('favorites');
    if (savedFavs != null) {
      _favorites = savedFavs;
    }

    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _appName = prefs.getString('app_name_cached') ?? "تطبيق البث المميز";

    if (_isLoggedIn) {
