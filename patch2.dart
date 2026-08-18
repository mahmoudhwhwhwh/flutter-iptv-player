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
