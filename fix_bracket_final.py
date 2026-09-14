with open('lib/providers/iptv_provider.dart', 'r') as f:
    content = f.read()

# Fix the missing brace at the end of fetchAllData
old = '''    } catch (e) {
      debugPrint("Streams could not be loaded");
    }
    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
    void toggleFavorite(String streamId) {'''

new = '''    } catch (e) {
      debugPrint("Streams could not be loaded");
    }
    _applyFilters();
    _isFetchingData = false;
    notifyListeners();
  }
  
  void toggleFavorite(String streamId) {'''

if old in content:
    content = content.replace(old, new)
    print("Fixed brace.")
else:
    print("Brace target not found.")

with open('lib/providers/iptv_provider.dart', 'w') as f:
    f.write(content)

