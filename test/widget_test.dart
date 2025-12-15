// Basic Flutter widget test for POS Calculator

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_calculator/main.dart';

void main() {
  testWidgets('App should load', (WidgetTester tester) async {
    await tester.pumpWidget(const POSCalculatorApp());
    
    // Wait for async initialization
    await tester.pumpAndSettle();
    
    // Should show the calculator
    expect(find.text('Cash Calculator'), findsOneWidget);
  });
}
