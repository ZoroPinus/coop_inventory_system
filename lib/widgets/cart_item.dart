import 'package:flutter/material.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.sellingPrice * quantity;
}

class CartItemWidget extends StatefulWidget {
  final CartItem cartItem;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemWidget({
    super.key,
    required this.cartItem,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  void _decreaseQuantity() {
    if (widget.cartItem.quantity > 1) {
      setState(() {
        widget.cartItem.quantity--;
      });
      widget.onQuantityChanged(widget.cartItem.quantity);
    }
  }

  void _increaseQuantity() {
    if (widget.cartItem.quantity < widget.cartItem.product.currentStock) {
      setState(() {
        widget.cartItem.quantity++;
      });
      widget.onQuantityChanged(widget.cartItem.quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name and remove button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cartItem.product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.cartItem.product.categoryName ?? 'No Category',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove from cart',
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),

            // Price info and total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price per ${widget.cartItem.product.unitOfMeasure}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '₱${widget.cartItem.product.sellingPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Stock: ${widget.cartItem.product.currentStock} ${widget.cartItem.product.unitOfMeasure}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '₱${widget.cartItem.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),

            // Quantity Controls
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decrease button
                  Material(
                    color:
                        widget.cartItem.quantity > 1
                            ? Colors.red[50]
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap:
                          widget.cartItem.quantity > 1
                              ? _decreaseQuantity
                              : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.remove,
                          size: 24,
                          color:
                              widget.cartItem.quantity > 1
                                  ? Colors.red[700]
                                  : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),

                  // Quantity display
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Container(
                      key: ValueKey(widget.cartItem.quantity),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green[300]!, width: 2),
                      ),
                      child: Text(
                        '${widget.cartItem.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),

                  // Increase button
                  Material(
                    color:
                        widget.cartItem.quantity <
                                widget.cartItem.product.currentStock
                            ? Colors.green[50]
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap:
                          widget.cartItem.quantity <
                                  widget.cartItem.product.currentStock
                              ? _increaseQuantity
                              : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.add,
                          size: 24,
                          color:
                              widget.cartItem.quantity <
                                      widget.cartItem.product.currentStock
                                  ? Colors.green[700]
                                  : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Max stock warning
            if (widget.cartItem.quantity >=
                widget.cartItem.product.currentStock) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Maximum stock reached',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
