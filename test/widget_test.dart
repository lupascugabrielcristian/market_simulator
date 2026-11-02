import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:market_simulation/main.dart';

void main() {
  testWidgets('shows the market game and building options', (tester) async {
    await tester.pumpWidget(const MarketSimulationApp());

    expect(find.byIcon(Icons.storefront_rounded), findsWidgets);
    expect(find.text('Store'), findsWidgets);
    expect(find.text('Company'), findsWidgets);
    expect(find.text('Factory'), findsWidgets);
    expect(find.text('Warehouse'), findsWidgets);
    expect(find.text('\$10000'), findsOneWidget);
    expect(find.textContaining('consumers'), findsWidgets);
  });
}
