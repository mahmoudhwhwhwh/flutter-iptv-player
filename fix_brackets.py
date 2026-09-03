with open("lib/providers/iptv_provider.dart", "r") as f:
    content = f.read()

content = content.replace('''    if (playlist.type == "custom") {
       try {
            final List<dynamic> data = await Isolate.run(() => json.decode(mainMenuJsonData));''', '''    if (playlist.type == "custom") {
       try {
         if (true) {
            final List<dynamic> data = await Isolate.run(() => json.decode(mainMenuJsonData));''')

with open("lib/providers/iptv_provider.dart", "w") as f:
    f.write(content)
