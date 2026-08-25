import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/services/subscription_profile.dart';

void main() {
  test('accepts a complete Stalker profile without a password', () {
    expect(
        hasCompleteWorkerSubscriptionProfile({
          'server': {
            'type': 'stalker',
            'host': 'https://worker.example/v1/stalker',
            'username': 'masked-mac',
            'password': '',
          },
        }),
        isTrue);
  });

  test('requires a password for an Xtream profile', () {
    expect(
        hasCompleteWorkerSubscriptionProfile({
          'server': {
            'type': 'xtream',
            'host': 'https://worker.example/v1/xtream',
            'username': 'code',
            'password': 'managed',
          },
        }),
        isTrue);
    expect(
        hasCompleteWorkerSubscriptionProfile({
          'server': {
            'type': 'xtream',
            'host': 'https://worker.example/v1/xtream',
            'username': 'code',
            'password': '',
          },
        }),
        isFalse);
  });

  test('accepts a custom menu profile without source credentials', () {
    expect(
      hasCompleteWorkerSubscriptionProfile({
        'server': {
          'type': 'custom',
          'content_mode': 'custom_menu',
          'host': '',
          'username': '',
          'password': '',
        },
      }),
      isTrue,
    );
  });

  test('rejects a missing or incomplete server payload', () {
    expect(hasCompleteWorkerSubscriptionProfile({}), isFalse);
    expect(
        hasCompleteWorkerSubscriptionProfile({
          'server': {'type': 'stalker'}
        }),
        isFalse);
  });
}
