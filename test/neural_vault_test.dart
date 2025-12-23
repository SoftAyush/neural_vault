import 'package:flutter_test/flutter_test.dart';
import 'package:neural_vault/neural_vault.dart';
import 'dart:io';

void main() {
  late NeuralVault db;
  late Directory tempDir;

  setUp(() async {
    // Create temporary directory for tests
    tempDir = await Directory.systemTemp.createTemp('neural_vault_test_');

    db = NeuralVault(NeuralVaultConfig(path: tempDir.path));
    await db.initialize();
  });

  tearDown(() async {
    // Clean up
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Create Operations', () {
    test('create single document', () async {
      final id = await db.create('users', {'name': 'John Doe', 'age': 30});

      expect(id, isNotEmpty);

      final doc = await db.findById(id);
      expect(doc.collection, equals('users'));
      expect((doc.get('name') as NVString).value, equals('John Doe'));
      expect((doc.get('age') as NVNumber).value, equals(30.0));
    });

    test('create batch documents', () async {
      final ids = await db.createBatch('products', [
        {'name': 'Product 1', 'price': 10.0},
        {'name': 'Product 2', 'price': 20.0},
        {'name': 'Product 3', 'price': 30.0},
      ]);

      expect(ids.length, equals(3));

      final count = await db.count('products');
      expect(count, equals(3));
    });
  });

  group('Find Operations', () {
    setUp(() async {
      // Create test data
      for (var i = 1; i <= 10; i++) {
        await db.create('users', {
          'name': 'User $i',
          'age': 20 + i,
          'status': i % 2 == 0 ? 'active' : 'inactive',
        });
      }
    });

    test('find all documents', () async {
      final users = await db.findAll('users');
      expect(users.length, equals(10));
    });

    test('find with equals filter', () async {
      final query = NVQuery('users').where('status', equals: 'active');
      final results = await db.find(query);
      expect(results.length, equals(5));
    });

    test('find with greater than filter', () async {
      final query = NVQuery('users').whereGreaterThan('age', 25);
      final results = await db.find(query);
      expect(results.length, equals(5));
    });

    test('find with multiple conditions', () async {
      final query = NVQuery(
        'users',
      ).whereGreaterThan('age', 23).where('status', equals: 'active');

      final results = await db.find(query);
      expect(
        results.length,
        equals(4),
      ); // Users 4, 6, 8, 10 (ages 24, 26, 28, 30)
    });

    test('find with String contains', () async {
      final query = NVQuery('users').whereContains('name', 'User 1');
      final results = await db.find(query);
      expect(results.length, equals(2)); // User 1 and User 10
    });

    test('find with sorting', () async {
      final query = NVQuery('users').sort('age', descending: true);

      final results = await db.find(query);
      expect(results.length, equals(10));

      // Check descending order
      for (var i = 0; i < results.length - 1; i++) {
        final currentAge = (results[i].get('age') as NVNumber).value;
        final nextAge = (results[i + 1].get('age') as NVNumber).value;
        expect(currentAge, greaterThanOrEqualTo(nextAge));
      }
    });

    test('find with limit and skip', () async {
      final query = NVQuery('users').sort('age').skipCount(3).take(4);

      final results = await db.find(query);
      expect(results.length, equals(4));

      final firstAge = (results.first.get('age') as NVNumber).value;
      expect(firstAge, equals(24.0)); // Age 21, 22, 23 skipped
    });

    test('find one', () async {
      final doc = await db.findOne(
        NVQuery('users').where('status', equals: 'active'),
      );
      expect(doc, isNotNull);
      expect((doc!.get('status') as NVString).value, equals('active'));
    });
  });

  group('Update Operations', () {
    test('update by ID', () async {
      final id = await db.create('users', {'name': 'Alice', 'age': 25});

      await db.updateById(id, {'age': 26});

      final doc = await db.findById(id);
      expect((doc.get('age') as NVNumber).value, equals(26.0));
    });

    test('update multiple documents', () async {
      await db.create('users', {'name': 'Bob', 'status': 'pending'});
      await db.create('users', {'name': 'Charlie', 'status': 'pending'});
      await db.create('users', {'name': 'Dave', 'status': 'active'});

      final count = await db.update(
        NVQuery('users').where('status', equals: 'pending'),
        {'status': 'approved'},
      );

      expect(count, equals(2));

      final approved = await db.find(
        NVQuery('users').where('status', equals: 'approved'),
      );
      expect(approved.length, equals(2));
    });
  });

  group('Delete (Kill) Operations', () {
    test('kill by ID', () async {
      final id = await db.create('users', {'name': 'ToDelete', 'age': 99});

      await db.killById(id);

      expect(
        () async => await db.findById(id),
        throwsA(isA<DocumentNotFoundException>()),
      );
    });

    test('kill multiple documents', () async {
      await db.create('users', {'name': 'User1', 'temp': true});
      await db.create('users', {'name': 'User2', 'temp': true});
      await db.create('users', {'name': 'User3', 'temp': false});

      final count = await db.kill(NVQuery('users').where('temp', equals: true));

      expect(count, equals(2));

      final remaining = await db.findAll('users');
      expect(remaining.length, equals(1));
    });

    test('kill all in collection', () async {
      await db.create('temp', {'data': 1});
      await db.create('temp', {'data': 2});
      await db.create('temp', {'data': 3});

      final count = await db.killAll('temp');
      expect(count, equals(3));

      final remaining = await db.count('temp');
      expect(remaining, equals(0));
    });
  });

  group('Utility Operations', () {
    test('count documents', () async {
      await db.create('articles', {'title': 'Article 1'});
      await db.create('articles', {'title': 'Article 2'});
      await db.create('articles', {'title': 'Article 3'});

      final count = await db.count('articles');
      expect(count, equals(3));
    });

    test('count with query', () async {
      await db.create('posts', {'title': 'Post 1', 'published': true});
      await db.create('posts', {'title': 'Post 2', 'published': false});
      await db.create('posts', {'title': 'Post 3', 'published': true});

      final count = await db.countWhere(
        NVQuery('posts').where('published', equals: true),
      );
      expect(count, equals(2));
    });

    test('get collections', () async {
      await db.create('users', {'name': 'User'});
      await db.create('posts', {'title': 'Post'});
      await db.create('comments', {'text': 'Comment'});

      final collections = await db.collections();
      expect(collections.length, equals(3));
      expect(collections, containsAll(['users', 'posts', 'comments']));
    });

    test('get statistics', () async {
      await db.create('users', {'name': 'User1'});
      await db.create('users', {'name': 'User2'});
      await db.create('posts', {'title': 'Post1'});

      final stats = await db.stats();
      expect(stats.totalDocuments, equals(3));
      expect(stats.totalCollections, equals(2));
      expect(stats.storageSizeBytes, greaterThan(0));
    });
  });

  group('Complex Queries', () {
    setUp(() async {
      // Create test data with various fields
      await db.create('products', {
        'name': 'Laptop',
        'price': 1200.0,
        'category': 'Electronics',
        'inStock': true,
      });
      await db.create('products', {
        'name': 'Mouse',
        'price': 25.0,
        'category': 'Electronics',
        'inStock': true,
      });
      await db.create('products', {
        'name': 'Desk',
        'price': 300.0,
        'category': 'Furniture',
        'inStock': false,
      });
      await db.create('products', {
        'name': 'Chair',
        'price': 150.0,
        'category': 'Furniture',
        'inStock': true,
      });
    });

    test('query with AND conditions', () async {
      final query = NVQuery(
        'products',
      ).where('category', equals: 'Electronics').whereLessThan('price', 1000);

      final results = await db.find(query);
      expect(results.length, equals(1));
      expect((results.first.get('name') as NVString).value, equals('Mouse'));
    });

    test('query with OR conditions', () async {
      final query = NVQuery(
        'products',
      ).where('category', equals: 'Electronics').or('price', equals: 150.0);

      final results = await db.find(query);
      expect(results.length, equals(3)); // 2 Electronics + 1 with price 150
    });

    test('complex query with sorting and pagination', () async {
      final query = NVQuery(
        'products',
      ).whereGreaterThan('price', 50).sort('price', descending: true).take(2);

      final results = await db.find(query);
      expect(results.length, equals(2));
      expect((results[0].get('name') as NVString).value, equals('Laptop'));
      expect((results[1].get('name') as NVString).value, equals('Desk'));
    });
  });
}
