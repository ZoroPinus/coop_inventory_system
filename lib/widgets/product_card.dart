import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.product.currentStock <= 0) return;

    setState(() {
      _isPressed = true;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Call parent callback after animation starts
    Future.delayed(Duration(milliseconds: 50), () {
      widget.onTap();
      setState(() {
        _isPressed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLowStock = widget.product.isLowStock;
    final isOutOfStock = widget.product.currentStock <= 0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        elevation: _isPressed ? 8 : 2,
        shadowColor: _isPressed ? Colors.green.withAlpha(50) : Colors.black26,
        child: InkWell(
          onTap: isOutOfStock ? null : _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient:
                  _isPressed
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.withAlpha(10),
                          Colors.green.withAlpha(5),
                        ],
                      )
                      : null,
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock Status Indicator with Animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isOutOfStock
                                  ? Colors.red[100]
                                  : isLowStock
                                  ? Colors.orange[100]
                                  : Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOutOfStock
                              ? 'Out of Stock'
                              : isLowStock
                              ? 'Low Stock'
                              : 'In Stock',
                          style: TextStyle(
                            color:
                                isOutOfStock
                                    ? Colors.red[700]
                                    : isLowStock
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isOutOfStock)
                        AnimatedRotation(
                          turns: _isPressed ? 0.25 : 0,
                          duration: Duration(milliseconds: 150),
                          child: Icon(
                            Icons.add_circle,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Product Name
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),

                  // Category
                  Text(
                    widget.product.categoryName ?? 'No Category',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),

                  Spacer(),

                  // Price and Stock with Animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Duration(milliseconds: 300),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium!.copyWith(
                          color:
                              _isPressed
                                  ? Colors.green[900]
                                  : Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: _isPressed ? 16 : 15,
                        ),
                        child: Text(
                          '₱${widget.product.sellingPrice.toStringAsFixed(2)}',
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _isPressed ? Colors.green[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.product.currentStock} ${widget.product.unitOfMeasure}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
