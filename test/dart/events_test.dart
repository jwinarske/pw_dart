// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PwGraphEvent.fromJson', () {
    test('deserializes NodeAdded', () {
      final json = {
        'type': 'node_added',
        'node': {
          'id': 1,
          'name': 'test_node',
          'media_class': 'Audio/Sink',
          'state': 'idle',
        }
      };
      final event = PwGraphEvent.fromJson(json);
      expect(event, isA<NodeAdded>());
      final nodeAdded = event as NodeAdded;
      expect(nodeAdded.node.id, 1);
      expect(nodeAdded.node.name, 'test_node');
    });

    test('deserializes NodeRemoved', () {
      final event = PwGraphEvent.fromJson({
        'type': 'node_removed',
        'node_id': 42,
      });
      expect(event, isA<NodeRemoved>());
      expect((event as NodeRemoved).nodeId, 42);
    });

    test('deserializes NodeInfoChanged', () {
      final event = PwGraphEvent.fromJson({
        'type': 'node_info_changed',
        'node': {'id': 1, 'name': 'updated', 'state': 'running'},
      });
      expect(event, isA<NodeInfoChanged>());
      expect((event as NodeInfoChanged).node.state, PwNodeState.running);
    });

    test('deserializes PortAdded', () {
      final event = PwGraphEvent.fromJson({
        'type': 'port_added',
        'port': {'id': 10, 'node_id': 1, 'name': 'FL', 'direction': 'output'},
      });
      expect(event, isA<PortAdded>());
      final portAdded = event as PortAdded;
      expect(portAdded.port.direction, PwDirection.output);
    });

    test('deserializes PortRemoved', () {
      final event = PwGraphEvent.fromJson({
        'type': 'port_removed',
        'port_id': 10,
      });
      expect(event, isA<PortRemoved>());
      expect((event as PortRemoved).portId, 10);
    });

    test('deserializes LinkAdded', () {
      final event = PwGraphEvent.fromJson({
        'type': 'link_added',
        'link': {
          'id': 100,
          'output_node_id': 1,
          'output_port_id': 10,
          'input_node_id': 2,
          'input_port_id': 20,
          'state': 'active',
        },
      });
      expect(event, isA<LinkAdded>());
      expect((event as LinkAdded).link.state, PwLinkState.active);
    });

    test('deserializes LinkRemoved', () {
      final event = PwGraphEvent.fromJson({
        'type': 'link_removed',
        'link_id': 100,
      });
      expect(event, isA<LinkRemoved>());
    });

    test('deserializes LinkStateChanged', () {
      final event = PwGraphEvent.fromJson({
        'type': 'link_state_changed',
        'link': {
          'id': 100,
          'output_node_id': 1,
          'output_port_id': 10,
          'input_node_id': 2,
          'input_port_id': 20,
          'state': 'paused',
        },
      });
      expect(event, isA<LinkStateChanged>());
      expect((event as LinkStateChanged).link.state, PwLinkState.paused);
    });

    test('deserializes ParamChanged', () {
      final event = PwGraphEvent.fromJson({
        'type': 'param_changed',
        'node_id': 5,
        'key': 'volume',
        'value': 0.8,
      });
      expect(event, isA<ParamChanged>());
      final pc = event as ParamChanged;
      expect(pc.nodeId, 5);
      expect(pc.key, 'volume');
    });

    test('returns null for unknown event type', () {
      final event = PwGraphEvent.fromJson({'type': 'unknown_event'});
      expect(event, isNull);
    });

    test('returns null for missing type field', () {
      final event = PwGraphEvent.fromJson({'data': 'something'});
      expect(event, isNull);
    });
  });

  group('Event toJson', () {
    test('NodeAdded toJson', () {
      final event = NodeAdded(
        node: PwNode(id: 1, name: 'test', mediaClass: 'Audio/Sink', state: PwNodeState.idle),
      );
      final json = event.toJson();
      expect(json['type'], 'node_added');
      expect((json['node'] as Map)['id'], 1);
    });

    test('LinkRemoved toJson', () {
      final event = LinkRemoved(linkId: 42);
      final json = event.toJson();
      expect(json['type'], 'link_removed');
      expect(json['link_id'], 42);
    });

    test('ParamChanged toJson', () {
      final event = ParamChanged(nodeId: 5, key: 'volume', value: 0.8);
      final json = event.toJson();
      expect(json['type'], 'param_changed');
      expect(json['node_id'], 5);
      expect(json['key'], 'volume');
    });
  });

  group('Event toString', () {
    test('all events have meaningful toString', () {
      final events = <PwGraphEvent>[
        NodeAdded(node: PwNode(id: 1, name: 'n', mediaClass: '', state: PwNodeState.idle)),
        NodeRemoved(nodeId: 1),
        NodeInfoChanged(node: PwNode(id: 1, name: 'n', mediaClass: '', state: PwNodeState.idle)),
        PortAdded(port: PwPort(id: 1, nodeId: 1, name: 'p', direction: PwDirection.output)),
        PortRemoved(portId: 1),
        LinkAdded(link: PwLink(id: 1, outputNodeId: 1, outputPortId: 2, inputNodeId: 3, inputPortId: 4, state: PwLinkState.active)),
        LinkRemoved(linkId: 1),
        LinkStateChanged(link: PwLink(id: 1, outputNodeId: 1, outputPortId: 2, inputNodeId: 3, inputPortId: 4, state: PwLinkState.paused)),
        ParamChanged(nodeId: 1, key: 'k'),
      ];

      for (final event in events) {
        expect(event.toString(), isNotEmpty);
        expect(event.toString().length, greaterThan(5));
      }
    });
  });
}

