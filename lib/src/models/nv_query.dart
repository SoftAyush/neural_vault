import 'nv_value.dart';

/// Query operators
enum QueryOperator {
  equals,
  notEquals,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  contains,
  startsWith,
  endsWith,
  isIn,
  notIn,
}

/// Logical operators
enum LogicalOperator { and, or }

/// Query condition
class QueryCondition {
  final String field;
  final QueryOperator operator;
  final NVValue value;
  final LogicalOperator? logicalOp;

  const QueryCondition({
    required this.field,
    required this.operator,
    required this.value,
    this.logicalOp,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'operator': operator.name,
      'value': value.toJson(),
      if (logicalOp != null) 'logical': logicalOp!.name,
    };
  }
}

/// NeuralVault query builder
class NVQuery {
  final String collection;
  final List<QueryCondition> conditions;
  String? orderBy;
  bool orderDesc;
  int? limit;
  int? skip;

  NVQuery(this.collection) : conditions = [], orderDesc = false;

  /// Add a condition with equals operator
  NVQuery where(String field, {required dynamic equals}) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.equals,
        value: NVValue.from(equals),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a not-equals condition
  NVQuery whereNot(String field, {required dynamic equals}) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.notEquals,
        value: NVValue.from(equals),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a greater-than condition
  NVQuery whereGreaterThan(String field, num value) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.greaterThan,
        value: NVNumber(value.toDouble()),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a greater-than-or-equal condition
  NVQuery whereGreaterThanOrEqual(String field, num value) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.greaterThanOrEqual,
        value: NVNumber(value.toDouble()),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a less-than condition
  NVQuery whereLessThan(String field, num value) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.lessThan,
        value: NVNumber(value.toDouble()),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a less-than-or-equal condition
  NVQuery whereLessThanOrEqual(String field, num value) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.lessThanOrEqual,
        value: NVNumber(value.toDouble()),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a contains condition (for strings)
  NVQuery whereContains(String field, String substring) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.contains,
        value: NVString(substring),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add a starts-with condition
  NVQuery whereStartsWith(String field, String prefix) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.startsWith,
        value: NVString(prefix),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add an ends-with condition
  NVQuery whereEndsWith(String field, String suffix) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.endsWith,
        value: NVString(suffix),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add an IN condition
  NVQuery whereIn(String field, List<dynamic> values) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.isIn,
        value: NVArray(values.map((v) => NVValue.from(v)).toList()),
        logicalOp: conditions.isNotEmpty ? LogicalOperator.and : null,
      ),
    );
    return this;
  }

  /// Add an OR condition
  NVQuery or(String field, {required dynamic equals}) {
    conditions.add(
      QueryCondition(
        field: field,
        operator: QueryOperator.equals,
        value: NVValue.from(equals),
        logicalOp: LogicalOperator.or,
      ),
    );
    return this;
  }

  /// Set ordering
  NVQuery sort(String field, {bool descending = false}) {
    orderBy = field;
    orderDesc = descending;
    return this;
  }

  /// Set limit
  NVQuery take(int count) {
    limit = count;
    return this;
  }

  /// Set skip
  NVQuery skipCount(int count) {
    skip = count;
    return this;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'collection': collection,
      'conditions': conditions.map((c) => c.toJson()).toList(),
      if (orderBy != null) 'order_by': orderBy,
      'order_desc': orderDesc,
      if (limit != null) 'limit': limit,
      if (skip != null) 'skip': skip,
    };
  }

  @override
  String toString() => 'NVQuery($collection, ${conditions.length} conditions)';
}
