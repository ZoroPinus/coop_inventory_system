import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart' as app_models;

class LocalDatabaseService {
  static sqflite.Database? _database;
  static const String dbName = 'farm_coop_pos.db';
  static const int dbVersion = 1;

  static Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<sqflite.Database> _initDatabase() async {
    String path = join(await sqflite.getDatabasesPath(), dbName);
    return await sqflite.openDatabase(
      path,
      version: dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createTables(sqflite.Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT,
        sync_status INTEGER DEFAULT 1,
        local_id TEXT
      )
    ''');

    // Products table with category name for efficient queries
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        category_name TEXT,
        cost_price REAL,
        selling_price REAL NOT NULL,
        current_stock INTEGER DEFAULT 0,
        minimum_stock_level INTEGER DEFAULT 0,
        unit_of_measure TEXT DEFAULT 'pieces',
        supplier_name TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        sync_status INTEGER DEFAULT 1,
        local_id TEXT
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY,
        total_amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        cashier_name TEXT,
        transaction_date TEXT,
        sync_status INTEGER DEFAULT 0,
        local_id TEXT UNIQUE
      )
    ''');

    // Transaction items table
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY,
        transaction_id INTEGER,
        product_id INTEGER,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        sync_status INTEGER DEFAULT 0,
        local_transaction_id TEXT
      )
    ''');

    // Sync queue table for tracking changes
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        created_at TEXT,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Insert default categories
    await db.insert('categories', {
      'id': 1,
      'name': 'Seeds & Seedlings',
      'description': 'Various seeds and young plants',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 1,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    await db.insert('categories', {
      'id': 2,
      'name': 'Fertilizers',
      'description': 'Organic and synthetic fertilizers',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 1,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    await db.insert('categories', {
      'id': 3,
      'name': 'Tools & Equipment',
      'description': 'Farming tools and equipment',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 1,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    await db.insert('categories', {
      'id': 4,
      'name': 'Pesticides',
      'description': 'Pest control products',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 1,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    await db.insert('categories', {
      'id': 5,
      'name': 'Fresh Produce',
      'description': 'Harvested farm products',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 1,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  static Future<void> _onUpgrade(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle database upgrades here
  }

  // Categories
  static Future<List<Category>> getLocalCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'name');
    return result.map((json) => Category.fromJson(json)).toList();
  }

  static Future<int> insertCategory(Category category) async {
    final db = await database;
    final data = category.toJson();
    data['sync_status'] = 0; // Needs sync
    data['local_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    data['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('categories', data);
  }

  static Future<void> updateCategoryServerId(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'categories',
      {'id': serverId, 'sync_status': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // Products
  static Future<List<Product>> getLocalProducts() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1
      ORDER BY p.name
    ''');

    // Debug: print first product to see data structure
    if (result.isNotEmpty) {
      print('Sample product data from SQLite: ${result.first}');
    }

    return result.map((json) => Product.fromJson(json)).toList();
  }

  static Future<int> insertProduct(Product product) async {
    final db = await database;
    final data = product.toJson();
    data['sync_status'] = 0; // Needs sync
    data['local_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();

    // Get category name
    final category = await db.query(
      'categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [product.categoryId],
    );
    if (category.isNotEmpty) {
      data['category_name'] = category.first['name'];
    }

    return await db.insert('products', data);
  }

  static Future<void> updateProduct(Product product) async {
    final db = await database;
    final data = product.toJson();
    data['sync_status'] = 0; // Needs sync
    data['updated_at'] = DateTime.now().toIso8601String();

    // Get category name
    final category = await db.query(
      'categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [product.categoryId],
    );
    if (category.isNotEmpty) {
      data['category_name'] = category.first['name'];
    }

    await db.update('products', data, where: 'id = ?', whereArgs: [product.id]);
  }

  static Future<void> updateProductServerId(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'products',
      {'id': serverId, 'sync_status': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  static Future<void> markProductSynced(int productId) async {
    final db = await database;
    await db.update(
      'products',
      {'sync_status': 1},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  static Future<void> syncProductsFromServer(List<Product> products) async {
    final db = await database;
    await db.transaction((txn) async {
      // Get products that have local unsynced changes
      final unsyncedLocal = await txn.query(
        'products',
        columns: ['id'],
        where: 'sync_status = 0',
      );
      final unsyncedIds = unsyncedLocal.map((row) => row['id'] as int).toSet();

      // Insert/update products from server
      for (final product in products) {
        // Skip if this product has local unsynced changes
        if (unsyncedIds.contains(product.id)) {
          print(
            '⏭️ Skipping product ${product.id} - has local unsynced changes',
          );
          continue;
        }

        final data = product.toJson();
        if (product.id != null) {
          data['id'] = product.id;
        }

        data['sync_status'] = 1; // Synced
        data['category_name'] = product.categoryName;
        await txn.insert(
          'products',
          data,
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Stock management
  static Future<void> updateStock(int productId, int newStock) async {
    final db = await database;
    await db.update(
      'products',
      {
        'current_stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 0, // Needs sync
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  static Future<void> deleteProduct(int productId) async {
    final db = await database;
    // Soft delete - mark as inactive instead of actually deleting
    await db.update(
      'products',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 0, // Needs sync
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // Transactions
  static Future<String> insertTransaction(
    app_models.Transaction transaction,
  ) async {
    final db = await database;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final data = transaction.toJson();
    data['sync_status'] = 0; // Needs sync
    data['local_id'] = localId;

    await db.insert('transactions', data);
    return localId;
  }

  static Future<void> insertTransactionItems(
    List<app_models.TransactionItem> items,
    String localTransactionId,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        final data = item.toJson();
        data['sync_status'] = 0; // Needs sync
        data['local_transaction_id'] = localTransactionId;
        await txn.insert('transaction_items', data);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'sync_status = ?',
      whereArgs: [0],
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTransactionItems(
    String localTransactionId,
  ) async {
    final db = await database;
    return await db.query(
      'transaction_items',
      where: 'local_transaction_id = ? AND sync_status = ?',
      whereArgs: [localTransactionId, 0],
    );
  }

  static Future<void> markTransactionSynced(
    String localId,
    int serverId,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {'sync_status': 1, 'id': serverId},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // Reports and Analytics
  static Future<double> getTodaysSales() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay =
        DateTime(
          today.year,
          today.month,
          today.day,
          23,
          59,
          59,
        ).toIso8601String();

    final result = await db.rawQuery(
      '''
      SELECT SUM(total_amount) as total
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date <= ?
    ''',
      [startOfDay, endOfDay],
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  static Future<List<Map<String, dynamic>>> getRecentTransactions(
    int limit,
  ) async {
    final db = await database;
    return await db.query(
      'transactions',
      orderBy: 'transaction_date DESC',
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>> getSalesReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    // Get total sales and transaction count
    final salesResult = await db.rawQuery(
      '''
      SELECT 
        SUM(total_amount) as total_sales,
        COUNT(*) as transaction_count
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date <= ?
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // Get profit calculation (approximate, based on available cost prices)
    final profitResult = await db.rawQuery(
      '''
      SELECT 
        SUM((ti.unit_price - COALESCE(p.cost_price, 0)) * ti.quantity) as total_profit
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id OR ti.local_transaction_id = t.local_id
      JOIN products p ON ti.product_id = p.id
      WHERE t.transaction_date >= ? AND t.transaction_date <= ?
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return {
      'total_sales': (salesResult.first['total_sales'] as double?) ?? 0.0,
      'total_profit': (profitResult.first['total_profit'] as double?) ?? 0.0,
      'transaction_count':
          (salesResult.first['transaction_count'] as int?) ?? 0,
    };
  }

  static Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 10,
  }) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT 
        p.id as product_id,
        p.name as product_name,
        SUM(ti.quantity) as total_quantity,
        SUM(ti.subtotal) as total_revenue
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id OR ti.local_transaction_id = t.local_id
      JOIN products p ON ti.product_id = p.id
      WHERE t.transaction_date >= ? AND t.transaction_date <= ?
      GROUP BY p.id, p.name
      ORDER BY total_revenue DESC
      LIMIT ?
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String(), limit],
    );

    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getDailySales(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT 
        DATE(transaction_date) as date,
        SUM(total_amount) as total_sales,
        COUNT(*) as transaction_count
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date <= ?
      GROUP BY DATE(transaction_date)
      ORDER BY DATE(transaction_date)
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT id, name, current_stock, minimum_stock_level, unit_of_measure
      FROM products
      WHERE current_stock <= minimum_stock_level 
        AND is_active = 1
      ORDER BY current_stock
    ''');

    return List<Map<String, dynamic>>.from(result);
  }

  // Categories sync methods
  static Future<void> syncCategoriesFromServer(
    List<Category> categories,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // Don't delete - just replace/update existing categories
      for (final category in categories) {
        final data = category.toJson();
        data['id'] = category.id;
        data['sync_status'] = 1; // Synced
        await txn.insert(
          'categories',
          data,
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedCategories() async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'sync_status = ?',
      whereArgs: [0],
    );
  }

  static Future<void> markCategorySynced(int categoryId) async {
    final db = await database;
    await db.update(
      'categories',
      {'sync_status': 1},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  // Products sync methods
  static Future<List<Map<String, dynamic>>> getUnsyncedProducts() async {
    final db = await database;
    return await db.query('products', where: 'sync_status = ?', whereArgs: [0]);
  }

  // Transaction sync methods
  static Future<void> markTransactionItemsSynced(
    String localTransactionId,
  ) async {
    final db = await database;
    await db.update(
      'transaction_items',
      {'sync_status': 1},
      where: 'local_transaction_id = ?',
      whereArgs: [localTransactionId],
    );
  }
}
