import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';

class SyncService {
  static bool _isSyncing = false;
  static DateTime? _lastSyncTime;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static Timer? _periodicSyncTimer;

  static bool get isSyncing => _isSyncing;
  static DateTime? get lastSyncTime => _lastSyncTime;

  /// Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Initialize sync service with connectivity monitoring
  static Future<void> initialize() async {
    // Start monitoring connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) async {
      final isConnected = !result.contains(ConnectivityResult.none);

      if (isConnected && !_isSyncing) {
        print('Device came online, starting sync...');
        await syncData();
      }
    });

    // Initial sync if online
    if (await isOnline()) {
      await syncData();
    }

    // Start periodic sync
    startPeriodicSync();
  }

  /// Start periodic synchronization every 5 minutes
  static void startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(Duration(minutes: 5), (_) async {
      if (await isOnline() && !_isSyncing) {
        await syncData();
      }
    });
  }

  /// Stop periodic sync and connectivity monitoring
  static void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  /// Main sync function - orchestrates all sync operations
  static Future<void> syncData() async {
    if (_isSyncing) {
      print('Sync already in progress, skipping...');
      return;
    }

    if (!(await isOnline())) {
      print('Device is offline, skipping sync');
      return;
    }

    _isSyncing = true;
    try {
      print('🔄 Starting data synchronization...');

      // 1. Sync categories from server to local (download first)
      await _syncCategoriesFromServer();

      // 2. Sync products from server to local
      await _syncProductsFromServer();

      // 3. Sync local changes to server (upload)
      await _syncLocalChangesToServer();

      _lastSyncTime = DateTime.now();
      print('✅ Synchronization completed successfully at ${_lastSyncTime}');
    } catch (e) {
      print('❌ Sync error: $e');
      // Don't rethrow - let the app continue working offline
    } finally {
      _isSyncing = false;
    }
  }

  /// Force a manual sync (with user feedback)
  static Future<bool> forceSyncWithFeedback() async {
    if (!(await isOnline())) {
      return false;
    }

    try {
      await syncData();
      return true;
    } catch (e) {
      print('Force sync failed: $e');
      return false;
    }
  }

  /// Sync categories from server to local database
  static Future<void> _syncCategoriesFromServer() async {
    try {
      print('📂 Syncing categories from server...');
      final serverCategories = await SupabaseService.getCategories();
      await LocalDatabaseService.syncCategoriesFromServer(serverCategories);
      print('✅ Categories synced: ${serverCategories.length} items');
    } catch (e) {
      print('❌ Error syncing categories from server: $e');
      rethrow;
    }
  }

  /// Sync products from server to local database
  static Future<void> _syncProductsFromServer() async {
    try {
      print('📦 Syncing products from server...');
      final serverProducts = await SupabaseService.getProducts();
      await LocalDatabaseService.syncProductsFromServer(serverProducts);
      print('✅ Products synced: ${serverProducts.length} items');
    } catch (e) {
      print('❌ Error syncing products from server: $e');
      rethrow;
    }
  }

  /// Sync all local changes to server
  static Future<void> _syncLocalChangesToServer() async {
    await _syncUnsyncedCategoriesToServer();
    await _syncUnsyncedProductsToServer();
    await _syncUnsyncedTransactionsToServer();
  }

  /// Sync unsynced categories to server
  static Future<void> _syncUnsyncedCategoriesToServer() async {
    try {
      print('📂 Syncing unsynced categories to server...');
      final unsyncedCategories =
          await LocalDatabaseService.getUnsyncedCategories();

      int syncedCount = 0;
      for (final categoryData in unsyncedCategories) {
        try {
          final category = Category.fromJson(categoryData);

          if (categoryData['local_id'] != null) {
            // This is a new category created locally
            final serverCategory = await SupabaseService.addCategory(category);
            await LocalDatabaseService.updateCategoryServerId(
              categoryData['id'],
              serverCategory.id!,
            );
          } else {
            // This is an updated category
            await SupabaseService.updateCategory(category);
            await LocalDatabaseService.markCategorySynced(category.id!);
          }

          syncedCount++;
        } catch (e) {
          print('❌ Error syncing category ${categoryData['id']}: $e');
        }
      }

      if (syncedCount > 0) {
        print('✅ Categories synced to server: $syncedCount items');
      }
    } catch (e) {
      print('❌ Error syncing categories to server: $e');
    }
  }

  static Future<void> _syncUnsyncedProductsToServer() async {
    try {
      print('📦 Syncing unsynced products to server...');
      final unsyncedProducts = await LocalDatabaseService.getUnsyncedProducts();

      print('Found ${unsyncedProducts.length} unsynced products'); // DEBUG

      int syncedCount = 0;
      for (final productData in unsyncedProducts) {
        try {
          final product = Product.fromJson(productData);

          print(
            'Product ${product.id}: stock = ${product.currentStock}, is_active = ${productData['is_active']}',
          ); // DEBUG

          if (productData['is_active'] == 0) {
            // Deleted product logic...
          } else if (productData['local_id'] != null) {
            // New product logic...
          } else {
            // This is an EXISTING product that was updated (including stock changes)
            print(
              'Updating product ${product.id} on server with stock ${product.currentStock}',
            ); // DEBUG
            await SupabaseService.updateProduct(product);
            await LocalDatabaseService.markProductSynced(product.id!);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Error syncing product ${productData['id']}: $e');
        }
      }

      if (syncedCount > 0) {
        print('✅ Products synced to server: $syncedCount items');
      }
    } catch (e) {
      print('❌ Error syncing products to server: $e');
    }
  }

  /// Sync unsynced transactions to server
  static Future<void> _syncUnsyncedTransactionsToServer() async {
    try {
      print('🧾 Syncing unsynced transactions to server...');
      final unsyncedTransactions =
          await LocalDatabaseService.getUnsyncedTransactions();

      int syncedCount = 0;
      for (final txnData in unsyncedTransactions) {
        try {
          // Get transaction items
          final items = await LocalDatabaseService.getUnsyncedTransactionItems(
            txnData['local_id'],
          );

          // Create transaction on server
          final transaction = Transaction.fromJson(txnData);
          final serverId = await SupabaseService.createTransaction(transaction);

          // Create transaction items on server
          final transactionItems =
              items.map((item) {
                final itemData = Map<String, dynamic>.from(item);
                itemData['transaction_id'] = serverId;
                return TransactionItem.fromJson(itemData);
              }).toList();

          await SupabaseService.addTransactionItems(transactionItems);

          // Mark as synced locally
          await LocalDatabaseService.markTransactionSynced(
            txnData['local_id'],
            serverId,
          );

          syncedCount++;

          print('✅ Transaction synced: ${txnData['local_id']} -> $serverId');
        } catch (e) {
          print('❌ Error syncing transaction ${txnData['local_id']}: $e');
        }
      }

      if (syncedCount > 0) {
        print('✅ Transactions synced to server: $syncedCount items');
      }
    } catch (e) {
      print('❌ Error syncing transactions to server: $e');
    }
  }

  /// Get sync status information
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final unsyncedCategories =
          await LocalDatabaseService.getUnsyncedCategories();
      final unsyncedProducts = await LocalDatabaseService.getUnsyncedProducts();
      final unsyncedTransactions =
          await LocalDatabaseService.getUnsyncedTransactions();

      final totalPendingSync =
          unsyncedCategories.length +
          unsyncedProducts.length +
          unsyncedTransactions.length;

      return {
        'isOnline': await isOnline(),
        'isSyncing': _isSyncing,
        'lastSyncTime': _lastSyncTime,
        'pendingSync': totalPendingSync,
        'pendingCategories': unsyncedCategories.length,
        'pendingProducts': unsyncedProducts.length,
        'pendingTransactions': unsyncedTransactions.length,
      };
    } catch (e) {
      return {
        'isOnline': false,
        'isSyncing': false,
        'lastSyncTime': null,
        'pendingSync': 0,
        'error': e.toString(),
      };
    }
  }

  /// Pause sync (useful for low bandwidth situations)
  static void pauseSync() {
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    print('⏸️ Sync paused');
  }

  /// Resume sync
  static void resumeSync() {
    initialize();
    print('▶️ Sync resumed');
  }

  /// Check if there are pending items to sync
  static Future<bool> hasPendingSync() async {
    final status = await getSyncStatus();
    return (status['pendingSync'] ?? 0) > 0;
  }
}
