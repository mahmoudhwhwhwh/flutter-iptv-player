import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfig {
  const RemoteConfig({
    required this.configVersion,
    required this.expiresAt,
    required this.backgroundCatalogLoader,
    required this.showQualitySelector,
    required this.webFallback,
    required this.maxBufferMs,
    required this.retryCount,
  });

  final int configVersion;
  final DateTime expiresAt;
  final bool backgroundCatalogLoader;
  final bool showQualitySelector;
  final bool webFallback;
  final int maxBufferMs;
  final int retryCount;

  static final fallback = RemoteConfig(
    configVersion: 1,
    expiresAt: _fallbackExpiry,
    backgroundCatalogLoader: true,
    showQualitySelector: true,
    webFallback: true,
    maxBufferMs: 30000,
    retryCount: 2,
  );

  static final DateTime _fallbackExpiry = DateTime.utc(2099, 1, 1);

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final flags = json['flags'];
    final player = json['player'];
    if (json['schema_version'] != 1 || flags is! Map || player is! Map) {
      throw const FormatException('Unsupported remote config schema');
    }
    final expiresAt = DateTime.tryParse('${json['expires_at']}');
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Expired remote config');
    }
    int boundedInt(dynamic value, int fallbackValue, int min, int max) {
      final parsed = value is num ? value.toInt() : fallbackValue;
      return parsed.clamp(min, max);
    }

    return RemoteConfig(
      configVersion: boundedInt(json['config_version'], 1, 1, 1 << 31),
      expiresAt: expiresAt.toUtc(),
      backgroundCatalogLoader: flags['background_catalog_loader'] != false,
      showQualitySelector: flags['show_quality_selector'] != false,
      webFallback: flags['web_fallback'] != false,
      maxBufferMs: boundedInt(player['max_buffer_ms'], 30000, 5000, 120000),
      retryCount: boundedInt(player['retry_count'], 2, 0, 5),
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'config_version': configVersion,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'flags': {
          'background_catalog_loader': backgroundCatalogLoader,
          'show_quality_selector': showQualitySelector,
          'web_fallback': webFallback,
        },
        'player': {
          'max_buffer_ms': maxBufferMs,
          'retry_count': retryCount,
        },
      };
}

class RemoteConfigService {
  RemoteConfigService({http.Client? client})
      : _client = client ?? http.Client();

  static const _cacheKey = 'remote_config_v1';
  static const _endpoint =
      'https://iptv-subscription-api.tvkora56.workers.dev/v1/remote-config';
  final http.Client _client;

  Future<RemoteConfig> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    RemoteConfig? cached;
    final cachedRaw = prefs.getString(_cacheKey);
    if (cachedRaw != null) {
      try {
        cached = RemoteConfig.fromJson(jsonDecode(cachedRaw));
      } catch (_) {
        cached = null;
      }
    }
    if (!forceRefresh && cached != null) return cached;
    try {
      final response = await _client
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return cached ?? RemoteConfig.fallback;
      final parsed = RemoteConfig.fromJson(jsonDecode(response.body));
      await prefs.setString(_cacheKey, jsonEncode(parsed.toJson()));
      return parsed;
    } catch (_) {
      return cached ?? RemoteConfig.fallback;
    }
  }
}
