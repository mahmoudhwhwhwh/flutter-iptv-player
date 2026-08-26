import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/services/remote_config_service.dart';

void main() {
  test('parses a valid remote config and clamps player settings', () {
    final config = RemoteConfig.fromJson({
      'schema_version': 1,
      'config_version': 4,
      'expires_at': '2099-01-01T00:00:00.000Z',
      'flags': {
        'background_catalog_loader': false,
        'show_quality_selector': true,
        'web_fallback': false,
      },
      'player': {'max_buffer_ms': 999999, 'retry_count': 99},
    });

    expect(config.configVersion, 4);
    expect(config.backgroundCatalogLoader, isFalse);
    expect(config.webFallback, isFalse);
    expect(config.maxBufferMs, 120000);
    expect(config.retryCount, 5);
  });

  test('rejects an unsupported schema and an expired config', () {
    expect(
      () => RemoteConfig.fromJson({
        'schema_version': 2,
        'config_version': 1,
        'expires_at': '2099-01-01T00:00:00.000Z',
        'flags': {},
        'player': {},
      }),
      throwsFormatException,
    );
    expect(
      () => RemoteConfig.fromJson({
        'schema_version': 1,
        'config_version': 1,
        'expires_at': '2020-01-01T00:00:00.000Z',
        'flags': {},
        'player': {},
      }),
      throwsFormatException,
    );
  });
}
