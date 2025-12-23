import '../models/nv_document.dart';
import 'storage_stats.dart';

/// Stub storage manager
class FileStorage {
  FileStorage._();

  static Future<FileStorage> initialize(String dbPath) async {
    throw UnsupportedError(
      'Cannot create a FileStorage without dart:io or dart:html.',
    );
  }

  Future<void> append(NVDocument document) async => throw UnimplementedError();
  Future<NVDocument> read(String id) async => throw UnimplementedError();
  Future<List<NVDocument>> scanCollection(String collection) async =>
      throw UnimplementedError();
  Future<List<NVDocument>> scanAll() async => throw UnimplementedError();
  Future<void> markDeleted(String id) async => throw UnimplementedError();
  Future<StorageStats> getStats() async => throw UnimplementedError();
}
