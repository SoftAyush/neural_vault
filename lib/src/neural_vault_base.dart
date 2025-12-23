import 'package:uuid/uuid.dart';
import 'models/nv_document.dart';
import 'models/nv_query.dart';
import 'storage/file_storage.dart';
import 'query/query_processor.dart';
import 'exceptions.dart';

/// Configuration for NeuralVault database
class NeuralVaultConfig {
  /// Path to database directory
  final String path;

  /// Enable compression (future feature)
  final bool enableCompression;

  /// Maximum cache size in MB (future feature)
  final int cacheSizeMB;

  const NeuralVaultConfig({
    required this.path,
    this.enableCompression = false,
    this.cacheSizeMB = 100,
  });
}

/// Database statistics
class DatabaseStats {
  final int totalDocuments;
  final int totalCollections;
  final int storageSizeBytes;
  final List<String> collections;

  const DatabaseStats({
    required this.totalDocuments,
    required this.totalCollections,
    required this.storageSizeBytes,
    required this.collections,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_documents': totalDocuments,
      'total_collections': totalCollections,
      'storage_size_bytes': storageSizeBytes,
      'collections': collections,
    };
  }
}

/// Main NeuralVault database class
class NeuralVault {
  final NeuralVaultConfig config;
  late final FileStorage _storage;
  late final QueryProcessor _queryProcessor;
  final _uuid = const Uuid();
  bool _initialized = false;

  NeuralVault(this.config);

  /// Initialize the database
  Future<void> initialize() async {
    _storage = await FileStorage.initialize(config.path);
    _queryProcessor = QueryProcessor();
    _initialized = true;
  }

  /// Ensure database is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw DatabaseNotInitializedException();
    }
  }

  // ==================== CREATE ====================

  /// Create a new document
  Future<String> create(String collection, Map<String, dynamic> data) async {
    _ensureInitialized();

    final id = _uuid.v4();
    final document = NVDocument.create(
      id: id,
      collection: collection,
      data: data,
    );

    await _storage.append(document);
    return id;
  }

  /// Create multiple documents in batch
  Future<List<String>> createBatch(
    String collection,
    List<Map<String, dynamic>> dataList,
  ) async {
    _ensureInitialized();

    final ids = <String>[];
    for (final data in dataList) {
      final id = await create(collection, data);
      ids.add(id);
    }
    return ids;
  }

  // ==================== FIND ====================

  /// Find documents matching a query
  Future<List<NVDocument>> find(NVQuery query) async {
    _ensureInitialized();

    final documents = await _storage.scanCollection(query.collection);
    return _queryProcessor.filter(documents, query);
  }

  /// Find a single document by ID
  Future<NVDocument> findById(String id) async {
    _ensureInitialized();
    return await _storage.read(id);
  }

  /// Find first document matching query
  Future<NVDocument?> findOne(NVQuery query) async {
    final results = await find(query.take(1));
    return results.isEmpty ? null : results.first;
  }

  /// Find all documents in a collection
  Future<List<NVDocument>> findAll(String collection) async {
    _ensureInitialized();
    return await _storage.scanCollection(collection);
  }

  // ==================== UPDATE ====================

  /// Update documents matching a query
  Future<int> update(NVQuery query, Map<String, dynamic> updates) async {
    _ensureInitialized();

    final documents = await find(query);

    for (var doc in documents) {
      // Apply updates
      for (final entry in updates.entries) {
        doc = doc.set(entry.key, entry.value);
      }
      await _storage.append(doc);
    }

    return documents.length;
  }

  /// Update a single document by ID
  Future<void> updateById(String id, Map<String, dynamic> updates) async {
    _ensureInitialized();

    var document = await _storage.read(id);

    // Apply updates
    for (final entry in updates.entries) {
      document = document.set(entry.key, entry.value);
    }

    await _storage.append(document);
  }

  // ==================== DELETE (KILL) ====================

  /// Delete documents matching a query
  Future<int> kill(NVQuery query) async {
    _ensureInitialized();

    final documents = await find(query);

    for (final doc in documents) {
      await _storage.markDeleted(doc.id);
    }

    return documents.length;
  }

  /// Delete a single document by ID
  Future<void> killById(String id) async {
    _ensureInitialized();
    await _storage.markDeleted(id);
  }

  /// Delete all documents in a collection
  Future<int> killAll(String collection) async {
    _ensureInitialized();

    final query = NVQuery(collection);
    return await kill(query);
  }

  // ==================== UTILITY ====================

  /// Count documents in a collection
  Future<int> count(String collection) async {
    _ensureInitialized();

    final documents = await _storage.scanCollection(collection);
    return documents.length;
  }

  /// Count documents matching a query
  Future<int> countWhere(NVQuery query) async {
    final documents = await find(query);
    return documents.length;
  }

  /// Get all collection names
  Future<List<String>> collections() async {
    _ensureInitialized();

    final documents = await _storage.scanAll();
    final collections = documents.map((doc) => doc.collection).toSet().toList();
    collections.sort();
    return collections;
  }

  /// Get database statistics
  Future<DatabaseStats> stats() async {
    _ensureInitialized();

    final storageStats = await _storage.getStats();
    final collectionList = await collections();

    return DatabaseStats(
      totalDocuments: storageStats.documentCount,
      totalCollections: collectionList.length,
      storageSizeBytes: storageStats.fileSizeBytes,
      collections: collectionList,
    );
  }

  /// Check if database is initialized
  bool get isInitialized => _initialized;
}
