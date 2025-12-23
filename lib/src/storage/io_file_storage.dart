import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/nv_document.dart';
import '../exceptions.dart';
import 'storage_stats.dart';

/// File-based storage manager
class FileStorage {
  final String dbPath;
  final File _dataFile;
  final Map<String, int> _index = {}; // id -> file position

  FileStorage._(this.dbPath, this._dataFile);

  static Future<FileStorage> initialize(String dbPath) async {
    final dir = Directory(dbPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final dataFile = File(path.join(dbPath, 'data.nvdb'));
    if (!await dataFile.exists()) {
      await dataFile.create();
    }

    final storage = FileStorage._(dbPath, dataFile);
    await storage._rebuildIndex();
    return storage;
  }

  /// Append a document to storage
  Future<void> append(NVDocument document) async {
    try {
      // Serialize document
      final json = document.toJson();
      final jsonStr = jsonEncode(json);
      final bytes = utf8.encode(jsonStr);

      // Get current file position before writing
      final position = await _dataFile.length();

      // Write record: [length(4 bytes)][data][newline]
      final lengthBytes = _uint32ToBytes(bytes.length);
      final recordBytes = <int>[
        ...lengthBytes,
        ...bytes,
        10, // newline
      ];

      // Append to file
      await _dataFile.writeAsBytes(
        recordBytes,
        mode: FileMode.append,
        flush: true,
      );

      // Update index
      _index[document.id] = position;
    } catch (e) {
      throw StorageException('Failed to append document: $e');
    }
  }

  /// Read a document by ID
  Future<NVDocument> read(String id) async {
    final position = _index[id];
    if (position == null) {
      throw DocumentNotFoundException(id);
    }

    return await _readAt(position);
  }

  /// Read document at specific position
  Future<NVDocument> _readAt(int position) async {
    try {
      final raf = await _dataFile.open(mode: FileMode.read);
      try {
        await raf.setPosition(position);

        // Read length
        final lengthBytes = await raf.read(4);
        if (lengthBytes.length < 4) {
          throw StorageException('Corrupted data: incomplete length');
        }
        final length = _bytesToUint32(lengthBytes);

        // Read data
        final dataBytes = await raf.read(length);
        if (dataBytes.length < length) {
          throw StorageException('Corrupted data: incomplete record');
        }

        // Deserialize
        final jsonStr = utf8.decode(dataBytes);
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return NVDocument.fromJson(json);
      } finally {
        await raf.close();
      }
    } catch (e) {
      throw StorageException('Failed to read document: $e');
    }
  }

  /// Scan all documents in a collection
  Future<List<NVDocument>> scanCollection(String collection) async {
    final documents = <NVDocument>[];

    for (final position in _index.values) {
      try {
        final doc = await _readAt(position);
        if (doc.collection == collection && !doc.deleted) {
          documents.add(doc);
        }
      } catch (e) {
        // Skip corrupted documents
        continue;
      }
    }

    return documents;
  }

  /// Scan all documents
  Future<List<NVDocument>> scanAll() async {
    final documents = <NVDocument>[];

    if (await _dataFile.length() == 0) {
      return documents;
    }

    final raf = await _dataFile.open(mode: FileMode.read);
    try {
      while (true) {
        // Read length
        final lengthBytes = await raf.read(4);
        if (lengthBytes.isEmpty || lengthBytes.length < 4) break;

        final length = _bytesToUint32(lengthBytes);

        // Read data
        final dataBytes = await raf.read(length);
        if (dataBytes.length < length) break;

        // Skip newline
        await raf.read(1);

        try {
          final jsonStr = utf8.decode(dataBytes);
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final doc = NVDocument.fromJson(json);

          if (!doc.deleted) {
            documents.add(doc);
          }
        } catch (e) {
          // Skip corrupted documents
          continue;
        }
      }
    } finally {
      await raf.close();
    }

    return documents;
  }

  /// Rebuild index from storage file
  Future<void> _rebuildIndex() async {
    _index.clear();

    if (await _dataFile.length() == 0) {
      return;
    }

    final raf = await _dataFile.open(mode: FileMode.read);
    try {
      while (true) {
        final position = await raf.position();

        // Read length
        final lengthBytes = await raf.read(4);
        if (lengthBytes.isEmpty || lengthBytes.length < 4) break;

        final length = _bytesToUint32(lengthBytes);

        // Read data
        final dataBytes = await raf.read(length);
        if (dataBytes.length < length) break;

        // Skip newline
        await raf.read(1);

        try {
          final jsonStr = utf8.decode(dataBytes);
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final id = json['id'] as String;
          final deleted = json['deleted'] as bool? ?? false;

          if (!deleted) {
            _index[id] = position;
          }
        } catch (e) {
          // Skip corrupted documents
          continue;
        }
      }
    } finally {
      await raf.close();
    }
  }

  /// Mark a document as deleted
  Future<void> markDeleted(String id) async {
    final doc = await read(id);
    final deletedDoc = doc.copyWith(deleted: true);
    await append(deletedDoc);
    _index.remove(id);
  }

  /// Get storage statistics
  Future<StorageStats> getStats() async {
    return StorageStats(
      documentCount: _index.length,
      fileSizeBytes: await _dataFile.length(),
    );
  }

  /// Convert uint32 to bytes (little-endian)
  List<int> _uint32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  /// Convert bytes to uint32 (little-endian)
  int _bytesToUint32(List<int> bytes) {
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }
}
