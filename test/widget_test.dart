import 'package:flutter_test/flutter_test.dart';

import 'package:cf21_map_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CF21MapApp());

    // Verify that the app title is shown
    expect(find.text('CF21 Booth Map'), findsOneWidget);
  });
}

