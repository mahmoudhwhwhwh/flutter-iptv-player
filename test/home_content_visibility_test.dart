import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home sections do not silently truncate loaded content', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('.take(12)')));
  });
}
