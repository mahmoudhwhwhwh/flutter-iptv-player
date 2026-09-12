import re

with open("lib/providers/iptv_provider.dart", "r") as f:
    content = f.read()

# Replace the block checking for 2027 and fetching from /v1/menu
old_block = r'''    if \(_activationCode == "2027"\) \{
       try \{
         final url = Uri.parse\("https://iptv-subscription-api.tvkora56.workers.dev/v1/menu\?t=\$\{DateTime.now\(\).millisecondsSinceEpoch\}"\);
         final res = await http.get\(url\);
         if \(res.statusCode == 200\) \{
            final List<dynamic> data = await Isolate.run\(\(\) => json.decode\(res.body\)\);'''

new_block = r'''    if (playlist.type == "custom") {
       try {
            final List<dynamic> data = await Isolate.run(() => json.decode(mainMenuJsonData));'''

content = re.sub(old_block, new_block, content, count=1)

with open("lib/providers/iptv_provider.dart", "w") as f:
    f.write(content)
print("Patched loadPlaylistStreams.")
