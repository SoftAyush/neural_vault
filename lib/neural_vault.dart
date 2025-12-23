/// NeuralVault - A high-performance NoSQL database for Flutter
///
/// NeuralVault is a cross-platform, file-based NoSQL database designed
/// specifically for Flutter applications. It provides a simple, elegant API
/// for CRUD operations with support for complex queries, sorting, and filtering.
///
/// ## Features
///
/// * **Cross-Platform**: Works on Android, iOS, Windows, macOS, Linux, and Web
/// * **Simple API**: Intuitive CRUD operations (Create, Find, Update, Kill)
/// * **Powerful Queries**: Filter, sort, paginate with fluent query builder
/// * **Persistent Storage**: File-based storage with automatic indexing
/// * **Type-Safe**: Strongly typed documents with flexible data structures
/// * **Lightweight**: Zero external dependencies for core functionality
///
/// ## Usage
///
/// ```dart
/// // Initialize database
/// final db = NeuralVault(NeuralVaultConfig(path: './my_database'));
/// await db.initialize();
///
/// // Create documents
/// final id = await db.create('users', {
///   'name': 'John Doe',
///   'age': 30,
///   'email': 'john@example.com',
/// });
///
/// // Find documents
/// final adults = await db.find(
///   NVQuery('users')
///     .whereGreaterThanOrEqual('age', 18)
///     .sort('name')
///     .take(10),
/// );
///
/// // Update documents
/// await db.updateById(id, {'age': 31});
///
/// // Delete (kill) documents
/// await db.killById(id);
///
/// // Get statistics
/// final stats = await db.stats();
/// print('Total documents: ${stats.totalDocuments}');
/// ```
library;

// Core
export 'src/neural_vault_base.dart';

// Models
export 'src/models/nv_document.dart';
export 'src/models/nv_query.dart';
export 'src/models/nv_value.dart';

// Exceptions
export 'src/exceptions.dart';
