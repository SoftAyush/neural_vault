import 'package:flutter/material.dart';
import 'package:neural_vault/neural_vault.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuralVault Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DatabaseDemo(),
    );
  }
}

class DatabaseDemo extends StatefulWidget {
  const DatabaseDemo({super.key});

  @override
  State<DatabaseDemo> createState() => _DatabaseDemoState();
}

class _DatabaseDemoState extends State<DatabaseDemo> {
  NeuralVault? _db;
  String _status = 'Not initialized';
  List<NVDocument> _documents = [];
  DatabaseStats? _stats;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, 'neural_vault_demo');

      _db = NeuralVault(NeuralVaultConfig(path: dbPath));
      await _db!.initialize();

      setState(() {
        _status = 'Database initialized at: $dbPath';
      });

      await _refreshData();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _refreshData() async {
    if (_db == null) return;

    try {
      final docs = await _db!.findAll('demo_collection');
      final stats = await _db!.stats();

      setState(() {
        _documents = docs;
        _stats = stats;
      });
    } catch (e) {
      _showError('Error refreshing data: $e');
    }
  }

  Future<void> _createDocument() async {
    if (_db == null) return;

    try {
      await _db!.create('demo_collection', {
        'name': 'Sample ${DateTime.now().millisecondsSinceEpoch}',
        'value': DateTime.now().second,
        'timestamp': DateTime.now().toIso8601String(),
        'active': true,
      });

      await _refreshData();
      _showSuccess('Document created!');
    } catch (e) {
      _showError('Error creating document: $e');
    }
  }

  Future<void> _queryDocuments() async {
    if (_db == null) return;

    try {
      final query = NVQuery(
        'demo_collection',
      ).whereGreaterThan('value', 30).sort('value', descending: true).take(5);

      final results = await _db!.find(query);

      setState(() {
        _documents = results;
      });

      _showSuccess('Found ${results.length} document(s) with value > 30');
    } catch (e) {
      _showError('Error querying: $e');
    }
  }

  Future<void> _updateRandomDocument() async {
    if (_db == null || _documents.isEmpty) return;

    try {
      final doc = _documents.first;
      await _db!.updateById(doc.id, {
        'updated': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _refreshData();
      _showSuccess('Document updated!');
    } catch (e) {
      _showError('Error updating: $e');
    }
  }

  Future<void> _deleteDocument() async {
    if (_db == null || _documents.isEmpty) return;

    try {
      final doc = _documents.first;
      await _db!.killById(doc.id);

      await _refreshData();
      _showSuccess('Document deleted!');
    } catch (e) {
      _showError('Error deleting: $e');
    }
  }

  Future<void> _clearAll() async {
    if (_db == null) return;

    try {
      final count = await _db!.killAll('demo_collection');
      await _refreshData();
      _showSuccess('Deleted $count document(s)');
    } catch (e) {
      _showError('Error clearing: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuralVault Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_stats != null) ...[
                  const SizedBox(height: 8),
                  Text('Total Documents: ${_stats!.totalDocuments}'),
                  Text('Collections: ${_stats!.totalCollections}'),
                  Text('Storage Size: ${_stats!.storageSizeBytes} bytes'),
                ],
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _createDocument,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
                ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                ElevatedButton.icon(
                  onPressed: _queryDocuments,
                  icon: const Icon(Icons.search),
                  label: const Text('Query'),
                ),
                ElevatedButton.icon(
                  onPressed: _updateRandomDocument,
                  icon: const Icon(Icons.edit),
                  label: const Text('Update First'),
                ),
                ElevatedButton.icon(
                  onPressed: _deleteDocument,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete First'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Documents List
          Expanded(
            child: _documents.isEmpty
                ? const Center(child: Text('No documents'))
                : ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            'ID: ${doc.id.substring(0, 8)}...',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Collection: ${doc.collection}'),
                              Text('Data: ${_formatData(doc)}'),
                              Text('Created: ${_formatDate(doc.createdAt)}'),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatData(NVDocument doc) {
    final entries = doc.data.entries.take(3).map((e) {
      final value = e.value.toDynamic();
      return '${e.key}: $value';
    });
    return entries.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
