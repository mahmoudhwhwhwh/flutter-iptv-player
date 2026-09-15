with open('lib/providers/iptv_provider.dart', 'r') as f:
    content = f.read()

# Fix the missing brace at the end of fetchAllData - exact string matching
idx = content.find('_isFetchingData = false;')
if idx != -1:
    end_idx = content.find('void toggleFavorite', idx)
    target = content[idx:end_idx+20]
    
    if 'notifyListeners();\n    void toggleFavorite' in target:
        new_target = target.replace('notifyListeners();\n    void toggleFavorite', 'notifyListeners();\n  }\n\n  void toggleFavorite')
        content = content.replace(target, new_target)
        print("Fixed real brace.")
        with open('lib/providers/iptv_provider.dart', 'w') as f:
            f.write(content)

