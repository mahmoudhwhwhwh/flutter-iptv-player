import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/playlist_item.dart';

/// Stores subscription profiles in platform-backed secure storage.
/// Legacy SharedPreferences migration is handled by IPTVProvider so that
/// existing users keep their saved subscriptions without leaving credentials
/// in the plain-preferences container after the first successful load.
class SecurePlaylistStore {
  static const _key = 'saved_playlists_secure_v1';

  const SecurePlaylistStore(
      {FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  final FlutterSecureStorage _storage;

  Future<List<UserPlaylist>> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null || encoded.isEmpty) return <UserPlaylist>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <UserPlaylist>[];
      return decoded
          .whereType<Map>()
          .map((item) => UserPlaylist.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: true);
    } catch (_) {
      return <UserPlaylist>[];
    }
  }

  Future<void> write(List<UserPlaylist> playlists) async {
    await _storage.write(
      key: _key,
      value:
          jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
    );
  }

  Future<void> delete() => _storage.delete(key: _key);

  Future<String?> readValue(String key) => _storage.read(key: key);

  Future<void> writeValue(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> deleteValue(String key) => _storage.delete(key: key);
}
