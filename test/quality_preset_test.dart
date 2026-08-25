import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/screens/player_screen.dart';
import 'package:flutter_iptv_player/main.dart';

void main() {
  test('4K preset selects the highest available source track up to 2160p', () {
    expect(bestAvailableQualityHeight([720, 1080, 2160], 2160), 2160);
    expect(bestAvailableQualityHeight([720, 1080], 2160), 1080);
  });

  test('8K preset never claims a source resolution that is unavailable', () {
    expect(bestAvailableQualityHeight([1080, 2160], 4320), 2160);
    expect(bestAvailableQualityHeight([0, -1], 4320), isNull);
  });

  test('startup transition is cinematic normally and brief in Lite Mode', () {
    expect(startupIntroTransitionDuration(false),
        const Duration(milliseconds: 420));
    expect(startupIntroTransitionDuration(true),
        const Duration(milliseconds: 120));
  });

  test('live image filters provide distinct enhancement matrices', () {
    expect(
      liveImageFilterMatrix(LiveImageFilter.k4),
      isNot(equals(liveImageFilterMatrix(LiveImageFilter.none))),
    );
    expect(
      liveImageFilterMatrix(LiveImageFilter.k8),
      isNot(equals(liveImageFilterMatrix(LiveImageFilter.k4))),
    );
    expect(liveImageFilterMatrix(LiveImageFilter.none), hasLength(20));
  });
}
