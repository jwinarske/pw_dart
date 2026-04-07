// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:async';

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

import 'mock_native_bridge.dart';

void main() {
  late MockPwNativeBridge mockBridge;

  setUp(() {
    mockBridge = MockPwNativeBridge();
    mockBridge.snapshotJson = '{"nodes":[],"ports":[],"links":[],"devices":[]}';
  });

  group('PwClient.connect', () {
    test('connects and returns client', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      expect(client.isDisposed, isFalse);
      expect(mockBridge.connectCalled, isTrue);
      expect(client.graph.nodes, isEmpty);
      await client.dispose();
    });

    test('passes remote name to bridge', () async {
      final client = await PwClient.connect(
        remoteName: 'test-remote',
        bridge: mockBridge,
      );
      expect(mockBridge.lastRemoteName, 'test-remote');
      await client.dispose();
    });

    test('fetches initial graph snapshot', () async {
      mockBridge.snapshotJson = '''
        {"nodes":[{"id":1,"name":"node1","state":"idle"}],
         "ports":[],"links":[],"devices":[]}
      ''';
      final client = await PwClient.connect(bridge: mockBridge);
      expect(client.graph.nodes.length, 1);
      expect(client.graph.nodes[1]!.name, 'node1');
      await client.dispose();
    });
  });

  group('PwClient.events', () {
    test('emits deserialized events from native', () async {
      final client = await PwClient.connect(bridge: mockBridge);

      final events = <PwGraphEvent>[];
      final sub = client.events.listen(events.add);

      // Simulate native event
      mockBridge.simulateEvent({
        'type': 'node_added',
        'node': {'id': 42, 'name': 'new_node', 'media_class': 'Audio/Sink', 'state': 'idle'},
      });

      // Give the event time to propagate
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events.length, 1);
      expect(events.first, isA<NodeAdded>());
      expect((events.first as NodeAdded).node.id, 42);

      await sub.cancel();
      await client.dispose();
    });

    test('updates graph snapshot on events', () async {
      final client = await PwClient.connect(bridge: mockBridge);

      mockBridge.simulateEvent({
        'type': 'node_added',
        'node': {'id': 1, 'name': 'test', 'state': 'idle'},
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(client.graph.nodes.length, 1);
      expect(client.graph.nodes[1]!.name, 'test');

      mockBridge.simulateEvent({
        'type': 'node_removed',
        'node_id': 1,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(client.graph.nodes, isEmpty);

      await client.dispose();
    });

    test('ignores malformed events', () async {
      final client = await PwClient.connect(bridge: mockBridge);

      final events = <PwGraphEvent>[];
      final sub = client.events.listen(events.add);

      mockBridge.simulateRawEvent('not valid json');
      mockBridge.simulateRawEvent('{"type":"unknown_event_type"}');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, isEmpty);

      await sub.cancel();
      await client.dispose();
    });
  });

  group('PwClient mutations', () {
    test('destroyLink delegates to bridge', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      await client.destroyLink(42);
      expect(mockBridge.destroyedLinks, [42]);
      await client.dispose();
    });

    test('setNodeParam delegates to bridge', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      await client.setNodeParam(1, 'volume', 0.5);
      expect(mockBridge.setParams, [(1, 'volume', 0.5)]);
      await client.dispose();
    });

    test('getNodeParams delegates to bridge', () async {
      mockBridge.paramsJson =
          '[{"key":"volume","value":0.5,"type":"Float","flags":{"readable":true,"writable":true}}]';
      final client = await PwClient.connect(bridge: mockBridge);
      final params = await client.getNodeParams(1);
      expect(params.length, 1);
      expect(params['volume']!.value, 0.5);
      await client.dispose();
    });
  });

  group('PwClient.getVersion', () {
    test('returns version info', () async {
      mockBridge.headerVer = (0, 3, 77);
      mockBridge.libraryVer = (0, 3, 80);
      final client = await PwClient.connect(bridge: mockBridge);
      final version = client.getVersion();
      expect(version.headerVersion, (0, 3, 77));
      expect(version.libraryVersion, (0, 3, 80));
      expect(version.isCompatible, isTrue);
      expect(version.meetsMinimumVersion, isTrue);
      await client.dispose();
    });
  });

  group('PwClient.dispose', () {
    test('calls disconnect on bridge', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      await client.dispose();
      expect(mockBridge.disconnectCalled, isTrue);
      expect(client.isDisposed, isTrue);
    });

    test('double dispose is safe', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      await client.dispose();
      await client.dispose(); // Should not throw
    });

    test('operations after dispose throw StateError', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      await client.dispose();

      expect(() => client.getVersion(), throwsStateError);
      expect(() async => client.destroyLink(1), throwsStateError);
      expect(() async => client.setNodeParam(1, 'k', 'v'), throwsStateError);
      expect(() async => client.getNodeParams(1), throwsStateError);
      expect(() => client.refreshGraph(), throwsStateError);
    });
  });

  group('PwClient.refreshGraph', () {
    test('re-fetches snapshot from native', () async {
      final client = await PwClient.connect(bridge: mockBridge);
      expect(client.graph.nodes, isEmpty);

      mockBridge.snapshotJson = '{"nodes":[{"id":1,"name":"new","state":"idle"}],"ports":[],"links":[],"devices":[]}';
      client.refreshGraph();
      expect(client.graph.nodes.length, 1);

      await client.dispose();
    });
  });
}

