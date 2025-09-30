class Category {
  final int? id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final int syncStatus; // 0 = needs sync, 1 = synced
  final String? localId;

  Category({
    this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.syncStatus = 0,
    this.localId,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    createdAt:
        json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    syncStatus: json['sync_status'] ?? 0,
    localId: json['local_id'],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'created_at': createdAt?.toIso8601String(),
  };

  Category copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    int? syncStatus,
    String? localId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
