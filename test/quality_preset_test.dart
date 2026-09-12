import 'package:flutter_test/flutter_test.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter_iptv_player/screens/player_screen.dart';
import 'package:flutter_iptv_player/main.dart';
import 'package:flutter_iptv_player/providers/iptv_provider.dart';

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

  test('quality availability distinguishes one source track from manifest tracks', () {
    expect(realQualityAvailabilityLabel(hasTracks: false), contains('جودة واحدة'));
    expect(realQualityAvailabilityLabel(hasTracks: true), contains('مسارات الجودة'));
  });

  test('real quality label reflects the announced source track', () {
    final track = BetterPlayerAsmsTrack(
        'v1080', 1920, 1080, 4500000, 25, 'avc1', 'video/mp4');
    expect(realQualityTrackKey(track), 'v1080|1920|1080|4500000');
    expect(realQualityTrackLabel(track), contains('1080p'));
    expect(realQualityTrackLabel(track), contains('4.5 Mbps'));
  });

  test('real quality label does not claim a resolution for auto track', () {
    final track = BetterPlayerAsmsTrack.defaultTrack();
    expect(realQualityTrackLabel(track), 'تلقائي');
  });

  test('Xtream media type preserves real HLS and DASH manifest extensions', () {
    expect(normalizeXtreamMediaExtension('hls'), 'm3u8');
    expect(normalizeXtreamMediaExtension('.m3u8'), 'm3u8');
    expect(normalizeXtreamMediaExtension('dash'), 'mpd');
    expect(normalizeXtreamMediaExtension('mp4'), 'mp4');
  });
}
