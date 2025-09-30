import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/transaction.dart' as app_models;
import '../services/hybrid_service.dart';
import '../widgets/product_card.dart';
import '../widgets/cart_item.dart';
import 'dashboard_screen.dart' show dashboardUpdateStream;

class PosScreen extends StatefulWidget {
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  List<CartItem> cart = [];
  TextEditingController searchController = TextEditingController();
  String selectedCategory = 'All';
  List<String> categories = ['All'];
  bool isLoading = true;
  bool isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final loadedProducts = await HybridService.getProducts();
      final loadedCategories = await HybridService.getCategories();

      if (!mounted) return;

      setState(() {
        products = loadedProducts;
        filteredProducts = loadedProducts;
        categories = ['All'] + loadedCategories.map((c) => c.name).toList();
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading data: $e\n$stackTrace');

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Unable to load products. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _filterProducts() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredProducts =
          products.where((product) {
            final matchesSearch = product.name.toLowerCase().contains(query);
            final matchesCategory =
                selectedCategory == 'All' ||
                product.categoryName == selectedCategory;
            return matchesSearch && matchesCategory && product.currentStock > 0;
          }).toList();
    });
  }

  void _addToCart(Product product) {
    if (product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.inventory, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('${product.name} is out of stock')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = cart.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex >= 0) {
        if (cart[existingIndex].quantity < product.currentStock) {
          cart[existingIndex].quantity++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Not enough stock for ${product.name}')),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        cart.add(CartItem(product: product));
      }
    });

    dashboardUpdateStream.add('refresh');
  }

  void _removeFromCart(int index) {
    if (cart.isEmpty || index < 0 || index >= cart.length) {
      return;
    }

    final productName = cart[index].product.name;

    setState(() {
      cart.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$productName removed'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    dashboardUpdateStream.add('refresh');
  }

  void _updateQuantity(int index, int newQuantity) {
    if (index < 0 || index >= cart.length) {
      return;
    }

    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }

    final product = cart[index].product;

    if (newQuantity > product.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${product.currentStock} ${product.unitOfMeasure} available',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      cart[index].quantity = newQuantity;
    });

    dashboardUpdateStream.add('refresh');
  }

  void _clearCart() {
    setState(() {
      cart.clear();
    });
  }

  double get cartTotal => cart.fold(0.0, (sum, item) => sum + item.subtotal);

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => DraggableScrollableSheet(
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

                            // Cart Header
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_cart,
                                        color: Colors.green[700],
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Your Cart (${cart.length})',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (cart.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () {
                                        _clearCart();
                                        Navigator.pop(context);
                                      },
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      label: Text('Clear All'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Divider(height: 1),

                            // Cart Items
                            Expanded(
                              child:
                                  cart.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.shopping_cart_outlined,
                                              size: 80,
                                              color: Colors.grey[300],
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Cart is empty',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add products to start selling',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : ListView.builder(
                                        controller: scrollController,
                                        padding: EdgeInsets.all(16),
                                        itemCount: cart.length,
                                        itemBuilder: (context, index) {
                                          if (index >= cart.length) {
                                            return SizedBox.shrink();
                                          }

                                          final cartItem = cart[index];
                                          return CartItemWidget(
                                            key: ValueKey(cartItem.product.id),
                                            cartItem: cartItem,
                                            onQuantityChanged: (newQuantity) {
                                              if (index < cart.length) {
                                                _updateQuantity(
                                                  index,
                                                  newQuantity,
                                                );
                                                setModalState(() {});
                                              }
                                            },
                                            onRemove: () {
                                              if (index < cart.length) {
                                                _removeFromCart(index);
                                                setModalState(() {});
                                              }
                                            },
                                          );
                                        },
                                      ),
                            ),

                            // Cart Total and Checkout
                            if (cart.isNotEmpty) ...[
                              Divider(height: 1),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(50),
                                      blurRadius: 10,
                                      offset: Offset(0, -5),
                                    ),
                                  ],
                                ),
                                child: SafeArea(
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Amount:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '₱${cartTotal.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed:
                                              isProcessingPayment
                                                  ? null
                                                  : () {
                                                    Navigator.pop(context);
                                                    _processPayment();
                                                  },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[700],
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                          ),
                                          child:
                                              isProcessingPayment
                                                  ? SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                  : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle,
                                                        size: 24,
                                                      ),
                                                      SizedBox(width: 12),
                                                      Text(
                                                        'Complete Sale',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                ),
          ),
    );
  }

  Future<void> _processPayment() async {
    if (cart.isEmpty) return;

    setState(() => isProcessingPayment = true);

    try {
      final transaction = app_models.Transaction(
        totalAmount: cartTotal,
        paymentMethod: 'cash',
        cashierName: 'Current User',
        transactionDate: DateTime.now(),
      );

      final transactionItems = <app_models.TransactionItem>[];
      for (final cartItem in cart) {
        transactionItems.add(
          app_models.TransactionItem(
            transactionId: 0,
            productId: cartItem.product.id!,
            quantity: cartItem.quantity,
            unitPrice: cartItem.product.sellingPrice,
            subtotal: cartItem.subtotal,
          ),
        );
      }

      await HybridService.createTransaction(transaction, transactionItems);

      if (!mounted) return;

      dashboardUpdateStream.add('refresh');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sale completed! Total: ₱${cartTotal.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 3),
        ),
      );

      _clearCart();
      _loadData();
    } catch (e) {
      print('Error processing payment: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Unable to process sale. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Make a Sale'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh products',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: Colors.green[700],
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Category Chips
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = category == selectedCategory;
                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedCategory = category;
                            });
                            _filterProducts();
                          },
                          selectedColor: Colors.white,
                          backgroundColor: Colors.green[600],
                          labelStyle: TextStyle(
                            color:
                                isSelected ? Colors.green[700] : Colors.white,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading products...'),
                        ],
                      ),
                    )
                    : filteredProducts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No products available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try changing your search or category',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                    : GridView.builder(
                      padding: EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ProductCard(
                          product: product,
                          onTap: () => _addToCart(product),
                        );
                      },
                    ),
          ),
        ],
      ),

      // Floating Cart Button
      floatingActionButton:
          cart.isEmpty
              ? null
              : FloatingActionButton.extended(
                onPressed: _showCartBottomSheet,
                backgroundColor: Colors.green[700],
                icon: Badge(
                  label: Text('${cart.length}'),
                  backgroundColor: Colors.white,
                  textColor: Colors.green[700],
                  child: Icon(Icons.shopping_cart, color: Colors.white),
                ),
                label: Text(
                  '₱${cartTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
