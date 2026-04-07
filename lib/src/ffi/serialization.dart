// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:convert';

import '../events.dart';
import '../graph.dart';
import '../models/models.dart';

/// Deserializes JSON strings from the native layer into Dart objects.
class PwEventDeserializer {
  const PwEventDeserializer._();

  /// Deserialize a JSON event string into a [PwGraphEvent].
  ///
  /// Returns `null` for unknown or malformed events (defensive parsing).
  static PwGraphEvent? deserializeEvent(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PwGraphEvent.fromJson(map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Deserialize a JSON snapshot string into a [PwGraph].
  static PwGraph deserializeSnapshot(String json) {
    try {
      return PwGraph.fromJsonString(json);
    } on FormatException {
      return const PwGraph.empty();
    } on TypeError {
      return const PwGraph.empty();
    }
  }

  /// Deserialize a JSON params array string into a param map.
  static Map<String, PwParam> deserializeParams(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final params = <String, PwParam>{};
      for (final item in list) {
        final param = PwParam.fromJson(item as Map<String, dynamic>);
        params[param.key] = param;
      }
      return params;
    } on FormatException {
      return const {};
    } on TypeError {
      return const {};
    }
  }
}

