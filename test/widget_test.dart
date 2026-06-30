import 'package:flutter_test/flutter_test.dart';

import 'package:chicken_hop/main.dart';

void main() {
  testWidgets('App boots into loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChickenHopApp());
    expect(find.text('Loading'), findsOneWidget);
  });
}
