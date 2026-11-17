import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_plus_example/form_demo.dart';

void main() {
  testWidgets('Save scrolls to the first invalid field', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormDemo()));

    final scrollable = find.byType(Scrollable).first;
    ScrollPosition position() =>
        tester.state<ScrollableState>(scrollable).position;
    expect(position().pixels, 0);

    // Fill the two visible fields; the first invalid one (phone) is off-screen.
    await tester.enterText(find.byType(TextFormField).at(0), 'Ada');
    await tester.enterText(find.byType(TextFormField).at(1), 'ada@example.com');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(position().pixels, greaterThan(0));
    expect(find.text('phone is required'), findsOneWidget);
    // Let the 2 second highlight expire.
    await tester.pump(const Duration(seconds: 3));
  });
}
