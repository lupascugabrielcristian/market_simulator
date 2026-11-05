import 'package:flutter_test/flutter_test.dart';

import 'package:market_simulation/main.dart';
import 'package:market_simulation/product_catalog.dart';

void main() {
  testWidgets('shows the market game and building options', (tester) async {
    // Pre-load the product catalog before pumping the widget.
    await ProductCatalog.instance.load();

    await tester.pumpWidget(const MarketSimulationApp());

    // After loading, building options should be visible.
    expect(find.text('Store'), findsWidgets);
    expect(find.text('Company'), findsWidgets);
    expect(find.text('Factory'), findsWidgets);
    expect(find.text('Warehouse'), findsWidgets);
    expect(find.text('Extractor'), findsWidgets);
    expect(find.text('\$10000'), findsOneWidget);
  });
}
