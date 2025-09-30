class Product {
  final int? id;
  final String name;
  final String? description;
  final int categoryId;
  final String? categoryName; // Added for display purposes
  final double? costPrice;
  final double sellingPrice;
  final int currentStock;
  final int minimumStockLevel;
  final String unitOfMeasure;
  final String? supplierName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int syncStatus; // 0 = needs sync, 1 = synced
  final String? localId;

  Product({
    this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.categoryName,
    this.costPrice,
    required this.sellingPrice,
    this.currentStock = 0,
    this.minimumStockLevel = 0,
    this.unitOfMeasure = 'pieces',
    this.supplierName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 0,
    this.localId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'category_id': categoryId,
    'cost_price': costPrice,
    'selling_price': sellingPrice,
    'current_stock': currentStock,
    'minimum_stock_level': minimumStockLevel,
    'unit_of_measure': unitOfMeasure,
    'supplier_name': supplierName,
    'is_active': isActive ? 1 : 0, // Convert bool to int for SQLite
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to boolean
    bool _toBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return true; // Default to true if null or unknown type
    }

    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      categoryId: json['category_id'],
      categoryName: json['category_name'], // From JOIN or local storage
      costPrice: json['cost_price']?.toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      currentStock: json['current_stock'] ?? 0,
      minimumStockLevel: json['minimum_stock_level'] ?? 0,
      unitOfMeasure: json['unit_of_measure'] ?? 'pieces',
      supplierName: json['supplier_name'],
      isActive: _toBool(json['is_active']),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      syncStatus: json['sync_status'] ?? 0,
      localId: json['local_id'],
    );
  }

  bool get isLowStock => currentStock <= minimumStockLevel;
  bool get isOutOfStock => currentStock <= 0;

  Product copyWith({
    int? id,
    String? name,
    String? description,
    int? categoryId,
    String? categoryName,
    double? costPrice,
    double? sellingPrice,
    int? currentStock,
    int? minimumStockLevel,
    String? unitOfMeasure,
    String? supplierName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    String? localId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name, stock: $currentStock, price: $sellingPrice}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
