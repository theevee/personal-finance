import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabob/shared/widgets/numeric_keypad.dart';

void main() {
  testWidgets('keypad reports taps and long-press clear', (tester) async {
    final keys = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NumericKeypad(onKey: keys.add)),
      ),
    );

    await tester.tap(find.text('7'));
    await tester.tap(find.text('.'));
    await tester.longPress(find.byIcon(Icons.backspace_outlined));

    expect(keys, ['7', '.', 'clear']);
  });

  testWidgets('riel keypad offers 000 instead of a decimal point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NumericKeypad(onKey: (_) {}, allowDecimal: false)),
      ),
    );
    expect(find.text('000'), findsOneWidget);
    expect(find.text('.'), findsNothing);
  });
}
