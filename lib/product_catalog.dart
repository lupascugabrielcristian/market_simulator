import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class ProductDefinition {
  const ProductDefinition({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.outputPerDay,
    required this.consumerDemand,
    required this.inputs,
  });

  final String id;
  final String name;
  final double basePrice;
  final int outputPerDay;
  final double consumerDemand;
  final Map<String, int> inputs;

  IconData get icon => switch (id) {
        'wood' => Icons.forest_rounded,
        'aluminium' => Icons.layers_rounded,
        'iron' => Icons.hexagon_rounded,
        'stone' => Icons.landscape_rounded,
        'grain' => Icons.grass_rounded,
        'fruit' => Icons.apple_rounded,
        'cotton' => Icons.cloud_rounded,
        'bread' => Icons.bakery_dining_rounded,
        'brick' => Icons.domain_rounded,
        'cloths' => Icons.checkroom_rounded,
        'tools' => Icons.handyman_rounded,
        'car' => Icons.directions_car_rounded,
        _ => Icons.inventory_2_rounded,
      };
}

class ProductCatalog {
  ProductDefinition? byId(String id) => _byId[id];

  final Map<String, ProductDefinition> _byId = {};
  final List<ProductDefinition> extractorProducts = [];
  final List<ProductDefinition> factoryProducts = [];
  final List<ProductDefinition> allProducts = [];

  static final ProductCatalog instance = ProductCatalog._();
  bool _loaded = false;
  bool get isLoaded => _loaded;

  ProductCatalog._();

  Future<void> load() async {
    if (_loaded) return;
    final extractorsJson = await rootBundle.loadString(
      'assets/data/extractors.json',
    );
    final factoriesJson = await rootBundle.loadString(
      'assets/data/factories.json',
    );

    final extractors =
        jsonDecode(extractorsJson)['products'] as List<dynamic>;
    final factories =
        jsonDecode(factoriesJson)['products'] as List<dynamic>;

    for (final item in extractors) {
      final def = ProductDefinition(
        id: item['id'] as String,
        name: item['name'] as String,
        basePrice: (item['basePrice'] as num).toDouble(),
        outputPerDay: item['outputPerDay'] as int,
        consumerDemand: (item['consumerDemand'] as num).toDouble(),
        inputs: {},
      );
      extractorProducts.add(def);
      allProducts.add(def);
      _byId[def.id] = def;
    }

    for (final item in factories) {
      final rawInputs = item['inputs'] as Map<String, dynamic>;
      final def = ProductDefinition(
        id: item['id'] as String,
        name: item['name'] as String,
        basePrice: (item['basePrice'] as num).toDouble(),
        outputPerDay: item['outputPerDay'] as int,
        consumerDemand: (item['consumerDemand'] as num).toDouble(),
        inputs: rawInputs.map(
          (key, value) => MapEntry(key, value as int),
        ),
      );
      factoryProducts.add(def);
      allProducts.add(def);
      _byId[def.id] = def;
    }

    _loaded = true;
  }
}
