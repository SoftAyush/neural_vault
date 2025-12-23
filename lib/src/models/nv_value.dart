/// Value types supported by NeuralVault
abstract class NVValue {
  const NVValue();

  /// Convert dynamic value to NVValue
  factory NVValue.from(dynamic value) {
    if (value == null) return const NVNull();
    if (value is bool) return NVBool(value);
    if (value is num) return NVNumber(value.toDouble());
    if (value is String) return NVString(value);
    if (value is List) {
      return NVArray(value.map((e) => NVValue.from(e)).toList());
    }
    if (value is Map<String, dynamic>) {
      return NVObject(value.map((k, v) => MapEntry(k, NVValue.from(v))));
    }
    throw ArgumentError('Unsupported value type: ${value.runtimeType}');
  }

  /// Convert to Dart dynamic
  dynamic toDynamic();

  /// Convert to JSON-compatible object
  dynamic toJson() => toDynamic();
}

class NVNull extends NVValue {
  const NVNull();

  @override
  dynamic toDynamic() => null;

  @override
  bool operator ==(Object other) => other is NVNull;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'null';
}

class NVBool extends NVValue {
  final bool value;

  const NVBool(this.value);

  @override
  dynamic toDynamic() => value;

  @override
  bool operator ==(Object other) => other is NVBool && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

class NVNumber extends NVValue {
  final double value;

  const NVNumber(this.value);

  @override
  dynamic toDynamic() => value;

  @override
  bool operator ==(Object other) =>
      other is NVNumber && (other.value - value).abs() < double.minPositive;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

class NVString extends NVValue {
  final String value;

  const NVString(this.value);

  @override
  dynamic toDynamic() => value;

  @override
  bool operator ==(Object other) => other is NVString && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '"$value"';
}

class NVArray extends NVValue {
  final List<NVValue> value;

  const NVArray(this.value);

  @override
  dynamic toDynamic() => value.map((e) => e.toDynamic()).toList();

  @override
  bool operator ==(Object other) {
    if (other is! NVArray || other.value.length != value.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (value[i] != other.value[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(value);

  @override
  String toString() => value.toString();
}

class NVObject extends NVValue {
  final Map<String, NVValue> value;

  const NVObject(this.value);

  @override
  dynamic toDynamic() => value.map((k, v) => MapEntry(k, v.toDynamic()));

  @override
  bool operator ==(Object other) {
    if (other is! NVObject || other.value.length != value.length) return false;
    for (var key in value.keys) {
      if (!other.value.containsKey(key) || value[key] != other.value[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(value.entries);

  @override
  String toString() => value.toString();
}
