import '../models/nv_document.dart';
import 'storage_stats.dart';

/// Web-based storage manager (Stub)
class FileStorage {
  final String dbPath;

  FileStorage._(this.dbPath);

  static Future<FileStorage> initialize(String dbPath) async {
    // TODO: Implement IndexedDB or LocalStorage backend
    throw UnsupportedError(
      'Web storage is not yet implemented in NeuralVault.',
    );
  }

  Future<void> append(NVDocument document) async {
    throw UnsupportedError('Web storage not implemented');
  }

  Future<NVDocument> read(String id) async {
    throw UnsupportedError('Web storage not implemented');
  }

  Future<List<NVDocument>> scanCollection(String collection) async {
    throw UnsupportedError('Web storage not implemented');
  }

  Future<List<NVDocument>> scanAll() async {
    throw UnsupportedError('Web storage not implemented');
  }

  Future<void> markDeleted(String id) async {
    throw UnsupportedError('Web storage not implemented');
  }

  Future<StorageStats> getStats() async {
    throw UnsupportedError('Web storage not implemented');
  }
}
