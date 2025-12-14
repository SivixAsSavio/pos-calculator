// Basic Flutter widget test for POS Calculator

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_calculator/main.dart';

void main() {
  testWidgets('App should load', (WidgetTester tester) async {
    await tester.pumpWidget(const POSCalculatorApp());
    expect(find.text('POS Currency Calculator'), findsOneWidget);
  });
}
