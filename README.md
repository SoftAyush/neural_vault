# NeuralVault 🧠

A high-performance, cross-platform NoSQL database for Flutter applications. Built with Dart for seamless integration and designed to work across all Flutter platforms including Android, iOS, Windows, macOS, Linux, and Web.

## Features ✨

- **🚀 High Performance**: Optimized file-based storage with in-memory indexing
- **📱 Cross-Platform**: Works on Android, iOS, Windows, macOS, Linux, and Web
- **💡 Simple API**: Intuitive CRUD operations (Create, Find, Update, Kill)
- **🔍 Powerful Queries**: Fluent query builder with filtering, sorting, and pagination
- **💾 Persistent Storage**: Automatic file-based persistence with corruption detection
- **🔒 Type-Safe**: Strongly typed documents with flexible data structures
- **⚡ Lightweight**: Zero external dependencies for core functionality
- **📊 Statistics**: Built-in database statistics and analytics

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  neural_vault: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Initialize Database

```dart
import 'package:neural_vault/neural_vault.dart';

// Create database instance
final db = NeuralVault(NeuralVaultConfig(
  path: './my_database', // or use path_provider for mobile
));

// Initialize
await db.initialize();
```

### Create (Insert) Documents

```dart
// Create a single document
final userId = await db.create('users', {
  'name': 'John Doe',
  'age': 30,
  'email': 'john@example.com',
  'active': true,
});

// Create multiple documents in batch
final ids = await db.createBatch('products', [
  {'name': 'Laptop', 'price': 1200.0},
  {'name': 'Mouse', 'price': 25.0},
  {'name': 'Keyboard', 'price': 75.0},
]);
```

### Find (Query) Documents

```dart
// Find all documents in a collection
final allUsers = await db.findAll('users');

// Find by ID
final user = await db.findById(userId);

// Simple query with equals
final activeUsers = await db.find(
  NVQuery('users').where('active', equals: true),
);

// Complex query with multiple conditions
final adults = await db.find(
  NVQuery('users')
    .whereGreaterThanOrEqual('age', 18)
    .where('active', equals: true)
    .sort('name')
    .take(10),
);

// Query with string operations
final results = await db.find(
  NVQuery('users')
    .whereContains('email', '@gmail.com')
    .or('email', equals: 'admin@example.com'),
);

// Find first matching document
final admin = await db.findOne(
  NVQuery('users').where('role', equals: 'admin'),
);
```

### Query Operators

**Comparison Operators:**
- `where(field, equals: value)` - Equals
- `whereNot(field, equals: value)` - Not equals
- `whereGreaterThan(field, value)` - Greater than
- `whereGreaterThanOrEqual(field, value)` - Greater than or equal
- `whereLessThan(field, value)` - Less than
- `whereLessThanOrEqual(field, value)` - Less than or equal

**String Operators:**
- `whereContains(field, substring)` - Contains substring
- `whereStartsWith(field, prefix)` - Starts with prefix
- `whereEndsWith(field, suffix)` - Ends with suffix

**Array Operators:**
- `whereIn(field, values)` - Value in array

**Logical Operators:**
- `.where()` - AND (default)
- `.or()` - OR

**Sorting & Pagination:**
- `sort(field, descending: bool)` - Sort by field
- `take(count)` - Limit results
- `skipCount(count)` - Skip results

### Update Documents

```dart
// Update by ID
await db.updateById(userId, {
  'age': 31,
  'last_login': DateTime.now().toIso8601String(),
});

// Update multiple documents matching a query
final count = await db.update(
  NVQuery('users').where('status', equals: 'pending'),
  {'status': 'approved'},
);
print('Updated $count documents');
```

### Delete (Kill) Documents

```dart
// Delete by ID
await db.killById(userId);

// Delete matching query
final count = await db.kill(
  NVQuery('users').where('active', equals: false),
);

// Delete all documents in a collection
await db.killAll('temp_collection');
```

### Utility Functions

```dart
// Count documents
final userCount = await db.count('users');

// Count with query
final activeCount = await db.countWhere(
  NVQuery('users').where('active', equals: true),
);

// Get all collections
final collections = await db.collections();

// Get database statistics
final stats = await db.stats();
print('Total documents: ${stats.totalDocuments}');
print('Total collections: ${stats.totalCollections}');
print('Storage size: ${stats.storageSizeBytes} bytes');
```

## Supported Data Types

NeuralVault supports the following data types through `NVValue`:

- `null`
- `bool`
- `num` (stored as `double`)
- `String`
- `List` (arrays)
- `Map<String, dynamic>` (objects/nested documents)

All values are automatically converted to the appropriate `NVValue` type.

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅ Supported |
| iOS      | ✅ Supported |
| Windows  | ✅ Supported |
| macOS    | ✅ Supported |
| Linux    | ✅ Supported |
| Web      | ✅ Supported |

## Performance

NeuralVault is optimized for:
- Fast writes with append-only log
- Efficient reads with in-memory indexing
- Quick queries with optimized filtering
- Low memory footprint

## Architecture

```
┌─────────────────┐
│   Flutter App   │
└────────┬────────┘
         │
┌────────▼────────┐
│   NeuralVault   │
│   (Dart API)    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼───┐
│Query │  │Storage│
│Engine│  │Engine │
└──────┘  └───┬───┘
              │
         ┌────▼────┐
         │File I/O │
         └─────────┘
```

## Future Enhancements

🚧 The following features are planned for future releases:

- **Rust Backend**: Optional high-performance Rust core with flutter_rust_bridge
- **Encryption**: Built-in AES-256 encryption at rest
- **Compression**: LZ4 compression for reduced storage
- **Indexes**: Custom secondary indexes for faster queries
- **Transactions**: ACID transaction support
- **Sync**: Cloud synchronization capabilities
- **WAL**: Write-ahead logging for crash recovery
- **Migrations**: Schema migration tools

## Example App

Check out the [`example`](./example) directory for a complete Flutter app demonstrating all features.

```bash
cd example
flutter run
```

## Testing

Run the test suite:

```bash
flutter test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

Developed by a senior Flutter developer with ❤️ for the Flutter community.

---

**Note**: This is currently a pure Dart implementation. A Rust-powered version with flutter_rust_bridge for enhanced performance is planned for future releases.
