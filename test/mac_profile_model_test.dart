import 'package:flutter_iptv_player/providers/iptv_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MAC profile starts with an unknown connection state', () {
    const status = MacProfileConnectionStatus.unknown();

    expect(status.state, MacProfileConnectionState.unknown);
    expect(status.message, 'لم يُفحص بعد');
    expect(status.checkedAt, isNull);
  });

  test('MAC profile survives JSON persistence', () {
    final profile = UserPlaylist(
      id: 'mac_profile_1',
      name: 'غرفة المعيشة',
      type: 'stalker',
      host: 'http://portal.example.test',
      username: '00:1A:79:AA:BB:CC',
    );

    final restored = UserPlaylist.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.name, profile.name);
    expect(restored.type, 'stalker');
    expect(restored.host, profile.host);
    expect(restored.username, profile.username);
  });

  test('saved subscription code survives JSON persistence', () {
    const saved = SavedSubscriptionCode(code: '96827', name: 'اشتراك العائلة');

    final restored = SavedSubscriptionCode.fromJson(saved.toJson());

    expect(restored.code, '96827');
    expect(restored.name, 'اشتراك العائلة');
  });
}
