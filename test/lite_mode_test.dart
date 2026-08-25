import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_iptv_player/providers/iptv_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Lite Mode toggles and persists as a manual preference', () async {
    final provider = IPTVProvider();

    expect(provider.liteMode, isFalse);
    await provider.setLiteMode(true);
    expect(provider.liteMode, isTrue);

    await provider.setLiteMode(false);
    expect(provider.liteMode, isFalse);
  });

  test('auto-enables only for conservative weak-device signals', () {
    expect(
      IPTVProvider.shouldAutoEnableLiteMode(
        isLowRamDevice: true,
        sdkInt: 34,
        has64BitAbi: true,
      ),
      isTrue,
    );
    expect(
      IPTVProvider.shouldAutoEnableLiteMode(
        isLowRamDevice: false,
        sdkInt: 25,
        has64BitAbi: false,
      ),
      isTrue,
    );
    expect(
      IPTVProvider.shouldAutoEnableLiteMode(
        isLowRamDevice: false,
        sdkInt: 34,
        has64BitAbi: true,
      ),
      isFalse,
    );
  });

  test('auto Lite Mode notice is shown only once', () {
    expect(
      IPTVProvider.shouldShowAutoLiteModeNotice(
        autoEnabled: true,
        noticeShown: false,
      ),
      isTrue,
    );
    expect(
      IPTVProvider.shouldShowAutoLiteModeNotice(
        autoEnabled: true,
        noticeShown: true,
      ),
      isFalse,
    );
  });

  test('manual Lite Mode and normal devices do not show the auto notice', () {
    expect(
      IPTVProvider.shouldShowAutoLiteModeNotice(
        autoEnabled: false,
        noticeShown: false,
      ),
      isFalse,
    );
  });
}
