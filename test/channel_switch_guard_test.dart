import 'package:flutter_iptv_player/services/channel_switch_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the latest channel load generation remains current', () {
    final guard = ChannelSwitchGuard();
    final first = guard.begin();
    final second = guard.begin();

    expect(guard.isCurrent(first), isFalse);
    expect(guard.isCurrent(second), isTrue);
    expect(guard.currentGeneration, second);
  });
}
