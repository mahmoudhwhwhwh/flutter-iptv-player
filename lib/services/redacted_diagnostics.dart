import 'dart:core';

/// Converts network/player exceptions into diagnostics that never expose
/// credentials, session tokens, or full upstream media URLs.
String redactDiagnostic(Object error) {
  var text = error.toString();

  text = text.replaceAllMapped(
    RegExp(r'(password|passwd|pass|token|play_token|mac|username|user)=([^&\s,}]+)', caseSensitive: false),
    (match) => '${match.group(1)}=[REDACTED]',
  );

  text = text.replaceAllMapped(RegExp(r'https?://[^\s,})]+'), (match) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null || uri.host.isEmpty) return 'https://[REDACTED_URL]';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/[REDACTED_URL]';
  });

  return text.length > 320 ? '${text.substring(0, 320)}…' : text;
}
