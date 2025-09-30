import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart' as app_models;

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Categories
  static Future<List<Category>> getCategories() async {
    final response = await _client.from('categories').select().order('name');

    return response.map((json) => Category.fromJson(json)).toList();
  }

  static Future<Category> addCategory(Category category) async {
    final response =
        await _client
            .from('categories')
            .insert(category.toJson())
            .select()
            .single();

    return Category.fromJson(response);
  }

  static Future<void> updateCategory(Category category) async {
    if (category.id == null) {
      throw Exception('Cannot update category without an ID');
    }
    await _client
        .from('categories')
        .update(category.toJson())
        .eq('id', category.id!);
  }

  // Products
  static Future<List<Product>> getProducts() async {
    final response = await _client
        .from('products')
        .select('''
          *,
          categories!inner(
            id,
            name
          )
        ''')
        .eq('is_active', true)
        .order('name');

    // Debug: print first product to see data structure
    if (response.isNotEmpty) {
      print('Sample product data from Supabase: ${response.first}');
    }

    return response.map((json) {
      // Add category name to product json
      json['category_name'] = json['categories']['name'];
      return Product.fromJson(json);
    }).toList();
  }

  static Future<Product> addProduct(Product product) async {
    final response =
        await _client.from('products').insert(product.toJson()).select('''
          *,
          categories!inner(
            id,
            name
          )
        ''').single();

    response['category_name'] = response['categories']['name'];
    return Product.fromJson(response);
  }

  static Future<void> updateProduct(Product product) async {
    if (product.id == null) {
      throw Exception('Cannot update product without an ID');
    }
    await _client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id!);
  }

  static Future<void> updateStock(int productId, int newStock) async {
    await _client
        .from('products')
        .update({
          'current_stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  // Transactions
  static Future<int> createTransaction(
    app_models.Transaction transaction,
  ) async {
    final response =
        await _client
            .from('transactions')
            .insert(transaction.toJson())
            .select('id')
            .single();

    return response['id'];
  }

  static Future<void> addTransactionItems(
    List<app_models.TransactionItem> items,
  ) async {
    await _client
        .from('transaction_items')
        .insert(items.map((item) => item.toJson()).toList());
  }

  static Future<void> deleteProduct(int productId) async {
    // Soft delete by setting is_active to false
    await _client
        .from('products')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  // Reports and Analytics
  static Future<double> getTodaysSales() async {
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

    final response = await _client
        .from('transactions')
        .select('total_amount')
        .gte('transaction_date', startOfDay)
        .lte('transaction_date', endOfDay);

    double total = 0.0;
    for (var item in response) {
      total += (item['total_amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  static Future<List<Map<String, dynamic>>> getRecentTransactions(
    int limit,
  ) async {
    final response = await _client
        .from('transactions')
        .select('id, total_amount, cashier_name, transaction_date')
        .order('transaction_date', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>> getSalesReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get transactions in date range
    final transactions = await _client
        .from('transactions')
        .select('id, total_amount')
        .gte('transaction_date', startDate.toIso8601String())
        .lte('transaction_date', endDate.toIso8601String());

    // Get transaction items with product cost prices for profit calculation
    final transactionIds = transactions.map((t) => t['id']).toList();

    if (transactionIds.isEmpty) {
      return {'total_sales': 0.0, 'total_profit': 0.0, 'transaction_count': 0};
    }

    final transactionItems = await _client
        .from('transaction_items')
        .select('''
          quantity,
          unit_price,
          subtotal,
          products!inner(cost_price)
        ''')
        .inFilter('transaction_id', transactionIds);

    double totalSales = transactions.fold(
      0.0,
      (sum, t) => sum + (t['total_amount'] ?? 0.0),
    );
    double totalProfit = 0.0;

    for (final item in transactionItems) {
      final costPrice = item['products']['cost_price'] ?? 0.0;
      final quantity = item['quantity'] ?? 0;
      final unitPrice = item['unit_price'] ?? 0.0;

      totalProfit += (unitPrice - costPrice) * quantity;
    }

    return {
      'total_sales': totalSales,
      'total_profit': totalProfit,
      'transaction_count': transactions.length,
    };
  }

  static Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 10,
  }) async {
    final response = await _client.rpc(
      'get_top_products',
      params: {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'limit_count': limit,
      },
    );

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getDailySales(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _client.rpc(
      'get_daily_sales',
      params: {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
    );

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final response = await _client
        .from('products')
        .select('id, name, current_stock, minimum_stock_level, unit_of_measure')
        .lte('current_stock', 'minimum_stock_level')
        .eq('is_active', true)
        .order('current_stock');

    return List<Map<String, dynamic>>.from(response);
  }
}

// SQL Functions to add to Supabase (run these in the SQL editor)
/*

-- Function to get top selling products
CREATE OR REPLACE FUNCTION get_top_products(
  start_date timestamp,
  end_date timestamp,
  limit_count integer DEFAULT 10
)
RETURNS TABLE (
  product_id integer,
  product_name text,
  total_quantity bigint,
  total_revenue numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as product_id,
    p.name as product_name,
    SUM(ti.quantity) as total_quantity,
    SUM(ti.subtotal) as total_revenue
  FROM transaction_items ti
  JOIN transactions t ON ti.transaction_id = t.id
  JOIN products p ON ti.product_id = p.id
  WHERE t.transaction_date >= start_date 
    AND t.transaction_date <= end_date
  GROUP BY p.id, p.name
  ORDER BY total_revenue DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get daily sales
CREATE OR REPLACE FUNCTION get_daily_sales(
  start_date timestamp,
  end_date timestamp
)
RETURNS TABLE (
  date text,
  total_sales numeric,
  transaction_count bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE(t.transaction_date)::text as date,
    SUM(t.total_amount) as total_sales,
    COUNT(*) as transaction_count
  FROM transactions t
  WHERE t.transaction_date >= start_date 
    AND t.transaction_date <= end_date
  GROUP BY DATE(t.transaction_date)
  ORDER BY DATE(t.transaction_date);
END;
$$ LANGUAGE plpgsql;

*/
