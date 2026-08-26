import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iptv_player/services/redacted_diagnostics.dart';

void main() {
  test('redacts credentials, tokens, MAC, and upstream URL', () {
    final output = redactDiagnostic(
      'HttpException: GET https://upstream.test/live/user/pass/7.ts?username=alice&password=secret&mac=00:11:22:33:44:55&token=abc',
    );

    expect(output, contains('https://upstream.test/[REDACTED_URL]'));
    expect(output, isNot(contains('alice')));
    expect(output, isNot(contains('secret')));
    expect(output, isNot(contains('00:11:22:33:44:55')));
    expect(output, isNot(contains('abc')));
  });

  test('keeps a bounded diagnostic message', () {
    final output = redactDiagnostic('x' * 500);
    expect(output.length, lessThanOrEqualTo(321));
    expect(output, endsWith('…'));
  });
}
