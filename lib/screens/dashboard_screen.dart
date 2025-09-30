import 'package:flutter/material.dart';
import '../services/hybrid_service.dart';
import '../widgets/stat_card.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'add_edit_product_screen.dart';
import 'reports_screen.dart';
import 'dart:async';

final StreamController<String> dashboardUpdateStream =
    StreamController<String>.broadcast();

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  double todaysSales = 0.0;
  int lowStockCount = 0;
  int totalProducts = 0;
  List<Map<String, dynamic>> recentTransactions = [];
  bool isLoading = true;
  Timer? _autoRefreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();

    // Auto-refresh every 30 seconds
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload when app resumes
    if (state == AppLifecycleState.resumed && mounted) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      final sales = await HybridService.getTodaysSales();
      final products = await HybridService.getProducts();
      final lowStock = products.where((p) => p.isLowStock).length;
      final transactions = await HybridService.getRecentTransactions(5);

      if (!mounted) return;

      setState(() {
        todaysSales = sales;
        lowStockCount = lowStock;
        totalProducts = products.length;
        recentTransactions = transactions;
        isLoading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      print('Error loading dashboard: $e');

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Unable to load dashboard data')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.agriculture, size: 24),
            SizedBox(width: 12),
            Text('Farm Coop POS'),
          ],
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (_lastUpdated != null)
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  '${_getTimeAgo(_lastUpdated!)}',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
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
                    Text('Loading dashboard...'),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Message
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[700]!, Colors.green[600]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wb_sunny, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ready to start selling?',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Today's Overview
                      Text(
                        'Today\'s Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 12),

                      // Stats Cards Row 1
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Sales Today',
                              value: '₱${todaysSales.toStringAsFixed(2)}',
                              icon: Icons.payments,
                              color: Colors.green,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Low Stock Alert',
                              value:
                                  '$lowStockCount ${lowStockCount == 1 ? 'item' : 'items'}',
                              icon: Icons.warning_amber_rounded,
                              color:
                                  lowStockCount > 0
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Stats Cards Row 2
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Total Products',
                              value: '$totalProducts',
                              icon: Icons.inventory_2,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Container(height: 120), // Placeholder
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              title: 'Make a Sale',
                              subtitle: 'Process transactions',
                              icon: Icons.point_of_sale,
                              color: Colors.green,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PosScreen(),
                                  ),
                                );
                                if (mounted) _loadDashboardData();
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              title: 'View Stock',
                              subtitle: 'Check inventory',
                              icon: Icons.inventory,
                              color: Colors.blue,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InventoryScreen(),
                                  ),
                                );
                                if (mounted) _loadDashboardData();
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              title: 'Add Product',
                              subtitle: 'New inventory item',
                              icon: Icons.add_box,
                              color: Colors.orange,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEditProductScreen(),
                                  ),
                                );
                                if (mounted) _loadDashboardData();
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              title: 'View Reports',
                              subtitle: 'Sales analytics',
                              icon: Icons.bar_chart,
                              color: Colors.purple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Recent Transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Sales',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (recentTransactions.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportsScreen(),
                                  ),
                                );
                              },
                              child: Text('View All'),
                            ),
                        ],
                      ),
                      SizedBox(height: 12),
                      if (recentTransactions.isEmpty)
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No sales yet today',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start making sales to see them here',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...recentTransactions.map(
                          (transaction) => Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.receipt,
                                  color: Colors.green[700],
                                ),
                              ),
                              title: Text(
                                '₱${transaction['total_amount'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                '${transaction['cashier_name'] ?? 'Cashier'} • ${_formatDate(transaction['transaction_date'])}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${transaction['id']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    } else {
      return '${diff.inDays} day ago';
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
