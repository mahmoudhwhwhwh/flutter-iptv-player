from pathlib import Path

root = Path(__file__).resolve().parents[1]
files = list((root / "lib").rglob("*.dart")) + [root / "pubspec.yaml", root / "worker.js"]
for path in files:
    text = path.read_text(encoding="utf-8")
    updated = text.replace("LIVE STREAM PREMIUM", "LIVE STREAM PRO")
    if updated != text:
        path.write_text(updated, encoding="utf-8")
        print(path)
