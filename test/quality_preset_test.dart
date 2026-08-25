import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/screens/player_screen.dart';

void main() {
  test('4K preset selects the highest available source track up to 2160p', () {
    expect(bestAvailableQualityHeight([720, 1080, 2160], 2160), 2160);
    expect(bestAvailableQualityHeight([720, 1080], 2160), 1080);
  });

  test('8K preset never claims a source resolution that is unavailable', () {
    expect(bestAvailableQualityHeight([1080, 2160], 4320), 2160);
    expect(bestAvailableQualityHeight([0, -1], 4320), isNull);
  });
}
