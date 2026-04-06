// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

/// Parameter value type.
enum PwParamType {
  int_,
  float_,
  double_,
  string,
  bool_,
  bytes,
  unknown;

  static PwParamType fromString(String s) => switch (s) {
        'Int' || 'int' => int_,
        'Float' || 'float' => float_,
        'Double' || 'double' => double_,
        'String' || 'string' => string,
        'Bool' || 'bool' => bool_,
        'Bytes' || 'bytes' => bytes,
        _ => unknown,
      };

  String toJsonString() => switch (this) {
        int_ => 'Int',
        float_ => 'Float',
        double_ => 'Double',
        string => 'String',
        bool_ => 'Bool',
        bytes => 'Bytes',
        unknown => 'Unknown',
      };
}

/// Parameter flags.
class PwParamFlags {
  final bool readable;
  final bool writable;

  const PwParamFlags({
    this.readable = true,
    this.writable = false,
  });

  factory PwParamFlags.fromJson(Map<String, dynamic> json) => PwParamFlags(
        readable: (json['readable'] as bool?) ?? true,
        writable: (json['writable'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'readable': readable,
        'writable': writable,
      };

  @override
  String toString() =>
      'PwParamFlags(${readable ? "r" : ""}${writable ? "w" : ""})';
}

/// A PipeWire node parameter.
class PwParam {
  /// Parameter key / name.
  final String key;

  /// Current value.
  final Object? value;

  /// Value type.
  final PwParamType type;

  /// Access flags.
  final PwParamFlags flags;

  /// Default value (if available).
  final Object? defaultValue;

  /// Minimum value (for numeric types).
  final Object? min;

  /// Maximum value (for numeric types).
  final Object? max;

  const PwParam({
    required this.key,
    this.value,
    this.type = PwParamType.unknown,
    this.flags = const PwParamFlags(),
    this.defaultValue,
    this.min,
    this.max,
  });

  factory PwParam.fromJson(Map<String, dynamic> json) => PwParam(
        key: json['key'] as String,
        value: json['value'],
        type: PwParamType.fromString((json['type'] as String?) ?? 'unknown'),
        flags: json['flags'] != null
            ? PwParamFlags.fromJson(json['flags'] as Map<String, dynamic>)
            : const PwParamFlags(),
        defaultValue: json['default'],
        min: json['min'],
        max: json['max'],
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'type': type.toJsonString(),
        'flags': flags.toJson(),
        if (defaultValue != null) 'default': defaultValue,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PwParam && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'PwParam("$key", $value, ${type.toJsonString()})';
}

