import re
filepath = 'lib/providers/iptv_provider.dart'
with open(filepath, 'r') as f:
    content = f.read()

# I see it failed due to zapChannel missing. Let's add it back if missing.
zap_method = '''  void zapChannel(bool next) {
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
  }'''

if "void zapChannel" not in content:
    idx = content.rfind('}')
    content = content[:idx] + zap_method + "\n" + content[idx:]
    with open(filepath, 'w') as f:
        f.write(content)
    print("Added zapChannel")
else:
    print("zapChannel already exists!")
