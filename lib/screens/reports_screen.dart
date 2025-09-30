import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hybrid_service.dart';
import '../services/local_database_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime selectedStartDate = DateTime.now().subtract(Duration(days: 7));
  DateTime selectedEndDate = DateTime.now();
  bool isLoading = true;

  // Report data
  double totalSales = 0.0;
  double totalProfit = 0.0;
  int totalTransactions = 0;
  List<Map<String, dynamic>> topProducts = [];
  List<Map<String, dynamic>> dailySales = [];
  List<Map<String, dynamic>> lowStockProducts = [];
  List<Map<String, dynamic>> allTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => isLoading = true);

    try {
      final salesData = await HybridService.getSalesReport(
        selectedStartDate,
        selectedEndDate,
      );

      final topProductsData = await HybridService.getTopProducts(
        selectedStartDate,
        selectedEndDate,
        limit: 10,
      );

      final dailySalesData = await HybridService.getDailySales(
        selectedStartDate,
        selectedEndDate,
      );

      final lowStockData = await HybridService.getLowStockProducts();

      // Load all transactions for the period
      final transactionsData = await HybridService.getRecentTransactions(100);

      if (!mounted) return;

      setState(() {
        totalSales = salesData['total_sales'] ?? 0.0;
        totalProfit = salesData['total_profit'] ?? 0.0;
        totalTransactions = salesData['transaction_count'] ?? 0;
        topProducts = topProductsData;
        dailySales = dailySalesData;
        lowStockProducts = lowStockData;

        // Filter transactions by date range
        allTransactions =
            transactionsData.where((txn) {
              final txnDate = DateTime.parse(txn['transaction_date']);
              return txnDate.isAfter(
                    selectedStartDate.subtract(Duration(days: 1)),
                  ) &&
                  txnDate.isBefore(selectedEndDate.add(Duration(days: 1)));
            }).toList();

        isLoading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Unable to load reports. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: selectedStartDate,
        end: selectedEndDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.purple[700]!,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        selectedStartDate = picked.start;
        selectedEndDate = picked.end;
      });
      _loadReports();
    }
  }

  void _setQuickDateRange(String range) {
    setState(() {
      selectedEndDate = DateTime.now();
      switch (range) {
        case 'today':
          selectedStartDate = DateTime.now();
          break;
        case 'week':
          selectedStartDate = DateTime.now().subtract(Duration(days: 7));
          break;
        case 'month':
          selectedStartDate = DateTime.now().subtract(Duration(days: 30));
          break;
        case 'quarter':
          selectedStartDate = DateTime.now().subtract(Duration(days: 90));
          break;
      }
    });
    _loadReports();
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch transaction items from database
      final db = await LocalDatabaseService.database;
      final items = await db.rawQuery(
        '''
        SELECT 
          ti.*,
          p.name as product_name,
          p.unit_of_measure
        FROM transaction_items ti
        LEFT JOIN products p ON ti.product_id = p.id
        WHERE ti.transaction_id = ? OR ti.local_transaction_id = ?
      ''',
        [transaction['id'], transaction['local_id']],
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show transaction details modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder:
                  (context, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Container(
                          margin: EdgeInsets.only(top: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Header
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: Colors.purple[700],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sale #${transaction['id']}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy • hh:mm a',
                                      ).format(
                                        DateTime.parse(
                                          transaction['transaction_date'],
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(height: 1),

                        // Transaction details
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: EdgeInsets.all(16),
                            children: [
                              // Items section
                              if (items.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_basket,
                                      size: 20,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Items Purchased',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),

                                // List of items
                                ...items.map((item) {
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['product_name']
                                                        as String? ??
                                                    'Unknown Product',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '${item['quantity']} ${item['unit_of_measure']} × ₱${(item['unit_price'] as num).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₱${(item['subtotal'] as num).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),

                                SizedBox(height: 16),
                              ],

                              // Total amount card
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[50]!,
                                      Colors.green[100]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₱${transaction['total_amount'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Cashier info
                              _DetailRow(
                                label: 'Cashier',
                                value: transaction['cashier_name'] ?? 'Unknown',
                                icon: Icons.person,
                              ),
                              SizedBox(height: 8),
                              _DetailRow(
                                label: 'Payment Method',
                                value: 'Cash',
                                icon: Icons.payments,
                              ),

                              if (items.isEmpty) ...[
                                SizedBox(height: 16),
                                Text(
                                  'Note: Item details not available for this transaction',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
      );
    } catch (e) {
      print('Error loading transaction details: $e');

      if (!mounted) return;

      // Close loading dialog if still open
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load transaction details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int get _daysDifference =>
      selectedEndDate.difference(selectedStartDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Reports & Analytics'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'Change date range',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading reports...'),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadReports,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Range Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    color: Colors.purple[700],
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Report Period',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${DateFormat('MMM dd, yyyy').format(selectedStartDate)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'to',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${DateFormat('MMM dd, yyyy').format(selectedEndDate)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '$_daysDifference days',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _selectDateRange,
                                    icon: Icon(Icons.edit_calendar, size: 18),
                                    label: Text('Custom'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple[700],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),

                              // Quick date range buttons
                              Wrap(
                                spacing: 8,
                                children: [
                                  _QuickDateButton(
                                    label: 'Today',
                                    onTap: () => _setQuickDateRange('today'),
                                  ),
                                  _QuickDateButton(
                                    label: 'Last 7 Days',
                                    onTap: () => _setQuickDateRange('week'),
                                  ),
                                  _QuickDateButton(
                                    label: 'Last 30 Days',
                                    onTap: () => _setQuickDateRange('month'),
                                  ),
                                  _QuickDateButton(
                                    label: 'Last 3 Months',
                                    onTap: () => _setQuickDateRange('quarter'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Summary Section Header
                      Text(
                        'Sales Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 12),

                      // Summary Cards
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        children: [
                          _SummaryCard(
                            title: 'Total Sales',
                            value: '₱${totalSales.toStringAsFixed(2)}',
                            icon: Icons.payments,
                            color: Colors.green,
                          ),
                          _SummaryCard(
                            title: 'Total Profit',
                            value: '₱${totalProfit.toStringAsFixed(2)}',
                            icon: Icons.trending_up,
                            color: Colors.blue,
                          ),
                          _SummaryCard(
                            title: 'Total Sales',
                            value: '$totalTransactions',
                            icon: Icons.receipt_long,
                            color: Colors.orange,
                          ),
                          _SummaryCard(
                            title: 'Average Sale',
                            value:
                                totalTransactions > 0
                                    ? '₱${(totalSales / totalTransactions).toStringAsFixed(2)}'
                                    : '₱0.00',
                            icon: Icons.bar_chart,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Top Products Section
                      Row(
                        children: [
                          Icon(Icons.emoji_events, color: Colors.amber[700]),
                          SizedBox(width: 12),
                          Text(
                            'Best Selling Products',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child:
                            topProducts.isEmpty
                                ? Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'No sales in this period',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : Column(
                                  children:
                                      topProducts.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final product = entry.value;
                                        final isTopThree = index < 3;

                                        return ListTile(
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color:
                                                  isTopThree
                                                      ? Colors.amber[100]
                                                      : Colors.purple[100],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child:
                                                  isTopThree
                                                      ? Icon(
                                                        Icons.emoji_events,
                                                        color:
                                                            Colors.amber[700],
                                                        size: 20,
                                                      )
                                                      : Text(
                                                        '${index + 1}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .purple[700],
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                          title: Text(
                                            product['product_name'] ??
                                                'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${product['total_quantity']} units sold',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₱${(product['total_revenue'] ?? 0.0).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'revenue',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                      ),
                      SizedBox(height: 24),

                      // Daily Sales Chart Section
                      Row(
                        children: [
                          Icon(Icons.show_chart, color: Colors.purple[700]),
                          SizedBox(width: 12),
                          Text(
                            'Daily Sales',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children:
                                dailySales.isEmpty
                                    ? [
                                      SizedBox(height: 60),
                                      Icon(
                                        Icons.bar_chart_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No daily sales data',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 60),
                                    ]
                                    : dailySales.map((day) {
                                      final date = DateTime.parse(day['date']);
                                      final sales =
                                          (day['total_sales'] ?? 0.0) as num;
                                      final maxSales = dailySales
                                          .map(
                                            (d) =>
                                                (d['total_sales'] ?? 0.0)
                                                    as num,
                                          )
                                          .reduce((a, b) => a > b ? a : b);

                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 70,
                                              child: Text(
                                                DateFormat(
                                                  'MMM dd',
                                                ).format(date),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor:
                                                      maxSales > 0
                                                          ? (sales / maxSales)
                                                              .toDouble()
                                                          : 0,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.purple[400]!,
                                                          Colors.purple[600]!,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                '₱${sales.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple[700],
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Low Stock Alert Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange[700],
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Stock Alerts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          if (lowStockProducts.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${lowStockProducts.length}',
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        child:
                            lowStockProducts.isEmpty
                                ? Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green[400],
                                          size: 48,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'All products well stocked!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'No items need restocking',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : Column(
                                  children:
                                      lowStockProducts.map((product) {
                                        final isOutOfStock =
                                            product['current_stock'] == 0;

                                        return ListTile(
                                          leading: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  isOutOfStock
                                                      ? Colors.red[100]
                                                      : Colors.orange[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isOutOfStock
                                                  ? Icons.remove_shopping_cart
                                                  : Icons.inventory_2,
                                              color:
                                                  isOutOfStock
                                                      ? Colors.red[700]
                                                      : Colors.orange[700],
                                            ),
                                          ),
                                          title: Text(
                                            product['name'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${product['current_stock']} ${product['unit_of_measure']} left • Restock at ${product['minimum_stock_level']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isOutOfStock
                                                      ? Colors.red[100]
                                                      : Colors.orange[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isOutOfStock ? 'Empty' : 'Low',
                                              style: TextStyle(
                                                color:
                                                    isOutOfStock
                                                        ? Colors.red[900]
                                                        : Colors.orange[900],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show all transactions in a separate screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => _AllTransactionsScreen(
                    transactions: allTransactions,
                    startDate: selectedStartDate,
                    endDate: selectedEndDate,
                    onTransactionTap: _showTransactionDetails,
                  ),
            ),
          );
        },
        backgroundColor: Colors.purple[700],
        icon: Icon(Icons.receipt_long, color: Colors.white),
        label: Text(
          'View All Sales',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// Quick date button widget
class _QuickDateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickDateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.purple[300]!),
        foregroundColor: Colors.purple[700],
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12)),
    );
  }
}

// Detail row widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// All transactions screen
class _AllTransactionsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final DateTime startDate;
  final DateTime endDate;
  final Function(Map<String, dynamic>) onTransactionTap;

  const _AllTransactionsScreen({
    required this.transactions,
    required this.startDate,
    required this.endDate,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Sales'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary header
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.purple[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${transactions.length} sales',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long, color: Colors.purple[700]),
                ),
              ],
            ),
          ),

          // Transactions list
          Expanded(
            child:
                transactions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No sales in this period',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final txn = transactions[index];
                        final txnDate = DateTime.parse(txn['transaction_date']);

                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => onTransactionTap(txn),
                            leading: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.receipt,
                                color: Colors.purple[700],
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  '₱${txn['total_amount'].toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${txn['id']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  txn['cashier_name'] ?? 'Cashier',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy • hh:mm a',
                                  ).format(txnDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, color.withOpacity(0.08)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
