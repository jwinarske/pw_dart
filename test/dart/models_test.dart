// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PwNode', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'id': 42,
        'name': 'alsa_output',
        'media_class': 'Audio/Sink',
        'state': 'running',
        'properties': {'node.name': 'alsa_output', 'audio.rate': '48000'},
      };

      final node = PwNode.fromJson(json);
      expect(node.id, 42);
      expect(node.name, 'alsa_output');
      expect(node.mediaClass, 'Audio/Sink');
      expect(node.state, PwNodeState.running);
      expect(node.properties['audio.rate'], '48000');

      final json2 = node.toJson();
      expect(json2['id'], 42);
      expect(json2['name'], 'alsa_output');
    });

    test('equality by id', () {
      final a = PwNode(id: 1, name: 'a', mediaClass: '', state: PwNodeState.idle);
      final b = PwNode(id: 1, name: 'b', mediaClass: '', state: PwNodeState.running);
      final c = PwNode(id: 2, name: 'a', mediaClass: '', state: PwNodeState.idle);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith', () {
      final node = PwNode(id: 1, name: 'old', mediaClass: 'Audio/Sink', state: PwNodeState.idle);
      final updated = node.copyWith(name: 'new', state: PwNodeState.running);
      expect(updated.name, 'new');
      expect(updated.state, PwNodeState.running);
      expect(updated.id, 1);
      expect(updated.mediaClass, 'Audio/Sink');
    });

    test('fromJson with missing fields', () {
      final node = PwNode.fromJson({'id': 1});
      expect(node.name, '');
      expect(node.mediaClass, '');
      expect(node.state, PwNodeState.error);
    });

    test('toString', () {
      final node = PwNode(id: 1, name: 'test', mediaClass: 'Audio/Sink', state: PwNodeState.running);
      expect(node.toString(), contains('PwNode'));
      expect(node.toString(), contains('test'));
    });
  });

  group('PwPort', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'id': 10,
        'node_id': 42,
        'name': 'output_FL',
        'direction': 'output',
        'media_type': 'audio/raw',
        'is_physical': true,
        'is_terminal': false,
        'alias': 'Front Left',
        'properties': {},
      };

      final port = PwPort.fromJson(json);
      expect(port.id, 10);
      expect(port.nodeId, 42);
      expect(port.direction, PwDirection.output);
      expect(port.isPhysical, isTrue);
      expect(port.alias, 'Front Left');

      final json2 = port.toJson();
      expect(json2['node_id'], 42);
    });

    test('direction parsing', () {
      expect(PwDirection.fromString('input'), PwDirection.input);
      expect(PwDirection.fromString('in'), PwDirection.input);
      expect(PwDirection.fromString('output'), PwDirection.output);
      expect(PwDirection.fromString('out'), PwDirection.output);
      expect(PwDirection.fromString('unknown'), PwDirection.input);
    });
  });

  group('PwLink', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'id': 100,
        'output_node_id': 1,
        'output_port_id': 10,
        'input_node_id': 2,
        'input_port_id': 20,
        'state': 'active',
        'error': '',
        'properties': {},
      };

      final link = PwLink.fromJson(json);
      expect(link.id, 100);
      expect(link.outputNodeId, 1);
      expect(link.state, PwLinkState.active);

      final json2 = link.toJson();
      expect(json2['output_port_id'], 10);
    });

    test('state parsing', () {
      for (final state in PwLinkState.values) {
        expect(PwLinkState.fromString(state.name), state);
      }
      expect(PwLinkState.fromString('unknown'), PwLinkState.error);
    });
  });

  group('PwDevice', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'id': 200,
        'name': 'ALSA card',
        'description': 'Built-in Audio',
        'media_class': 'Audio/Device',
        'api': 'alsa',
        'properties': {'device.name': 'hw:0'},
      };

      final device = PwDevice.fromJson(json);
      expect(device.id, 200);
      expect(device.name, 'ALSA card');
      expect(device.api, 'alsa');
    });
  });

  group('PwParam', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'key': 'volume',
        'value': 0.75,
        'type': 'Float',
        'flags': {'readable': true, 'writable': true},
        'min': 0.0,
        'max': 1.0,
      };

      final param = PwParam.fromJson(json);
      expect(param.key, 'volume');
      expect(param.value, 0.75);
      expect(param.type, PwParamType.float_);
      expect(param.flags.writable, isTrue);
      expect(param.min, 0.0);
      expect(param.max, 1.0);
    });

    test('type parsing', () {
      expect(PwParamType.fromString('Int'), PwParamType.int_);
      expect(PwParamType.fromString('Float'), PwParamType.float_);
      expect(PwParamType.fromString('String'), PwParamType.string);
      expect(PwParamType.fromString('Bool'), PwParamType.bool_);
      expect(PwParamType.fromString('xyz'), PwParamType.unknown);
    });

    test('equality by key', () {
      final a = PwParam(key: 'volume', value: 0.5);
      final b = PwParam(key: 'volume', value: 0.8);
      expect(a, equals(b));
    });
  });
}

