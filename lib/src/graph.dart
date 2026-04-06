// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:convert';

import 'events.dart';
import 'models/models.dart';

/// Reactive snapshot of the PipeWire graph.
///
/// Maintains maps of all known nodes, ports, links, and devices.
/// Updated by applying [PwGraphEvent]s. Each mutation returns a new
/// [PwGraph] instance (immutable snapshots).
class PwGraph {
  /// All known nodes, keyed by global ID.
  final Map<int, PwNode> nodes;

  /// All known ports, keyed by global ID.
  final Map<int, PwPort> ports;

  /// All known links, keyed by global ID.
  final Map<int, PwLink> links;

  /// All known devices, keyed by global ID.
  final Map<int, PwDevice> devices;

  const PwGraph({
    this.nodes = const {},
    this.ports = const {},
    this.links = const {},
    this.devices = const {},
  });

  /// Create an empty graph.
  const PwGraph.empty()
      : nodes = const {},
        ports = const {},
        links = const {},
        devices = const {};

  /// Deserialize a graph from a JSON snapshot string.
  factory PwGraph.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return PwGraph.fromJson(json);
  }

  /// Deserialize a graph from a JSON map.
  factory PwGraph.fromJson(Map<String, dynamic> json) {
    final nodes = <int, PwNode>{};
    final ports = <int, PwPort>{};
    final links = <int, PwLink>{};
    final devices = <int, PwDevice>{};

    if (json['nodes'] case final List<dynamic> nodeList) {
      for (final n in nodeList) {
        final node = PwNode.fromJson(n as Map<String, dynamic>);
        nodes[node.id] = node;
      }
    }

    if (json['ports'] case final List<dynamic> portList) {
      for (final p in portList) {
        final port = PwPort.fromJson(p as Map<String, dynamic>);
        ports[port.id] = port;
      }
    }

    if (json['links'] case final List<dynamic> linkList) {
      for (final l in linkList) {
        final link = PwLink.fromJson(l as Map<String, dynamic>);
        links[link.id] = link;
      }
    }

    if (json['devices'] case final List<dynamic> deviceList) {
      for (final d in deviceList) {
        final device = PwDevice.fromJson(d as Map<String, dynamic>);
        devices[device.id] = device;
      }
    }

    return PwGraph(
      nodes: Map.unmodifiable(nodes),
      ports: Map.unmodifiable(ports),
      links: Map.unmodifiable(links),
      devices: Map.unmodifiable(devices),
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
        'nodes': nodes.values.map((n) => n.toJson()).toList(),
        'ports': ports.values.map((p) => p.toJson()).toList(),
        'links': links.values.map((l) => l.toJson()).toList(),
        'devices': devices.values.map((d) => d.toJson()).toList(),
      };

  /// Apply a [PwGraphEvent] and return the new graph snapshot.
  PwGraph applyEvent(PwGraphEvent event) => switch (event) {
        NodeAdded(:final node) => _withNode(node),
        NodeRemoved(:final nodeId) => _withoutNode(nodeId),
        NodeInfoChanged(:final node) => _withNode(node),
        PortAdded(:final port) => _withPort(port),
        PortRemoved(:final portId) => _withoutPort(portId),
        LinkAdded(:final link) => _withLink(link),
        LinkRemoved(:final linkId) => _withoutLink(linkId),
        LinkStateChanged(:final link) => _withLink(link),
        ParamChanged() => this, // Params don't change graph topology
      };

  /// Get all ports belonging to a node.
  List<PwPort> portsForNode(int nodeId) =>
      ports.values.where((p) => p.nodeId == nodeId).toList();

  /// Get all links connected to a node (via its ports).
  List<PwLink> linksForNode(int nodeId) {
    final nodePorts = portsForNode(nodeId).map((p) => p.id).toSet();
    return links.values
        .where((l) =>
            nodePorts.contains(l.outputPortId) ||
            nodePorts.contains(l.inputPortId))
        .toList();
  }

  /// Summary counts.
  String get summary =>
      '${nodes.length} nodes, ${ports.length} ports, '
      '${links.length} links, ${devices.length} devices';

  // --- Private mutation helpers (return new snapshots) ---

  PwGraph _withNode(PwNode node) => PwGraph(
        nodes: Map.unmodifiable({...nodes, node.id: node}),
        ports: ports,
        links: links,
        devices: devices,
      );

  PwGraph _withoutNode(int nodeId) => PwGraph(
        nodes: Map.unmodifiable(
            Map.of(nodes)..remove(nodeId)),
        ports: ports,
        links: links,
        devices: devices,
      );

  PwGraph _withPort(PwPort port) => PwGraph(
        nodes: nodes,
        ports: Map.unmodifiable({...ports, port.id: port}),
        links: links,
        devices: devices,
      );

  PwGraph _withoutPort(int portId) => PwGraph(
        nodes: nodes,
        ports: Map.unmodifiable(
            Map.of(ports)..remove(portId)),
        links: links,
        devices: devices,
      );

  PwGraph _withLink(PwLink link) => PwGraph(
        nodes: nodes,
        ports: ports,
        links: Map.unmodifiable({...links, link.id: link}),
        devices: devices,
      );

  PwGraph _withoutLink(int linkId) => PwGraph(
        nodes: nodes,
        ports: ports,
        links: Map.unmodifiable(
            Map.of(links)..remove(linkId)),
        devices: devices,
      );

  @override
  String toString() => 'PwGraph($summary)';
}

