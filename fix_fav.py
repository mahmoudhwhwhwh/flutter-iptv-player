import re
filepath = 'lib/providers/iptv_provider.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Make sure it has exactly one toggleFavorite method
if "void toggleFavorite(String streamId)" not in content:
    print("Adding missing toggleFavorite")
    idx = content.rfind('}')
    method = '''  void toggleFavorite(String streamId) async {
    if (_favorites.contains(streamId)) {
      _favorites.remove(streamId);
    } else {
      _favorites.add(streamId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites);
    if (_activeTab == "favorites") {
      _applyFilters();
    } else {
      notifyListeners();
    }
  }
'''
    content = content[:idx] + method + content[idx:]
    with open(filepath, 'w') as f:
        f.write(content)
else:
    print("Found toggleFavorite")
