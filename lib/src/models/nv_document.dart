import 'nv_value.dart';

/// A document in NeuralVault
class NVDocument {
  /// Unique identifier
  final String id;

  /// Collection name
  final String collection;

  /// Document data
  final Map<String, NVValue> data;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last update timestamp
  final DateTime updatedAt;

  /// Soft delete flag
  final bool deleted;

  const NVDocument({
    required this.id,
    required this.collection,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  /// Create a new document
  factory NVDocument.create({
    required String id,
    required String collection,
    required Map<String, dynamic> data,
  }) {
    final now = DateTime.now();
    return NVDocument(
      id: id,
      collection: collection,
      data: data.map((k, v) => MapEntry(k, NVValue.from(v))),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get a field value
  NVValue? get(String field) => data[field];

  /// Update document data
  NVDocument copyWith({
    Map<String, NVValue>? data,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return NVDocument(
      id: id,
      collection: collection,
      data: data ?? this.data,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deleted: deleted ?? this.deleted,
    );
  }

  /// Set field value (returns new document)
  NVDocument set(String field, dynamic value) {
    final newData = Map<String, NVValue>.from(data);
    newData[field] = NVValue.from(value);
    return copyWith(data: newData);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection': collection,
      'data': data.map((k, v) => MapEntry(k, v.toJson())),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
    };
  }

  /// Create from JSON
  factory NVDocument.fromJson(Map<String, dynamic> json) {
    return NVDocument(
      id: json['id'] as String,
      collection: json['collection'] as String,
      data: (json['data'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, NVValue.from(v)),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'NVDocument(id: $id, collection: $collection)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NVDocument && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
