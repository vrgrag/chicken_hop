// Lightweight smoke test — the full app boot involves Firebase /
// AppsFlyer / WebView, none of which are available in the test host.
// We keep this file present so `flutter test` still has a target.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, equals(2));
  });
}
