import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteContentItem {
  const RemoteContentItem(
      {required this.title,
      this.imageUrl = '',
      this.description = '',
      this.url = '',
      this.date = ''});
  final String title;
  final String imageUrl;
  final String description;
  final String url;
  final String date;

  factory RemoteContentItem.fromJson(dynamic value) {
    if (value is String)
      return RemoteContentItem(title: value, imageUrl: value);
    if (value is! Map) return const RemoteContentItem(title: '');
    return RemoteContentItem(
      title: value['title']?.toString() ?? value['name']?.toString() ?? '',
      imageUrl: value['image']?.toString() ??
          value['image_url']?.toString() ??
          value['icon']?.toString() ??
          '',
      description: value['description']?.toString() ?? '',
      url: value['url']?.toString() ?? value['link']?.toString() ?? '',
      date:
          value['date']?.toString() ?? value['published_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'image_url': imageUrl,
        'description': description,
        'url': url,
        'date': date,
      };
}

class RemoteConfig {
  const RemoteConfig({
    required this.configVersion,
    required this.expiresAt,
    required this.backgroundCatalogLoader,
    required this.showQualitySelector,
    required this.webFallback,
    required this.maxBufferMs,
    required this.retryCount,
    required this.slider,
    required this.news,
    required this.matches,
    required this.maintenance,
    required this.latestVersion,
    required this.downloadUrl,
  });

  final int configVersion;
  final DateTime expiresAt;
  final bool backgroundCatalogLoader;
  final bool showQualitySelector;
  final bool webFallback;
  final int maxBufferMs;
  final int retryCount;
  final List<RemoteContentItem> slider;
  final List<RemoteContentItem> news;
  final List<RemoteContentItem> matches;
  final bool maintenance;
  final String latestVersion;
  final String downloadUrl;

  static final fallback = RemoteConfig(
    configVersion: 1,
    expiresAt: _fallbackExpiry,
    backgroundCatalogLoader: true,
    showQualitySelector: true,
    webFallback: true,
    maxBufferMs: 30000,
    retryCount: 2,
    slider: const [],
    news: const [],
    matches: const [],
    maintenance: false,
    latestVersion: '',
    downloadUrl: '',
  );

  static final DateTime _fallbackExpiry = DateTime.utc(2099, 1, 1);

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    // Accept both the versioned schema and the current Worker /v1/config
    // response so a backend config rollout does not break older clients.
    final flags = json['flags'] is Map
        ? Map<String, dynamic>.from(json['flags'] as Map)
        : <String, dynamic>{};
    final player = json['player'] is Map
        ? Map<String, dynamic>.from(json['player'] as Map)
        : <String, dynamic>{};
    final hasLegacyWorkerShape = json.containsKey('app_name') ||
        json.containsKey('app_version') ||
        json.containsKey('slider');
    if (json['schema_version'] != 1 && !hasLegacyWorkerShape) {
      throw const FormatException('Unsupported remote config schema');
    }
    final expiresAt = DateTime.tryParse('${json['expires_at']}') ??
        DateTime.now().toUtc().add(const Duration(hours: 12));
    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Expired remote config');
    }
    int boundedInt(dynamic value, int fallbackValue, int min, int max) {
      final parsed = value is num ? value.toInt() : fallbackValue;
      return parsed.clamp(min, max);
    }

    List<RemoteContentItem> items(dynamic value) => value is List
        ? value
            .map(RemoteContentItem.fromJson)
            .where((item) => item.title.isNotEmpty || item.imageUrl.isNotEmpty)
            .toList()
        : <RemoteContentItem>[];

    return RemoteConfig(
      configVersion: boundedInt(json['config_version'], 1, 1, 1 << 31),
      expiresAt: expiresAt.toUtc(),
      backgroundCatalogLoader: flags['background_catalog_loader'] != false,
      showQualitySelector: flags['show_quality_selector'] != false,
      webFallback: flags['web_fallback'] != false,
      maxBufferMs: boundedInt(player['max_buffer_ms'], 30000, 5000, 120000),
      retryCount: boundedInt(player['retry_count'], 2, 0, 5),
      slider: items(json['slider']),
      news: items(json['news']),
      matches: items(json['matches'] ?? json['match_center']),
      maintenance: json['maintenance'] == true,
      latestVersion: json['latest_version']?.toString() ??
          json['app_version']?.toString() ??
          '',
      downloadUrl: json['apk_url']?.toString() ?? '',
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
        'slider': slider.map((item) => item.toJson()).toList(),
        'news': news.map((item) => item.toJson()).toList(),
        'matches': matches.map((item) => item.toJson()).toList(),
        'maintenance': maintenance,
        'latest_version': latestVersion,
        'apk_url': downloadUrl,
      };
}

class RemoteConfigService {
  RemoteConfigService({http.Client? client})
      : _client = client ?? http.Client();

  static const _cacheKey = 'remote_config_v1';
  static const _endpoint =
      'https://iptv-subscription-api.tvkora56.workers.dev/v1/config';
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
