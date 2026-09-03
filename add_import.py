with open("lib/providers/iptv_provider.dart", "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    new_lines.append(line)
    if "import 'package:http/http.dart' as http;" in line and "main_menu_data.dart" not in "".join(lines):
        new_lines.append("import 'main_menu_data.dart';\n")

with open("lib/providers/iptv_provider.dart", "w") as f:
    f.write("".join(new_lines))
