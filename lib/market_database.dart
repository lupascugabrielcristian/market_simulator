import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

enum TransactionType { trade, consumerSale, buildingPurchase, revenue }

extension TransactionTypeInfo on TransactionType {
  String get databaseValue => switch (this) {
        TransactionType.trade => 'trade',
        TransactionType.consumerSale => 'consumer_sale',
        TransactionType.buildingPurchase => 'building_purchase',
        TransactionType.revenue => 'revenue',
      };

  String get label => switch (this) {
        TransactionType.trade => 'City trade',
        TransactionType.consumerSale => 'Consumer sale',
        TransactionType.buildingPurchase => 'Building purchase',
        TransactionType.revenue => 'Revenue',
      };
}

class MarketTransaction {
  const MarketTransaction({
    this.id,
    required this.day,
    required this.type,
    required this.fromCity,
    required this.toCity,
    required this.product,
    required this.units,
    required this.unitPrice,
    required this.amount,
    required this.profit,
    required this.description,
    required this.createdAt,
  });

  final int? id;
  final int day;
  final TransactionType type;
  final String fromCity;
  final String toCity;
  final String product;
  final int units;
  final double unitPrice;
  final int amount;
  final int profit;
  final String description;
  final DateTime createdAt;

  factory MarketTransaction.fromMap(Map<String, Object?> map) {
    return MarketTransaction(
      id: map['id'] as int?,
      day: map['day'] as int,
      type: TransactionType.values.firstWhere(
        (type) => type.databaseValue == map['type'],
        orElse: () => TransactionType.trade,
      ),
      fromCity: map['from_city'] as String,
      toCity: map['to_city'] as String,
      product: map['product'] as String,
      units: map['units'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      amount: map['amount'] as int,
      profit: map['profit'] as int,
      description: map['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, Object?> toMap() => {
        'day': day,
        'type': type.databaseValue,
        'from_city': fromCity,
        'to_city': toCity,
        'product': product,
        'units': units,
        'unit_price': unitPrice,
        'amount': amount,
        'profit': profit,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

class SavedBuilding {
  const SavedBuilding({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    required this.products,
  });

  final int id;
  final int x;
  final int y;
  final String type;
  final List<String> products;

  factory SavedBuilding.fromMap(Map<String, Object?> map) {
    return SavedBuilding(
      id: map['id'] as int,
      x: map['x'] as int,
      y: map['y'] as int,
      type: map['type'] as String,
      products: List<String>.from(
        jsonDecode(map['products'] as String) as List<dynamic>,
      ),
    );
  }

  Map<String, Object?> toMap() => {
        'x': x,
        'y': y,
        'type': type,
        'products': jsonEncode(products),
      };
}

class MarketDatabase {
  MarketDatabase._();

  static final MarketDatabase instance = MarketDatabase._();
  static const _databaseName = 'market_transactions.db';
  static const _databaseVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);
    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day INTEGER NOT NULL,
            type TEXT NOT NULL,
            from_city TEXT NOT NULL,
            to_city TEXT NOT NULL,
            product TEXT NOT NULL,
            units INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            amount INTEGER NOT NULL,
            profit INTEGER NOT NULL,
            description TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX transactions_day_idx ON transactions(day)',
        );
        await database.execute(
          'CREATE INDEX transactions_type_idx ON transactions(type)',
        );
        await database.execute('''
          CREATE TABLE buildings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            type TEXT NOT NULL,
            products TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE TABLE buildings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              x INTEGER NOT NULL,
              y INTEGER NOT NULL,
              type TEXT NOT NULL,
              products TEXT NOT NULL
            )
          ''');
        }
      },
    );
    return _database!;
  }

  Future<int> insert(MarketTransaction transaction) async {
    final db = await database;
    return db.insert('transactions', transaction.toMap());
  }

  Future<List<MarketTransaction>> all({TransactionType? type}) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type.databaseValue],
      orderBy: 'id DESC',
    );
    return rows.map(MarketTransaction.fromMap).toList();
  }

  Future<int> count() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS total FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('transactions');
  }

  Future<int> insertBuilding(SavedBuilding building) async {
    final db = await database;
    return db.insert('buildings', building.toMap());
  }

  Future<List<SavedBuilding>> allBuildings() async {
    final db = await database;
    final rows = await db.query('buildings', orderBy: 'id');
    return rows.map(SavedBuilding.fromMap).toList();
  }

  Future<void> updateBuilding(int id, List<String> products) async {
    final db = await database;
    await db.update(
      'buildings',
      {'products': jsonEncode(products)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBuilding(int id) async {
    final db = await database;
    await db.delete('buildings', where: 'id = ?', whereArgs: [id]);
  }
}
