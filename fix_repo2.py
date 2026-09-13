import re
filepath = 'lib/providers/iptv_provider.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Let's count braces to see if toggleFavorite is outside the class.
# The class starts at line 74.
class_start = content.find("class IPTVProvider")
if class_start == -1:
    print("Class not found")
    exit(1)

# Let's check the position of toggleFavorite
toggle_pos = content.find("void toggleFavorite")
if toggle_pos == -1:
    print("Toggle method not found")
    exit(1)

print(f"Class start: {class_start}, Toggle position: {toggle_pos}")

# Now let's find the closing brace of the class.
brace_count = 0
class_end = -1
in_class = False

for i in range(class_start, len(content)):
    if content[i] == '{':
        if not in_class:
            in_class = True
        brace_count += 1
    elif content[i] == '}':
        brace_count -= 1
        if in_class and brace_count == 0:
            class_end = i
            break

print(f"Class end: {class_end}")

if toggle_pos > class_end:
    print("ERROR: toggleFavorite is OUTSIDE the class!")
    
    # We need to move it inside.
    # The method text:
    method_text = '''  void toggleFavorite(String streamId) {
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
    } else {
      notifyListeners();
    }
  }'''
    
    # Remove all instances of toggleFavorite
    pattern = r'\s*void toggleFavorite\([^}]*\)\s*\{[^}]*\}\s*\}?\s*'
    # Actually just remove it manually.
    
    # It's better to just write the file completely.
    new_content = content[:class_end] + "\n" + method_text + "\n}\n"
    
    # And we also need to remove the trailing part outside the class.
    # What's outside?
    trailing = content[class_end+1:]
    print("Trailing content:")
    print(trailing)
    
    with open(filepath, 'w') as f:
        f.write(new_content)
    print("Fixed!")
else:
    print("Method is inside the class.")
