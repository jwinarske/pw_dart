// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PwEventDeserializer', () {
    test('deserializeEvent with valid JSON', () {
      const json =
          '{"type":"node_added","node":{"id":1,"name":"test","state":"idle"}}';
      final event = PwEventDeserializer.deserializeEvent(json);
      expect(event, isA<NodeAdded>());
      expect((event as NodeAdded).node.id, 1);
    });

    test('deserializeEvent with malformed JSON returns null', () {
      final event = PwEventDeserializer.deserializeEvent('{bad json');
      expect(event, isNull);
    });

    test('deserializeEvent with unknown type returns null', () {
      const json = '{"type":"unknown_event_type"}';
      final event = PwEventDeserializer.deserializeEvent(json);
      expect(event, isNull);
    });

    test('deserializeEvent with empty string returns null', () {
      final event = PwEventDeserializer.deserializeEvent('');
      expect(event, isNull);
    });

    test('deserializeSnapshot with valid JSON', () {
      const json =
          '{"nodes":[{"id":1,"name":"n","state":"idle"}],"ports":[],"links":[],"devices":[]}';
      final graph = PwEventDeserializer.deserializeSnapshot(json);
      expect(graph.nodes.length, 1);
    });

    test('deserializeSnapshot with malformed JSON returns empty graph', () {
      final graph = PwEventDeserializer.deserializeSnapshot('{bad');
      expect(graph.nodes, isEmpty);
    });

    test('deserializeParams with valid JSON', () {
      const json =
          '[{"key":"volume","value":0.5,"type":"Float","flags":{"readable":true,"writable":true}}]';
      final params = PwEventDeserializer.deserializeParams(json);
      expect(params.length, 1);
      expect(params['volume']!.value, 0.5);
      expect(params['volume']!.type, PwParamType.float_);
    });

    test('deserializeParams with empty array', () {
      final params = PwEventDeserializer.deserializeParams('[]');
      expect(params, isEmpty);
    });

    test('deserializeParams with malformed JSON returns empty', () {
      final params = PwEventDeserializer.deserializeParams('[bad');
      expect(params, isEmpty);
    });

    test('deserializeParams with multiple params', () {
      const json = '''[
        {"key":"volume","value":0.5,"type":"Float"},
        {"key":"mute","value":false,"type":"Bool"},
        {"key":"name","value":"Main","type":"String"}
      ]''';
      final params = PwEventDeserializer.deserializeParams(json);
      expect(params.length, 3);
      expect(params.containsKey('volume'), isTrue);
      expect(params.containsKey('mute'), isTrue);
      expect(params.containsKey('name'), isTrue);
    });
  });
}
