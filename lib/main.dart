import 'dart:math';

import 'package:flutter/material.dart';

import 'market_database.dart';
import 'product_catalog.dart';

void main() => runApp(const MarketSimulationApp());

class MarketSimulationApp extends StatelessWidget {
  const MarketSimulationApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF102A43);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Market Simulation',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22A06B),
          primary: const Color(0xFF167D5A),
          secondary: const Color(0xFFF2B84B),
          surface: const Color(0xFFF7F9FC),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: navy),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: navy),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: navy),
          bodyMedium: TextStyle(color: Color(0xFF486581)),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

enum Terrain { grass, forest, water, mountain }

enum BuildingType { store, company, factory, extractor, warehouse }

extension BuildingTypeInfo on BuildingType {
  String get label => switch (this) {
        BuildingType.store => 'Store',
        BuildingType.company => 'Company',
        BuildingType.factory => 'Factory',
        BuildingType.extractor => 'Extractor',
        BuildingType.warehouse => 'Warehouse',
      };

  IconData get icon => switch (this) {
        BuildingType.store => Icons.storefront_rounded,
        BuildingType.company => Icons.apartment_rounded,
        BuildingType.factory => Icons.factory_rounded,
        BuildingType.extractor => Icons.energy_savings_leaf_rounded,
        BuildingType.warehouse => Icons.warehouse_rounded,
      };

  int get cost => switch (this) {
        BuildingType.store => 500,
        BuildingType.company => 1200,
        BuildingType.factory => 2400,
        BuildingType.extractor => 1700,
        BuildingType.warehouse => 800,
      };

  int get storageCapacity => switch (this) {
        BuildingType.store => 60,
        BuildingType.company => 100,
        BuildingType.factory => 50,
        BuildingType.extractor => 60,
        BuildingType.warehouse => 250,
      };

  bool get isProducer =>
      this == BuildingType.factory || this == BuildingType.extractor;
}

class City {
  City(this.name, this.x, this.y, this.population);

  final String name;
  final int x;
  final int y;
  int population;
  double averageSalary = 1200;
  int jobOpportunities = 0;

  final Map<String, int> stock = {};
  final Map<String, double> prices = {};
  final Map<String, int> sold = {};
  final Map<String, int> produced = {};

  List<City> tradePartners = [];
}

class Building {
  Building(
    this.type,
    this.x,
    this.y, {
    Set<String>? products,
    Set<String>? storeAccepts,
    this.inputWarehouseId,
  })  : id = _nextId++,
        products = Set<String>.from(products ?? const {}),
        storeAccepts = Set<String>.from(storeAccepts ?? const {});

  static int _nextId = 1;

  final int id;
  final BuildingType type;
  final int x;
  final int y;

  /// For factory/extractor: what they produce.
  /// For warehouse: what they store.
  final Set<String> products;

  /// For store: which products it sells to consumers.
  final Set<String> storeAccepts;

  /// For factory: the warehouse it draws inputs from.
  int? inputWarehouseId;
}

class Tile {
  Tile(this.terrain, this.road);

  Terrain terrain;
  bool road;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random _random = Random();
  final Map<String, Tile> _tiles = {};
  final List<City> _cities = [];
  final List<Building> _buildings = [];
  BuildingType? _selectedBuilding;
  int _cash = 10000;
  int _day = 1;
  int _cityId = 0;
  int _totalConsumers = 0;
  int _tradesToday = 0;
  DateTime? _lastDialogClosedAt;
  final bool _showCities = true;

  static const int mapWidth = 20;
  static const int mapHeight = 80;

  static const cityNames = [
    'Northport',
    'Riverton',
    'Oakhaven',
    'Lakewood',
    'Stonebridge',
    'Meadowbrook',
    'Sunnyvale',
    'Highland',
  ];

  @override
  void initState() {
    super.initState();
    if (ProductCatalog.instance.isLoaded) {
      _generateWorld();
    } else {
      ProductCatalog.instance.load().then((_) {
        if (mounted) setState(() => _generateWorld());
      });
    }
  }

  ProductCatalog get _catalog => ProductCatalog.instance;

  void _generateWorld() {
    _tiles.clear();
    _cities.clear();
    _buildings.clear();
    _selectedBuilding = null;
    _cash = 10000;
    _day = 1;
    _cityId = 0;
    _totalConsumers = 0;
    _tradesToday = 0;

    for (var y = 0; y < mapHeight; y++) {
      for (var x = 0; x < mapWidth; x++) {
        _tiles['$x,$y'] = Tile(_randomTerrain(x, y), false);
      }
    }

    while (_cities.length < 4) {
      final x = 2 + _random.nextInt(mapWidth - 4);
      final y = 2 + _random.nextInt(mapHeight - 4);
      final tooClose = _cities.any(
        (city) => (city.x - x).abs() + (city.y - y).abs() < 5,
      );
      if (tooClose) continue;

      final name = cityNames[_cityId % cityNames.length];
      _cities.add(City(name, x, y, 1200 + _random.nextInt(8000)));
      _cityId++;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final tile = _tiles['${x + dx},${y + dy}'];
          if (tile != null && tile.terrain != Terrain.water) {
            tile.terrain = Terrain.grass;
          }
        }
      }
    }

    _buildRoads();
    final capital = _cities.first;
    _cities.removeAt(0);
    _cities.insert(
      0,
      City('Your Capital', capital.x, capital.y, capital.population),
    );

    // Give each city a starting warehouse
    for (final city in _cities) {
      _buildings.add(Building(
        BuildingType.warehouse,
        city.x,
        city.y,
        products: _catalog.allProducts.map((p) => p.id).toSet(),
      ));
    }

    for (final city in _cities) {
      for (final product in _catalog.allProducts) {
        city.stock[product.id] = 0;
        city.prices[product.id] = product.basePrice;
        city.sold[product.id] = 0;
        city.produced[product.id] = 0;
      }
      city.tradePartners = _cities
          .where((other) => other != city)
          .where((other) => _hasRoadConnection(city, other))
          .toList();
    }
    _totalConsumers = _cities.fold(0, (sum, city) => sum + city.population);
    for (final city in _cities) {
      _updateEmployment(city);
    }
  }

  Terrain _randomTerrain(int x, int y) {
    final wave = sin((x + y * 0.8) * 0.7);
    final value = _random.nextDouble() + wave * 0.12;
    if (value > 0.9) return Terrain.mountain;
    if (value > 0.78) return Terrain.forest;
    if (value < 0.18 && x > 1 && x < mapWidth - 2) return Terrain.water;
    return Terrain.grass;
  }

  void _buildRoads() {
    for (final city in _cities) {
      final nearest = _cities
          .where((other) => other != city)
          .toList()
        ..sort((a, b) => _distance(city, a) - _distance(city, b));
      if (nearest.isNotEmpty) _connect(city, nearest.first);
    }
  }

  int _distance(City a, City b) => (a.x - b.x).abs() + (a.y - b.y).abs();

  void _connect(City a, City b) {
    var x = a.x;
    var y = a.y;
    while (x != b.x) {
      x += x < b.x ? 1 : -1;
      _setRoad(x, y);
    }
    while (y != b.y) {
      y += y < b.y ? 1 : -1;
      _setRoad(x, y);
    }
  }

  void _setRoad(int x, int y) {
    final tile = _tiles['$x,$y'];
    if (tile == null) return;
    tile.terrain = Terrain.grass;
    tile.road = true;
  }

  bool _hasRoadConnection(City a, City b) {
    var x = a.x;
    var y = a.y;
    while (x != b.x) {
      x += x < b.x ? 1 : -1;
      if (_tiles['$x,$y']?.road != true) return false;
    }
    while (y != b.y) {
      y += y < b.y ? 1 : -1;
      if (_tiles['$x,$y']?.road != true) return false;
    }
    return true;
  }

  bool _buildingAt(int x, int y) =>
      _buildings.any((building) => building.x == x && building.y == y);

  City? _cityAt(int x, int y) {
    for (final city in _cities) {
      if ((city.x - x).abs() <= 1 && (city.y - y).abs() <= 1) return city;
    }
    return null;
  }

  List<Building> _buildingsNear(City city, {int range = 1}) {
    return _buildings
        .where((b) =>
            (b.x - city.x).abs() <= range && (b.y - city.y).abs() <= range)
        .toList();
  }

  void _handleTileTap(int x, int y) {
    if (_dialogSettling()) return;
    final tile = _tiles['$x,$y'];
    if (tile == null) return;

    if (_selectedBuilding == null) {
      // A building on the exact tile takes priority over the city dialog.
      final building =
          _buildings.where((b) => b.x == x && b.y == y).firstOrNull;
      if (building != null) {
        _showBuildingPopup(building);
      } else {
        final city = _cityAt(x, y);
        if (city != null) _showCityPopup(city);
      }
      return;
    }

    if (_cash < _selectedBuilding!.cost) {
      _showPopup('Insufficient funds',
          'You need \$${_selectedBuilding!.cost} to buy this business.');
      return;
    }
    if (tile.terrain == Terrain.water) {
      _showPopup('Cannot build here', 'Water tiles cannot be developed.');
      return;
    }
    if (tile.terrain == Terrain.mountain) {
      _showPopup('Cannot build here', 'The terrain is too steep.');
      return;
    }
    if (_buildingAt(x, y)) {
      _showPopup('Tile occupied', 'There is already a business on this tile.');
      return;
    }

    final type = _selectedBuilding!;
    if (type.isProducer) {
      _showProductionChoice(type, x, y);
      return;
    }
    if (type == BuildingType.store) {
      _showStoreConfigChoice(x, y);
      return;
    }
    if (type == BuildingType.warehouse) {
      _showWarehouseConfigChoice(x, y);
      return;
    }

    // company — no config needed
    setState(() {
      _cash -= type.cost;
      _buildings.add(Building(type, x, y));
      _selectedBuilding = null;
    });
    _recordTransaction(MarketTransaction(
      day: _day,
      type: TransactionType.buildingPurchase,
      fromCity: 'Player',
      toCity: '',
      product: '',
      units: 1,
      unitPrice: type.cost.toDouble(),
      amount: -type.cost,
      profit: 0,
      description: 'Purchased ${type.label}',
      createdAt: DateTime.now(),
    ));
    _showPopup('Business established',
        'Your new ${type.label.toLowerCase()} is operating.');
  }

  void _showProductionChoice(BuildingType type, int x, int y) {
    final available =
        type == BuildingType.factory
            ? _catalog.factoryProducts
            : _catalog.extractorProducts;
    _dialog<String>(
      (context) => SimpleDialog(
        title: Text(
          type == BuildingType.factory
              ? 'Choose factory production'
              : 'Choose extractor output',
        ),
        children: available
            .map((product) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, product.id),
                  child: ListTile(
                    leading: Icon(product.icon),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.outputPerDay} units/day · \$${product.basePrice.toStringAsFixed(2)}',
                    ),
                  ),
                ))
            .toList(),
      ),
    ).then((productId) {
      if (!mounted || productId == null) return;
      _placeBuilding(type, x, y, {productId});
    });
  }

  void _showStoreConfigChoice(int x, int y) {
    final allIds = _catalog.allProducts.map((p) => p.id).toSet();
    _dialog<Set<String>>(
      (context) => _MultiSelectDialog(
        title: 'Choose store inventory',
        items: _catalog.allProducts,
        initialSelected: allIds,
      ),
    ).then((selected) {
      if (!mounted || selected == null) return;
      _placeBuilding(BuildingType.store, x, y, {}, storeAccepts: selected);
    });
  }

  void _showWarehouseConfigChoice(int x, int y) {
    final allIds = _catalog.allProducts.map((p) => p.id).toSet();
    _dialog<Set<String>>(
      (context) => _MultiSelectDialog(
        title: 'Choose warehouse storage',
        items: _catalog.allProducts,
        initialSelected: allIds,
      ),
    ).then((selected) {
      if (!mounted || selected == null) return;
      _placeBuilding(BuildingType.warehouse, x, y, selected);
    });
  }

  void _placeBuilding(
    BuildingType type,
    int x,
    int y,
    Set<String> products, {
    Set<String>? storeAccepts,
  }) {
    setState(() {
      _cash -= type.cost;
      _buildings.add(Building(
        type,
        x,
        y,
        products: products,
        storeAccepts: storeAccepts,
      ));
      _selectedBuilding = null;
    });
    _recordTransaction(MarketTransaction(
      day: _day,
      type: TransactionType.buildingPurchase,
      fromCity: 'Player',
      toCity: '',
      product: '',
      units: 1,
      unitPrice: type.cost.toDouble(),
      amount: -type.cost,
      profit: 0,
      description: 'Purchased ${type.label}',
      createdAt: DateTime.now(),
    ));
    _showPopup('Business established',
        'Your new ${type.label.toLowerCase()} is operating.');
  }

  void _showBuildingPopup(Building building) {
    _dialog<void>(
      (context) => _BuildingDialog(
        building: building,
        catalog: _catalog,
        onProductsChanged: building.type.isProducer
            ? (products) => _changeProduction(building, products)
            : null,
        onStoreAcceptsChanged: building.type == BuildingType.store
            ? (accepts) => _changeStoreInventory(building, accepts)
            : null,
        onWarehouseProductsChanged: building.type == BuildingType.warehouse
            ? (products) => _changeWarehouseStorage(building, products)
            : null,
        onInputWarehouseChanged: building.type == BuildingType.factory
            ? (warehouseId) => _changeInputWarehouse(building, warehouseId)
            : null,
        warehouses: _buildings
            .where((b) => b.type == BuildingType.warehouse)
            .toList(),
        tiles: _tiles,
      ),
    );
  }

  void _changeProduction(Building building, Set<String> products) {
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        building.products
          ..clear()
          ..addAll(products);
      });
    });
  }

  void _changeStoreInventory(Building building, Set<String> accepts) {
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        building.storeAccepts
          ..clear()
          ..addAll(accepts);
      });
    });
  }

  void _changeWarehouseStorage(Building building, Set<String> products) {
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        building.products
          ..clear()
          ..addAll(products);
      });
    });
  }

  void _changeInputWarehouse(Building building, int warehouseId) {
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        building.inputWarehouseId = warehouseId;
      });
    });
  }

  void _advanceDay() {
    setState(() {
      _day++;
      _tradesToday = 0;
      for (final city in _cities) {
        city.jobOpportunities = 0;
        for (final product in _catalog.allProducts) {
          city.produced[product.id] = 0;
        }
      }
      _simulateProduction();
      _simulateTrade();
      _simulateConsumers();
      _updatePrices();
      for (final city in _cities) {
        _updateEmployment(city);
      }
    });
  }

  void _updateEmployment(City city) {
    final nearbyCities = _cities.where((other) {
      final distance = _distance(city, other);
      return distance <= 12;
    }).toList();
    final nearbyOpportunities = nearbyCities.fold<int>(
      0,
      (sum, nearby) => sum + nearby.jobOpportunities,
    );
    final localOpportunities = city.jobOpportunities;
    final employmentScore = localOpportunities * 1.5 +
        nearbyOpportunities * (nearbyCities.length == 1 ? 0.5 : 0.25);
    final opportunityFactor =
        (employmentScore / max(city.population * 0.08, 1)).clamp(0.0, 2.5);
    final targetSalary = 850 + opportunityFactor * 420;
    final change = (targetSalary - city.averageSalary) * 0.12;
    city.averageSalary = (city.averageSalary + change).clamp(700, 4200);
  }

  void _simulateProduction() {
    for (final city in _cities) {
      final buildingsHere = _buildingsNear(city);
      city.jobOpportunities = buildingsHere.fold<int>(
        0,
        (sum, building) => sum + building.type.storageCapacity ~/ 10,
      );

      for (final building in buildingsHere) {
        if (!building.type.isProducer) continue;

        for (final productId in building.products) {
          final def = _catalog.byId(productId);
          if (def == null) continue;

          // Factory: need inputs from warehouse
          if (building.type == BuildingType.factory) {
            final warehouse = _findInputWarehouse(building, city);
            if (warehouse == null) continue;

            var canProduce = true;
            for (final entry in def.inputs.entries) {
              final inputStock = city.stock[entry.key] ?? 0;
              if (inputStock < entry.value) {
                canProduce = false;
                break;
              }
            }
            if (!canProduce) continue;

            // Consume inputs
            for (final entry in def.inputs.entries) {
              city.stock[entry.key] =
                  (city.stock[entry.key] ?? 0) - entry.value;
            }
          }

          // Produce output
          final produced = def.outputPerDay;
          city.stock[productId] = (city.stock[productId] ?? 0) + produced;
          city.produced[productId] =
              (city.produced[productId] ?? 0) + produced;

          // Try to send surplus to connected warehouse
          _sendToWarehouse(building, city, productId, produced);
        }
      }
    }
  }

  Building? _findInputWarehouse(Building factory, City city) {
    if (factory.inputWarehouseId != null) {
      final warehouse =
          _buildings.where((b) => b.id == factory.inputWarehouseId).firstOrNull;
      if (warehouse != null) return warehouse;
    }
    // Default: find nearest warehouse with road connection
    final warehouses = _buildings
        .where((b) => b.type == BuildingType.warehouse)
        .where((b) =>
            (b.x - factory.x).abs() <= 3 && (b.y - factory.y).abs() <= 3)
        .toList();
    if (warehouses.isNotEmpty) return warehouses.first;
    return _buildings
        .where((b) => b.type == BuildingType.warehouse)
        .firstOrNull;
  }

  void _sendToWarehouse(
      Building producer, City city, String productId, int amount) {
    if (amount <= 0) return;
    final warehouse = _buildings
        .where((b) =>
            b.type == BuildingType.warehouse &&
            b.products.contains(productId) &&
            (_cityNearBuilding(b) == city ||
                _hasRoadConnection(city, _cityNearBuilding(b) ?? city)))
        .firstOrNull;
    if (warehouse == null) return;

    // Transfer half the production to warehouse stock
    final transfer = (amount * 0.5).round();
    final warehouseCity = _cityNearBuilding(warehouse);
    if (warehouseCity == null) return;

    final transferred = min(transfer, city.stock[productId] ?? 0);
    if (transferred <= 0) return;

    city.stock[productId] = (city.stock[productId] ?? 0) - transferred;
    warehouseCity.stock[productId] =
        (warehouseCity.stock[productId] ?? 0) + transferred;
  }

  City? _cityNearBuilding(Building building) {
    return _cities.where((c) =>
        (c.x - building.x).abs() <= 1 && (c.y - building.y).abs() <= 1).firstOrNull;
  }

  bool _canProduce(City city, String productId) => _buildings.any(
        (building) =>
            (building.x - city.x).abs() <= 1 &&
            (building.y - city.y).abs() <= 1 &&
            building.products.contains(productId) &&
            building.type.isProducer,
      );

  bool _hasStoreSelling(City city, String productId) => _buildings.any(
        (building) =>
            (building.x - city.x).abs() <= 1 &&
            (building.y - city.y).abs() <= 1 &&
            building.type == BuildingType.store &&
            building.storeAccepts.contains(productId),
      );

  void _simulateTrade() {
    for (final seller in _cities) {
      for (final buyer in seller.tradePartners) {
        for (final product in _catalog.allProducts) {
          if (!_canProduce(seller, product.id)) continue;
          if (!_hasStoreSelling(seller, product.id)) continue;
          final available = seller.stock[product.id] ?? 0;
          final shortage = _consumerDemand(buyer, product) -
              (buyer.stock[product.id] ?? 0);
          final maxUnits = min(available, max(0, shortage));
          if (maxUnits < 2) continue;

          final sellerPrice =
              seller.prices[product.id] ?? product.basePrice;
          final buyerPrice =
              buyer.prices[product.id] ?? product.basePrice;
          if (sellerPrice >= buyerPrice * 1.12) continue;

          final salaryFactor = (buyer.averageSalary / 1200).clamp(0.45, 2.5);
          final units = min(
            maxUnits,
            max(1, (4 + _random.nextInt(9)) * salaryFactor).round(),
          );
          final unitPrice = sellerPrice * 1.05;
          final revenue = (unitPrice * units).round();
          final profit =
              revenue - (product.basePrice * units * 0.65).round();

          seller.stock[product.id] = available - units;
          buyer.stock[product.id] =
              (buyer.stock[product.id] ?? 0) + units;
          buyer.prices[product.id] =
              (buyer.prices[product.id] ?? product.basePrice) * 0.94;
          seller.prices[product.id] =
              (seller.prices[product.id] ?? product.basePrice) * 1.03;
          _tradesToday++;
          _recordTransaction(MarketTransaction(
            day: _day,
            type: TransactionType.trade,
            fromCity: seller.name,
            toCity: buyer.name,
            product: product.name,
            units: units,
            unitPrice: unitPrice,
            amount: revenue,
            profit: profit,
            description:
                '${seller.name} sold $units ${product.name} to ${buyer.name}',
            createdAt: DateTime.now(),
          ));
        }
      }
    }
  }

  int _consumerDemand(City city, ProductDefinition product) {
    return (city.population * product.consumerDemand).round();
  }

  void _simulateConsumers() {
    for (final city in _cities) {
      for (final product in _catalog.allProducts) {
        final price = city.prices[product.id] ?? product.basePrice;
        final affordability =
            (product.basePrice / max(price, 0.1)).clamp(0.05, 1.2);
        final demand =
            (_consumerDemand(city, product) * affordability).round();
        if (!_hasStoreSelling(city, product.id)) continue;
        final units = min(city.stock[product.id] ?? 0, demand);
        if (units <= 0) continue;
        city.stock[product.id] = (city.stock[product.id] ?? 0) - units;
        city.sold[product.id] = (city.sold[product.id] ?? 0) + units;
        final revenue = (price * units).round();
        final profit = (revenue * 0.22).round();
        if (city.name == 'Your Capital') _cash += profit;
        _recordTransaction(MarketTransaction(
          day: _day,
          type: TransactionType.consumerSale,
          fromCity: city.name,
          toCity: 'Consumers',
          product: product.name,
          units: units,
          unitPrice: price,
          amount: revenue,
          profit: profit,
          description:
              '${city.name} sold $units ${product.name} to consumers',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  void _updatePrices() {
    for (final city in _cities) {
      for (final product in _catalog.allProducts) {
        final stock = city.stock[product.id] ?? 0;
        final sold = city.sold[product.id] ?? 0;
        final pressure =
            stock > 80 ? -0.04 : stock < 15 ? 0.07 : 0.0;
        final demandPressure = sold > 0 ? 0.025 : -0.015;
        final current =
            city.prices[product.id] ?? product.basePrice;
        final next =
            (current * (1 + pressure + demandPressure)).clamp(
          product.basePrice * 0.45,
          product.basePrice * 2.1,
        );
        city.prices[product.id] =
            double.parse(next.toStringAsFixed(2));
        city.sold[product.id] = 0;
      }
    }
  }

  void _recordTransaction(MarketTransaction transaction) {
    MarketDatabase.instance.insert(transaction).catchError((Object error) {
      if (mounted) {
        debugPrint('Could not save transaction: $error');
      }
      return 0;
    });
  }

  Future<T?> _dialog<T>(WidgetBuilder builder) {
    return showDialog<T>(context: context, builder: builder).then((result) {
      _lastDialogClosedAt = DateTime.now();
      return result;
    });
  }

  bool _dialogSettling() {
    final last = _lastDialogClosedAt;
    return last != null &&
        DateTime.now().difference(last).inMilliseconds < 300;
  }

  void _showTransactions() {
    if (_dialogSettling()) return;
    _dialog<void>((context) => const _TransactionsDialog());
  }

  void _selectBuildingType(BuildingType type) {
    setState(() {
      _selectedBuilding = _selectedBuilding == type ? null : type;
    });
  }

  void _showCityPopup(City city) {
    _dialog<void>(
      (context) =>
          _CityDialog(city: city, buildings: _buildings, catalog: _catalog),
    );
  }

  void _showPopup(String title, String message) {
    _dialog<void>(
      (context) => AlertDialog(
        icon:
            const Icon(Icons.info_outline_rounded, color: Color(0xFF167D5A)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _terrainColor(Terrain terrain) => switch (terrain) {
        Terrain.grass => const Color(0xFFB7D7A8),
        Terrain.forest => const Color(0xFF6EA879),
        Terrain.water => const Color(0xFF8BC5D6),
        Terrain.mountain => const Color(0xFFAAA39A),
      };

  IconData? _buildingIcon(int x, int y) {
    for (final building in _buildings) {
      if (building.x == x && building.y == y) return building.type.icon;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_catalog.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF167D5A)),
            SizedBox(width: 10),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Inspect transactions',
            onPressed: _showTransactions,
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          const SizedBox(width: 4),
          _CashPill(cash: _cash),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton.icon(
              onPressed: _advanceDay,
              icon: const Icon(Icons.fast_forward_rounded),
              label: Text('Day $_day'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsBar(
            cities: _cities.length,
            businesses: _buildings.length,
            day: _day,
            consumers: _totalConsumers,
            trades: _tradesToday,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidebar = constraints.maxWidth >= 850;
                final map = _MapView(
                  tiles: _tiles,
                  cities: _cities,
                  buildings: _buildings,
                  selectedBuilding: _selectedBuilding,
                  showCities: _showCities,
                  onTileTap: _handleTileTap,
                  terrainColor: _terrainColor,
                  buildingIcon: _buildingIcon,
                );
                if (!sidebar) {
                  return Column(
                    children: [
                      Expanded(child: map),
                      _BuildBar(
                        selected: _selectedBuilding,
                        onSelected: _selectBuildingType,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: map),
                    _BuildSidebar(
                      selected: _selectedBuilding,
                      onSelected: _selectBuildingType,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.items,
    required this.initialSelected,
  });

  final String title;
  final List<ProductDefinition> items;
  final Set<String> initialSelected;

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<String> _selected = Set.from(widget.initialSelected);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.items.map((product) {
              final selected = _selected.contains(product.id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected,
                secondary: Icon(product.icon),
                title: Text(product.name),
                onChanged: (value) => setState(() {
                  if (value ?? false) {
                    _selected.add(product.id);
                  } else {
                    _selected.remove(product.id);
                  }
                }),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BuildingDialog extends StatelessWidget {
  const _BuildingDialog({
    required this.building,
    required this.catalog,
    this.onProductsChanged,
    this.onStoreAcceptsChanged,
    this.onWarehouseProductsChanged,
    this.onInputWarehouseChanged,
    this.warehouses = const [],
    this.tiles = const {},
  });

  final Building building;
  final ProductCatalog catalog;
  final ValueChanged<Set<String>>? onProductsChanged;
  final ValueChanged<Set<String>>? onStoreAcceptsChanged;
  final ValueChanged<Set<String>>? onWarehouseProductsChanged;
  final ValueChanged<int>? onInputWarehouseChanged;
  final List<Building> warehouses;
  final Map<String, Tile> tiles;

  /// Pops this dialog, then opens the child selection dialog after the
  /// parent route has fully completed its dismissal animation. This avoids
  /// pushing a new route while the old one is mid-pop, which corrupts the
  /// Focus scope dependencies.
  void _openChildDialog(
    BuildContext context,
    String title,
    List<ProductDefinition> items,
    Set<String> initialSelected,
    ValueChanged<Set<String>> onChanged,
  ) {
    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 350), () {
      showDialog<Set<String>>(
        context: MarketSimulationApp.navigatorKey.currentContext!,
        builder: (context) => _MultiSelectDialog(
          title: title,
          items: items,
          initialSelected: initialSelected,
        ),
      ).then((selected) {
        if (selected != null) onChanged(selected);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(building.type.icon, color: const Color(0xFF167D5A)),
          const SizedBox(width: 10),
          Expanded(child: Text(building.type.label)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Location: (${building.x}, ${building.y})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Factory / Extractor production
              if (building.type.isProducer) ...[
                const Text('Produces',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (building.products.isEmpty)
                  const Text('Nothing configured.',
                      style: TextStyle(color: Color(0xFF8A5A00)))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: building.products.map((id) {
                      final def = catalog.byId(id);
                      if (def == null) return const SizedBox.shrink();
                      return Chip(
                        avatar: Icon(def.icon, size: 17),
                        label: Text(def.name),
                      );
                    }).toList(),
                  ),
                if (onProductsChanged != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openChildDialog(
                      context,
                      'Change production',
                      building.type == BuildingType.factory
                          ? catalog.factoryProducts
                          : catalog.extractorProducts,
                      building.products,
                      onProductsChanged!,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: const Text('Change production'),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // Factory input warehouse
              if (building.type == BuildingType.factory &&
                  onInputWarehouseChanged != null) ...[
                const Text('Input warehouse',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  isExpanded: true,
                  value: building.inputWarehouseId,
                  hint: const Text('Select warehouse'),
                  items: warehouses.map((warehouse) {
                    return DropdownMenuItem<int>(
                      value: warehouse.id,
                      child: Text(
                        'Warehouse at (${warehouse.x}, ${warehouse.y})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) onInputWarehouseChanged!(value);
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Store inventory
              if (building.type == BuildingType.store) ...[
                const Text('Sells',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (building.storeAccepts.isEmpty)
                  const Text('Nothing configured.',
                      style: TextStyle(color: Color(0xFF8A5A00)))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: building.storeAccepts.map((id) {
                      final def = catalog.byId(id);
                      if (def == null) return const SizedBox.shrink();
                      return Chip(
                        avatar: Icon(def.icon, size: 17),
                        label: Text(def.name),
                      );
                    }).toList(),
                  ),
                if (onStoreAcceptsChanged != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openChildDialog(
                      context,
                      'Change store inventory',
                      catalog.allProducts,
                      building.storeAccepts,
                      onStoreAcceptsChanged!,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: const Text('Change inventory'),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // Warehouse storage
              if (building.type == BuildingType.warehouse) ...[
                const Text('Stores',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (building.products.isEmpty)
                  const Text('Nothing configured.',
                      style: TextStyle(color: Color(0xFF8A5A00)))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: building.products.map((id) {
                      final def = catalog.byId(id);
                      if (def == null) return const SizedBox.shrink();
                      return Chip(
                        avatar: Icon(def.icon, size: 17),
                        label: Text(def.name),
                      );
                    }).toList(),
                  ),
                if (onWarehouseProductsChanged != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openChildDialog(
                      context,
                      'Change warehouse storage',
                      catalog.allProducts,
                      building.products,
                      onWarehouseProductsChanged!,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: const Text('Change storage'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _TransactionsDialog extends StatefulWidget {
  const _TransactionsDialog();

  @override
  State<_TransactionsDialog> createState() => _TransactionsDialogState();
}

class _TransactionsDialogState extends State<_TransactionsDialog> {
  late Future<List<MarketTransaction>> _transactions;
  TransactionType? _filter;

  @override
  void initState() {
    super.initState();
    _transactions = MarketDatabase.instance.all();
  }

  void _reload() {
    setState(() {
      _transactions = MarketDatabase.instance.all(type: _filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transactions'),
      content: SizedBox(
        width: 760,
        height: 480,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    selected: _filter == null,
                    label: const Text('All'),
                    onSelected: (_) {
                      _filter = null;
                      _reload();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...TransactionType.values.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _filter == type,
                        label: Text(type.label),
                        onSelected: (_) {
                          _filter = type;
                          _reload();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<MarketTransaction>>(
                future: _transactions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                          'Could not load transactions:\n${snapshot.error}'),
                    );
                  }
                  final transactions = snapshot.data ?? const [];
                  if (transactions.isEmpty) {
                    return const Center(
                      child: Text('No transactions have been recorded yet.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          switch (transaction.type) {
                            TransactionType.trade =>
                              Icons.swap_horiz_rounded,
                            TransactionType.consumerSale =>
                              Icons.shopping_bag_rounded,
                            TransactionType.buildingPurchase =>
                              Icons.domain_rounded,
                            TransactionType.revenue =>
                              Icons.attach_money_rounded,
                          },
                        ),
                        title: Text(transaction.description),
                        subtitle: Text(
                          'Day ${transaction.day} · ${transaction.type.label}'
                          '${transaction.product.isEmpty ? '' : ' · ${transaction.product}'}'
                          '${transaction.units > 0 ? ' · ${transaction.units} units' : ''}',
                        ),
                        trailing: Text(
                          '\$${transaction.amount}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: transaction.amount >= 0
                                ? const Color(0xFF167D5A)
                                : const Color(0xFFC0392B),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await MarketDatabase.instance.clear();
            _reload();
          },
          child: const Text('Clear history'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _CityDialog extends StatelessWidget {
  const _CityDialog({
    required this.city,
    required this.buildings,
    required this.catalog,
  });

  final City city;
  final List<Building> buildings;
  final ProductCatalog catalog;

  bool _hasStoreSelling(City city, String productId) => buildings.any(
        (building) =>
            (building.x - city.x).abs() <= 1 &&
            (building.y - city.y).abs() <= 1 &&
            building.type == BuildingType.store &&
            building.storeAccepts.contains(productId),
      );

  int _nearbyWorkOpportunities(City city) {
    return city.tradePartners
        .where((partner) =>
            (partner.x - city.x).abs() + (partner.y - city.y).abs() <= 12)
        .fold<int>(0, (sum, partner) => sum + partner.jobOpportunities);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            city.name == 'Your Capital'
                ? Icons.star_rounded
                : Icons.location_city_rounded,
            color: city.name == 'Your Capital'
                ? const Color(0xFF167D5A)
                : const Color(0xFF334E68),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(city.name)),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${city.population} consumers · ${city.tradePartners.length} trade connections',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Average salary: \$${city.averageSalary.toStringAsFixed(0)} · '
                '${city.jobOpportunities} local jobs · ${_nearbyWorkOpportunities(city)} nearby opportunities',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF486581),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Local market',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...catalog.allProducts.map(
                (product) {
                  final producerUnits = city.produced[product.id] ?? 0;
                  final hasProducer = producerUnits > 0;
                  final hasStore = _hasStoreSelling(city, product.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(product.icon, size: 19),
                            const SizedBox(width: 8),
                            Expanded(child: Text(product.name)),
                            Text(
                                '${city.stock[product.id] ?? 0} in stock'),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '\$${(city.prices[product.id] ?? 0).toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasProducer && hasStore
                              ? '$producerUnits producer units/day · Store selling'
                              : hasProducer
                                  ? '$producerUnits producer units/day · No store (cannot sell)'
                                  : hasStore
                                      ? 'No producer · Store selling'
                                      : 'No producer · No store',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasProducer && hasStore
                                ? const Color(0xFF167D5A)
                                : const Color(0xFF8A5A00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text('City businesses',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...buildings
                  .where((building) =>
                      (building.x - city.x).abs() <= 1 &&
                      (building.y - city.y).abs() <= 1)
                  .map(
                (building) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(building.type.icon, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(building.type.label)),
                      Flexible(
                        child: Text(
                          building.type.isProducer &&
                                  building.products.isNotEmpty
                              ? building.products
                                  .map((id) =>
                                      catalog.byId(id)?.name ?? id)
                                  .join(', ')
                              : building.type == BuildingType.store &&
                                      building.storeAccepts.isNotEmpty
                                  ? building.storeAccepts
                                      .map((id) =>
                                          catalog.byId(id)?.name ?? id)
                                      .join(', ')
                                  : building.type ==
                                              BuildingType.warehouse &&
                                          building.products.isNotEmpty
                                      ? building.products
                                          .map((id) =>
                                              catalog.byId(id)?.name ??
                                              id)
                                          .join(', ')
                                      : 'No products configured',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              const Text('Trade partners',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (city.tradePartners.isEmpty)
                const Text(
                    'No connected cities. Trade requires a road connection.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: city.tradePartners
                      .map((partner) => Chip(
                            avatar: const Icon(Icons.route_rounded,
                                size: 17),
                            label: Text(partner.name),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _CashPill extends StatelessWidget {
  const _CashPill({required this.cash});

  final int cash;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              size: 18, color: Color(0xFF167D5A)),
          const SizedBox(width: 7),
          Text(
            '\$$cash',
            style: const TextStyle(
              color: Color(0xFF126B4C),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.cities,
    required this.businesses,
    required this.day,
    required this.consumers,
    required this.trades,
  });

  final int cities;
  final int businesses;
  final int day;
  final int consumers;
  final int trades;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _Stat(
              icon: Icons.location_city_rounded, label: '$cities cities'),
          _Stat(
              icon: Icons.apartment_rounded,
              label: '$businesses businesses'),
          _Stat(
              icon: Icons.calendar_today_rounded, label: 'Day $day'),
          _Stat(
            icon: Icons.people_alt_rounded,
            label: '${NumberFormat.compact(consumers)} consumers',
          ),
          _Stat(
              icon: Icons.swap_horiz_rounded,
              label: '$trades trades today'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF627D98)),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView({
    required this.tiles,
    required this.cities,
    required this.buildings,
    required this.selectedBuilding,
    required this.showCities,
    required this.onTileTap,
    required this.terrainColor,
    required this.buildingIcon,
  });

  final Map<String, Tile> tiles;
  final List<City> cities;
  final List<Building> buildings;
  final BuildingType? selectedBuilding;
  final bool showCities;
  final void Function(int, int) onTileTap;
  final Color Function(Terrain) terrainColor;
  final IconData? Function(int, int) buildingIcon;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final TransformationController _transformController =
      TransformationController();

  Map<String, Tile> get _tiles => widget.tiles;
  List<City> get _cities => widget.cities;
  bool get _showCities => widget.showCities;
  void Function(int, int) get _onTileTap => widget.onTileTap;
  Color Function(Terrain) get _terrainColor => widget.terrainColor;
  IconData? Function(int, int) get _buildingIcon => widget.buildingIcon;

  int _roadNeighbors(int x, int y) {
    var mask = 0;
    if (_tiles['$x,${y - 1}']?.road ?? false) mask |= 1; // North
    if (_tiles['${x + 1},$y']?.road ?? false) mask |= 2; // East
    if (_tiles['$x,${y + 1}']?.road ?? false) mask |= 4; // South
    if (_tiles['${x - 1},$y']?.road ?? false) mask |= 8; // West
    return mask;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0EA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD9E2EC)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D102A43),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 2;
            final availableHeight = constraints.maxHeight - 2;
            final tileSize = min(
              availableWidth / _GameScreenState.mapWidth,
              availableHeight / _GameScreenState.mapHeight,
            ).clamp(18.0, 72.0);
            final mapWidth = tileSize * _GameScreenState.mapWidth;
            final mapHeight = tileSize * _GameScreenState.mapHeight;
            return InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              minScale: 0.55,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(120),
              clipBehavior: Clip.none,
              panEnabled: true,
              scaleEnabled: true,
              trackpadScrollCausesScale: false,
              child: SizedBox(
                width: mapWidth + 2,
                height: mapHeight + 2,
                child: Stack(
                  children: [
                    Positioned(
                      left: 1,
                      top: 1,
                      width: mapWidth,
                      height: mapHeight,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _GameScreenState.mapWidth,
                        ),
                        itemCount: _GameScreenState.mapWidth *
                            _GameScreenState.mapHeight,
                        itemBuilder: (context, index) {
                          final x = index % _GameScreenState.mapWidth;
                          final y = index ~/ _GameScreenState.mapWidth;
                          final tile = _tiles['$x,$y']!;
                          return InkWell(
                            onTap: () => _onTileTap(x, y),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _terrainColor(tile.terrain),
                                border: Border.all(
                                  color: const Color(0x160F172A),
                                  width: 0.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  if (tile.road)
                                    CustomPaint(
                                      painter: _RoadPainter(
                                        neighbors: _roadNeighbors(x, y),
                                        tileSize: tileSize,
                                      ),
                                      size: Size.square(tileSize),
                                    ),
                                  if (_buildingIcon(x, y) != null)
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: tileSize * 0.48,
                                        height: tileSize * 0.48,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _buildingIcon(x, y),
                                          size: tileSize * 0.28,
                                          color: const Color(0xFF167D5A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    for (final city in _cities)
                      if (_showCities)
                        Positioned(
                          left: city.x * tileSize + 1,
                          top: city.y * tileSize + 1,
                          width: tileSize,
                          height: tileSize,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: city.name == 'Your Capital'
                                      ? const Color(0xFF167D5A)
                                      : const Color(0xFF334E68),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  city.name == 'Your Capital'
                                      ? Icons.star_rounded
                                      : Icons.location_city_rounded,
                                  color: Colors.white,
                                  size: tileSize * 0.38,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({
    required this.neighbors,
    required this.tileSize,
  });

  final int neighbors;
  final double tileSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final roadWidth = tileSize * 0.14;
    final glowWidth = roadWidth * 2.4;

    final glowPaint = Paint()
      ..color = const Color(0x33D2B48C)
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round;

    final roadPaint = Paint()
      ..color = const Color(0xFFD2B48C)
      ..strokeWidth = roadWidth
      ..strokeCap = StrokeCap.round;

    _drawConnections(canvas, center, roadWidth, glowPaint);
    _drawConnections(canvas, center, roadWidth, roadPaint);
  }

  void _drawConnections(
      Canvas canvas, Offset center, double width, Paint paint) {
    if (neighbors & 1 != 0) {
      canvas.drawLine(
          center + Offset(0, -tileSize / 2), center, paint);
    }
    if (neighbors & 2 != 0) {
      canvas.drawLine(
          center + Offset(tileSize / 2, 0), center, paint);
    }
    if (neighbors & 4 != 0) {
      canvas.drawLine(
          center + Offset(0, tileSize / 2), center, paint);
    }
    if (neighbors & 8 != 0) {
      canvas.drawLine(
          center + Offset(-tileSize / 2, 0), center, paint);
    }
    if (neighbors == 0) {
      canvas.drawCircle(center, width * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return oldDelegate.neighbors != neighbors ||
        oldDelegate.tileSize != tileSize;
  }
}

class _BuildBar extends StatelessWidget {
  const _BuildBar({
    required this.selected,
    required this.onSelected,
  });

  final BuildingType? selected;
  final ValueChanged<BuildingType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: BuildingType.values
                  .map((type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _BuildButton(
                          type: type,
                          selected: selected == type,
                          onTap: () => onSelected(type),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildSidebar extends StatelessWidget {
  const _BuildSidebar({
    required this.selected,
    required this.onSelected,
  });

  final BuildingType? selected;
  final ValueChanged<BuildingType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Build business',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Choose a business, then select an available tile on the map.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 18),
          ...BuildingType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BuildButton(
                type: type,
                selected: selected == type,
                onTap: () => onSelected(type),
                expanded: true,
              ),
            ),
          ),
          const Spacer(),
          const _MarketSummary(),
          const SizedBox(height: 16),
          const _MapLegend(),
        ],
      ),
    );
  }
}

class _MarketSummary extends StatelessWidget {
  const _MarketSummary();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFF7F9FC),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.trending_up_rounded, color: Color(0xFF167D5A)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Extractors produce raw materials. Factories produce goods from inputs. Stores sell to consumers. Warehouses store and transfer goods.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildButton extends StatelessWidget {
  const _BuildButton({
    required this.type,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final BuildingType type;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE8F6EF)
              : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF167D5A)
                : const Color(0xFFD9E2EC),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize:
              expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF167D5A)
                    : const Color(0xFFE6EDF3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type.icon,
                color: selected
                    ? Colors.white
                    : const Color(0xFF486581),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '\$${type.cost}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return expanded
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
            color: Color(0xFFB7D7A8), label: 'Grass'),
        _LegendItem(
            color: Color(0xFF6EA879), label: 'Forest'),
        _LegendItem(
            color: Color(0xFF8BC5D6), label: 'Water'),
        _LegendItem(
            color: Color(0xFFAAA39A), label: 'Mountain'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class NumberFormat {
  static String compact(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return '$number';
  }
}
