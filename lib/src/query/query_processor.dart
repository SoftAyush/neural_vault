import '../models/nv_document.dart';
import '../models/nv_query.dart';
import '../models/nv_value.dart';

/// Query processor for filtering and sorting documents
class QueryProcessor {
  /// Filter documents based on query
  List<NVDocument> filter(List<NVDocument> documents, NVQuery query) {
    if (documents.isEmpty) return [];

    // Apply filter conditions
    var results = documents.where((doc) => _matchesQuery(doc, query)).toList();

    // Apply ordering
    if (query.orderBy != null) {
      _sortDocuments(results, query.orderBy!, query.orderDesc);
    }

    // Apply skip
    if (query.skip != null && query.skip! > 0) {
      results = results.skip(query.skip!).toList();
    }

    // Apply limit
    if (query.limit != null) {
      results = results.take(query.limit!).toList();
    }

    return results;
  }

  /// Check if document matches query
  bool _matchesQuery(NVDocument document, NVQuery query) {
    if (query.conditions.isEmpty) return true;

    // Start with first condition
    var result = _evaluateCondition(document, query.conditions.first);

    // Apply logical operators
    for (var i = 1; i < query.conditions.length; i++) {
      final condition = query.conditions[i];
      final nextResult = _evaluateCondition(document, condition);

      result = switch (condition.logicalOp) {
        LogicalOperator.and => result && nextResult,
        LogicalOperator.or => result || nextResult,
        null => result && nextResult,
      };
    }

    return result;
  }

  /// Evaluate a single condition
  bool _evaluateCondition(NVDocument document, QueryCondition condition) {
    final fieldValue = document.get(condition.field);
    if (fieldValue == null) return false;

    return _compareValues(fieldValue, condition.value, condition.operator);
  }

  /// Compare two values based on operator
  bool _compareValues(NVValue left, NVValue right, QueryOperator operator) {
    return switch (operator) {
      QueryOperator.equals => _valuesEqual(left, right),
      QueryOperator.notEquals => !_valuesEqual(left, right),
      QueryOperator.greaterThan => _compareNumeric(
        left,
        right,
        (a, b) => a > b,
      ),
      QueryOperator.greaterThanOrEqual => _compareNumeric(
        left,
        right,
        (a, b) => a >= b,
      ),
      QueryOperator.lessThan => _compareNumeric(left, right, (a, b) => a < b),
      QueryOperator.lessThanOrEqual => _compareNumeric(
        left,
        right,
        (a, b) => a <= b,
      ),
      QueryOperator.contains => _stringContains(left, right),
      QueryOperator.startsWith => _stringStartsWith(left, right),
      QueryOperator.endsWith => _stringEndsWith(left, right),
      QueryOperator.isIn => _valueInArray(left, right),
      QueryOperator.notIn => !_valueInArray(left, right),
    };
  }

  /// Check if values are equal
  bool _valuesEqual(NVValue left, NVValue right) {
    return left == right;
  }

  /// Compare numeric values
  bool _compareNumeric(
    NVValue left,
    NVValue right,
    bool Function(double, double) comparator,
  ) {
    if (left is NVNumber && right is NVNumber) {
      return comparator(left.value, right.value);
    }
    return false;
  }

  /// Check if string contains substring
  bool _stringContains(NVValue left, NVValue right) {
    if (left is NVString && right is NVString) {
      return left.value.contains(right.value);
    }
    return false;
  }

  /// Check if string starts with prefix
  bool _stringStartsWith(NVValue left, NVValue right) {
    if (left is NVString && right is NVString) {
      return left.value.startsWith(right.value);
    }
    return false;
  }

  /// Check if string ends with suffix
  bool _stringEndsWith(NVValue left, NVValue right) {
    if (left is NVString && right is NVString) {
      return left.value.endsWith(right.value);
    }
    return false;
  }

  /// Check if value is in array
  bool _valueInArray(NVValue value, NVValue array) {
    if (array is NVArray) {
      return array.value.any((item) => _valuesEqual(value, item));
    }
    return false;
  }

  /// Sort documents by field
  void _sortDocuments(
    List<NVDocument> documents,
    String field,
    bool descending,
  ) {
    documents.sort((a, b) {
      final aVal = a.get(field);
      final bVal = b.get(field);

      int ordering = _compareForSort(aVal, bVal);

      return descending ? -ordering : ordering;
    });
  }

  /// Compare values for sorting
  int _compareForSort(NVValue? a, NVValue? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    if (a is NVNumber && b is NVNumber) {
      return a.value.compareTo(b.value);
    }

    if (a is NVString && b is NVString) {
      return a.value.compareTo(b.value);
    }

    if (a is NVBool && b is NVBool) {
      return a.value == b.value ? 0 : (a.value ? 1 : -1);
    }

    return 0;
  }
}
