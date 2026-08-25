import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/models/saved_subscription_code.dart';

void main() {
  test('round trips a saved code without server credentials', () {
    const original = SavedSubscriptionCode(
      code: 'code-123',
      label: 'اشتراك المنزل',
      status: 'active',
      lastCheckedAt: 123,
      message: null,
    );
    final restored = SavedSubscriptionCode.fromJson(original.toJson());
    expect(restored.code, 'code-123');
    expect(restored.label, 'اشتراك المنزل');
    expect(restored.status, 'active');
    expect(restored.lastCheckedAt, 123);
    expect(restored.toJson().containsKey('host'), isFalse);
    expect(restored.toJson().containsKey('username'), isFalse);
    expect(restored.toJson().containsKey('password'), isFalse);
  });

  test('normalizes code and label during deserialization', () {
    final restored = SavedSubscriptionCode.fromJson({
      'code': '  code-456 ',
      'label': '  مكتب  ',
    });
    expect(restored.code, 'code-456');
    expect(restored.label, 'مكتب');
    expect(restored.status, 'unknown');
  });
}
