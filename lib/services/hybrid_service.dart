import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart' as app_models;
import 'local_database_service.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

// This service acts as a facade, routing calls to local or remote storage
class HybridService {
  // Categories
  static Future<List<Category>> getCategories() async {
    return await LocalDatabaseService.getLocalCategories();
  }

  static Future<Category> addCategory(Category category) async {
    // Add to local database immediately
    final localId = await LocalDatabaseService.insertCategory(category);

    // Try to sync to server if online
    if (await SyncService.isOnline()) {
      try {
        final serverCategory = await SupabaseService.addCategory(category);
        // Update local record with server ID
        await LocalDatabaseService.updateCategoryServerId(
          localId,
          serverCategory.id!,
        );
        return serverCategory;
      } catch (e) {
        print('Failed to sync category to server: $e');
      }
    }

    return category.copyWith(id: localId);
  }

  // Products
  static Future<List<Product>> getProducts() async {
    // Always return from local database for speed
    return await LocalDatabaseService.getLocalProducts();
  }

  static Future<Product> addProduct(Product product) async {
    // Add to local database immediately
    final localId = await LocalDatabaseService.insertProduct(product);

    // Try to sync to server if online
    if (await SyncService.isOnline()) {
      try {
        final serverProduct = await SupabaseService.addProduct(product);
        // Update local record with server ID
        await LocalDatabaseService.updateProductServerId(
          localId,
          serverProduct.id!,
        );
        return serverProduct;
      } catch (e) {
        print('Failed to sync product to server: $e');
      }
    }

    return product.copyWith(id: localId);
  }

  static Future<void> updateProduct(Product product) async {
    // Update locally first
    await LocalDatabaseService.updateProduct(product);

    // Try to sync to server if online
    if (await SyncService.isOnline()) {
      try {
        await SupabaseService.updateProduct(product);
        // Mark as synced locally
        await LocalDatabaseService.markProductSynced(product.id!);
      } catch (e) {
        print('Failed to sync product update to server: $e');
      }
    }
  }

  static Future<void> deleteProduct(int productId) async {
    // Soft delete locally (mark as inactive)
    await LocalDatabaseService.deleteProduct(productId);

    // Try to sync to server if online
    if (await SyncService.isOnline()) {
      try {
        await SupabaseService.deleteProduct(productId);
      } catch (e) {
        print('Failed to sync product deletion to server: $e');
      }
    }
  }

  static Future<void> updateStock(int productId, int newStock) async {
    // Update stock locally
    await LocalDatabaseService.updateStock(productId, newStock);

    // Try to sync immediately if online
    if (await SyncService.isOnline()) {
      try {
        await SupabaseService.updateStock(productId, newStock);
        // ✅ Mark as synced locally after successful server update
        await LocalDatabaseService.markProductSynced(productId);
      } catch (e) {
        print('Failed to sync stock update to server: $e');
      }
    }
  }

  // Transactions
  static Future<String> createTransaction(
    app_models.Transaction transaction,
    List<app_models.TransactionItem> items,
  ) async {
    // Always save locally first
    final localId = await LocalDatabaseService.insertTransaction(transaction);
    await LocalDatabaseService.insertTransactionItems(items, localId);

    // Update stock locally
    for (final item in items) {
      final product = await _getProductById(item.productId);
      if (product != null) {
        await LocalDatabaseService.updateStock(
          item.productId,
          product.currentStock - item.quantity,
        );
      }
    }

    // Try to sync immediately if online
    if (await SyncService.isOnline()) {
      await SyncService.syncData(); // Don't await, let it run in background
    }

    return localId;
  }

  static Future<Product?> _getProductById(int id) async {
    final products = await LocalDatabaseService.getLocalProducts();
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // Reports and Analytics
  static Future<double> getTodaysSales() async {
    return await LocalDatabaseService.getTodaysSales();
  }

  static Future<List<Map<String, dynamic>>> getRecentTransactions(
    int limit,
  ) async {
    return await LocalDatabaseService.getRecentTransactions(limit);
  }

  static Future<Map<String, dynamic>> getSalesReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Try to get from server if online, otherwise use local data
    if (await SyncService.isOnline()) {
      try {
        return await SupabaseService.getSalesReport(startDate, endDate);
      } catch (e) {
        print('Failed to get sales report from server: $e');
      }
    }

    // Fallback to local data
    return await LocalDatabaseService.getSalesReport(startDate, endDate);
  }

  static Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 10,
  }) async {
    // Try to get from server if online, otherwise use local data
    if (await SyncService.isOnline()) {
      try {
        return await SupabaseService.getTopProducts(
          startDate,
          endDate,
          limit: limit,
        );
      } catch (e) {
        print('Failed to get top products from server: $e');
      }
    }

    // Fallback to local data
    return await LocalDatabaseService.getTopProducts(
      startDate,
      endDate,
      limit: limit,
    );
  }

  static Future<List<Map<String, dynamic>>> getDailySales(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Try to get from server if online, otherwise use local data
    if (await SyncService.isOnline()) {
      try {
        return await SupabaseService.getDailySales(startDate, endDate);
      } catch (e) {
        print('Failed to get daily sales from server: $e');
      }
    }

    // Fallback to local data
    return await LocalDatabaseService.getDailySales(startDate, endDate);
  }

  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    return await LocalDatabaseService.getLowStockProducts();
  }

  // Utility methods
  static Future<void> forceSyncAll() async {
    if (await SyncService.isOnline()) {
      await SyncService.syncData();
    }
  }

  static Future<bool> isOnline() async {
    return await SyncService.isOnline();
  }

  static DateTime? getLastSyncTime() {
    return SyncService.lastSyncTime;
  }

  static bool isSyncing() {
    return SyncService.isSyncing;
  }
}
