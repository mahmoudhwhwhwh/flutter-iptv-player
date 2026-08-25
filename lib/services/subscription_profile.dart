bool hasCompleteWorkerSubscriptionProfile(Map<String, dynamic> data) {
  final rawServer = data['server'] ?? data['user'];
  if (rawServer is! Map) return false;
  final server = Map<String, dynamic>.from(rawServer);
  final type = (server['type'] ?? server['server_type'] ?? 'xtream')
      .toString()
      .toLowerCase();
  final mode = (server['content_mode'] ?? 'iptv').toString().toLowerCase();
  if (mode == 'custom_menu') return true;
  final host = server['host']?.toString() ?? '';
  final username = server['username']?.toString() ?? '';
  final password = server['password']?.toString() ?? '';
  return host.isNotEmpty &&
      username.isNotEmpty &&
      (type == 'stalker' || type == 'custom' || password.isNotEmpty) &&
      (mode.isNotEmpty);
}
