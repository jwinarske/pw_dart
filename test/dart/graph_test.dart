// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PwGraph', () {
    test('empty graph', () {
      const graph = PwGraph.empty();
      expect(graph.nodes, isEmpty);
      expect(graph.ports, isEmpty);
      expect(graph.links, isEmpty);
      expect(graph.devices, isEmpty);
      expect(graph.summary, '0 nodes, 0 ports, 0 links, 0 devices');
    });

    test('fromJson with all object types', () {
      final json = {
        'nodes': [
          {
            'id': 1,
            'name': 'node1',
            'media_class': 'Audio/Sink',
            'state': 'running',
          },
          {
            'id': 2,
            'name': 'node2',
            'media_class': 'Audio/Source',
            'state': 'idle',
          },
        ],
        'ports': [
          {'id': 10, 'node_id': 1, 'name': 'FL', 'direction': 'input'},
          {'id': 11, 'node_id': 1, 'name': 'FR', 'direction': 'input'},
        ],
        'links': [
          {
            'id': 100,
            'output_node_id': 2,
            'output_port_id': 20,
            'input_node_id': 1,
            'input_port_id': 10,
            'state': 'active',
          },
        ],
        'devices': [
          {'id': 200, 'name': 'ALSA'},
        ],
      };

      final graph = PwGraph.fromJson(json);
      expect(graph.nodes.length, 2);
      expect(graph.ports.length, 2);
      expect(graph.links.length, 1);
      expect(graph.devices.length, 1);
    });

    test('fromJsonString', () {
      const jsonStr =
          '{"nodes":[{"id":1,"name":"n","state":"idle"}],"ports":[],"links":[],"devices":[]}';
      final graph = PwGraph.fromJsonString(jsonStr);
      expect(graph.nodes.length, 1);
      expect(graph.nodes[1]!.name, 'n');
    });

    test('applyEvent NodeAdded', () {
      const graph = PwGraph.empty();
      final node = PwNode(
        id: 1,
        name: 'test',
        mediaClass: 'Audio/Sink',
        state: PwNodeState.idle,
      );
      final updated = graph.applyEvent(NodeAdded(node: node));

      expect(updated.nodes.length, 1);
      expect(updated.nodes[1]!.name, 'test');
      // Original unchanged
      expect(graph.nodes, isEmpty);
    });

    test('applyEvent NodeRemoved', () {
      final graph = PwGraph(
        nodes: {
          1: PwNode(
            id: 1,
            name: 'test',
            mediaClass: '',
            state: PwNodeState.idle,
          ),
        },
      );
      final updated = graph.applyEvent(const NodeRemoved(nodeId: 1));
      expect(updated.nodes, isEmpty);
    });

    test('applyEvent NodeInfoChanged updates existing node', () {
      final graph = PwGraph(
        nodes: {
          1: PwNode(
            id: 1,
            name: 'old',
            mediaClass: 'Audio/Sink',
            state: PwNodeState.idle,
          ),
        },
      );
      final updatedNode = PwNode(
        id: 1,
        name: 'new',
        mediaClass: 'Audio/Sink',
        state: PwNodeState.running,
      );
      final updated = graph.applyEvent(NodeInfoChanged(node: updatedNode));

      expect(updated.nodes[1]!.name, 'new');
      expect(updated.nodes[1]!.state, PwNodeState.running);
    });

    test('applyEvent PortAdded', () {
      const graph = PwGraph.empty();
      final port = PwPort(
        id: 10,
        nodeId: 1,
        name: 'FL',
        direction: PwDirection.output,
      );
      final updated = graph.applyEvent(PortAdded(port: port));
      expect(updated.ports.length, 1);
    });

    test('applyEvent PortRemoved', () {
      final graph = PwGraph(
        ports: {
          10: PwPort(
            id: 10,
            nodeId: 1,
            name: 'FL',
            direction: PwDirection.output,
          ),
        },
      );
      final updated = graph.applyEvent(const PortRemoved(portId: 10));
      expect(updated.ports, isEmpty);
    });

    test('applyEvent LinkAdded', () {
      const graph = PwGraph.empty();
      final link = PwLink(
        id: 100,
        outputNodeId: 1,
        outputPortId: 10,
        inputNodeId: 2,
        inputPortId: 20,
        state: PwLinkState.active,
      );
      final updated = graph.applyEvent(LinkAdded(link: link));
      expect(updated.links.length, 1);
    });

    test('applyEvent LinkRemoved', () {
      final graph = PwGraph(
        links: {
          100: PwLink(
            id: 100,
            outputNodeId: 1,
            outputPortId: 10,
            inputNodeId: 2,
            inputPortId: 20,
            state: PwLinkState.active,
          ),
        },
      );
      final updated = graph.applyEvent(const LinkRemoved(linkId: 100));
      expect(updated.links, isEmpty);
    });

    test('applyEvent LinkStateChanged', () {
      final graph = PwGraph(
        links: {
          100: PwLink(
            id: 100,
            outputNodeId: 1,
            outputPortId: 10,
            inputNodeId: 2,
            inputPortId: 20,
            state: PwLinkState.init,
          ),
        },
      );
      final updatedLink = PwLink(
        id: 100,
        outputNodeId: 1,
        outputPortId: 10,
        inputNodeId: 2,
        inputPortId: 20,
        state: PwLinkState.active,
      );
      final updated = graph.applyEvent(LinkStateChanged(link: updatedLink));
      expect(updated.links[100]!.state, PwLinkState.active);
    });

    test('applyEvent ParamChanged does not modify graph topology', () {
      final graph = PwGraph(
        nodes: {
          1: PwNode(
            id: 1,
            name: 'test',
            mediaClass: '',
            state: PwNodeState.idle,
          ),
        },
      );
      final updated = graph.applyEvent(
        const ParamChanged(nodeId: 1, key: 'vol'),
      );
      expect(identical(updated, graph), isTrue);
    });

    test('portsForNode', () {
      final graph = PwGraph(
        nodes: {
          1: PwNode(id: 1, name: 'n', mediaClass: '', state: PwNodeState.idle),
        },
        ports: {
          10: PwPort(
            id: 10,
            nodeId: 1,
            name: 'a',
            direction: PwDirection.output,
          ),
          11: PwPort(
            id: 11,
            nodeId: 1,
            name: 'b',
            direction: PwDirection.output,
          ),
          20: PwPort(
            id: 20,
            nodeId: 2,
            name: 'c',
            direction: PwDirection.input,
          ),
        },
      );
      final ports = graph.portsForNode(1);
      expect(ports.length, 2);
      expect(ports.map((p) => p.id).toSet(), {10, 11});
    });

    test('linksForNode', () {
      final graph = PwGraph(
        ports: {
          10: PwPort(
            id: 10,
            nodeId: 1,
            name: 'a',
            direction: PwDirection.output,
          ),
          20: PwPort(
            id: 20,
            nodeId: 2,
            name: 'b',
            direction: PwDirection.input,
          ),
        },
        links: {
          100: PwLink(
            id: 100,
            outputNodeId: 1,
            outputPortId: 10,
            inputNodeId: 2,
            inputPortId: 20,
            state: PwLinkState.active,
          ),
          101: PwLink(
            id: 101,
            outputNodeId: 3,
            outputPortId: 30,
            inputNodeId: 4,
            inputPortId: 40,
            state: PwLinkState.active,
          ),
        },
      );
      final links = graph.linksForNode(1);
      expect(links.length, 1);
      expect(links.first.id, 100);
    });

    test('toJson round-trip', () {
      final graph = PwGraph(
        nodes: {
          1: PwNode(
            id: 1,
            name: 'n',
            mediaClass: 'Audio/Sink',
            state: PwNodeState.running,
          ),
        },
        ports: {
          10: PwPort(
            id: 10,
            nodeId: 1,
            name: 'p',
            direction: PwDirection.output,
          ),
        },
        links: {
          100: PwLink(
            id: 100,
            outputNodeId: 1,
            outputPortId: 10,
            inputNodeId: 2,
            inputPortId: 20,
            state: PwLinkState.active,
          ),
        },
        devices: {200: PwDevice(id: 200, name: 'd')},
      );
      final json = graph.toJson();
      final graph2 = PwGraph.fromJson(json);
      expect(graph2.nodes.length, 1);
      expect(graph2.ports.length, 1);
      expect(graph2.links.length, 1);
      expect(graph2.devices.length, 1);
    });
  });
}
