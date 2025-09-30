class Transaction {
  final int? id;
  final double totalAmount;
  final String paymentMethod;
  final String? cashierName;
  final DateTime transactionDate;
  final int syncStatus;
  final String? localId;

  Transaction({
    this.id,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.cashierName,
    required this.transactionDate,
    this.syncStatus = 0,
    this.localId,
  });

  Map<String, dynamic> toJson() => {
    'total_amount': totalAmount,
    'payment_method': paymentMethod,
    'cashier_name': cashierName,
    'transaction_date': transactionDate.toIso8601String(),
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    totalAmount: json['total_amount'].toDouble(),
    paymentMethod: json['payment_method'] ?? 'cash',
    cashierName: json['cashier_name'],
    transactionDate: DateTime.parse(json['transaction_date']),
    syncStatus: json['sync_status'] ?? 0,
    localId: json['local_id'],
  );
}

class TransactionItem {
  final int? id;
  final int transactionId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  TransactionItem({
    this.id,
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
    'transaction_id': transactionId,
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'subtotal': subtotal,
  };

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: json['id'],
        transactionId: json['transaction_id'],
        productId: json['product_id'],
        quantity: json['quantity'],
        unitPrice: json['unit_price'].toDouble(),
        subtotal: json['subtotal'].toDouble(),
      );
}
