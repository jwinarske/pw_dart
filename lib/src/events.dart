// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'models/models.dart';

/// Sealed event hierarchy for type-safe handling of PipeWire graph changes.
///
/// Events are deserialized from JSON posted by the native C++ layer via
/// `Dart_PostCObject`. Each event carries the data needed to update the
/// [PwGraph] snapshot.
sealed class PwGraphEvent {
  const PwGraphEvent();

  /// Deserialize a [PwGraphEvent] from a JSON map.
  ///
  /// The `type` field determines which subclass to instantiate.
  /// Returns `null` for unknown event types (defensive parsing).
  static PwGraphEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'node_added' => NodeAdded.fromJson(json),
      'node_removed' => NodeRemoved.fromJson(json),
      'node_info_changed' => NodeInfoChanged.fromJson(json),
      'port_added' => PortAdded.fromJson(json),
      'port_removed' => PortRemoved.fromJson(json),
      'link_added' => LinkAdded.fromJson(json),
      'link_removed' => LinkRemoved.fromJson(json),
      'link_state_changed' => LinkStateChanged.fromJson(json),
      'param_changed' => ParamChanged.fromJson(json),
      _ => null, // Unknown event type — skip gracefully
    };
  }
}

/// A new node appeared in the PipeWire graph.
class NodeAdded extends PwGraphEvent {
  final PwNode node;

  const NodeAdded({required this.node});

  factory NodeAdded.fromJson(Map<String, dynamic> json) => NodeAdded(
        node: PwNode.fromJson(json['node'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'type': 'node_added',
        'node': node.toJson(),
      };

  @override
  String toString() => 'NodeAdded(${node.id}, "${node.name}")';
}

/// A node was removed from the PipeWire graph.
class NodeRemoved extends PwGraphEvent {
  final int nodeId;

  const NodeRemoved({required this.nodeId});

  factory NodeRemoved.fromJson(Map<String, dynamic> json) => NodeRemoved(
        nodeId: json['node_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        'type': 'node_removed',
        'node_id': nodeId,
      };

  @override
  String toString() => 'NodeRemoved($nodeId)';
}

/// A node's info (name, state, properties) changed.
class NodeInfoChanged extends PwGraphEvent {
  final PwNode node;

  const NodeInfoChanged({required this.node});

  factory NodeInfoChanged.fromJson(Map<String, dynamic> json) =>
      NodeInfoChanged(
        node: PwNode.fromJson(json['node'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'type': 'node_info_changed',
        'node': node.toJson(),
      };

  @override
  String toString() => 'NodeInfoChanged(${node.id}, "${node.name}")';
}

/// A new port appeared in the PipeWire graph.
class PortAdded extends PwGraphEvent {
  final PwPort port;

  const PortAdded({required this.port});

  factory PortAdded.fromJson(Map<String, dynamic> json) => PortAdded(
        port: PwPort.fromJson(json['port'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'type': 'port_added',
        'port': port.toJson(),
      };

  @override
  String toString() => 'PortAdded(${port.id}, node=${port.nodeId})';
}

/// A port was removed from the PipeWire graph.
class PortRemoved extends PwGraphEvent {
  final int portId;

  const PortRemoved({required this.portId});

  factory PortRemoved.fromJson(Map<String, dynamic> json) => PortRemoved(
        portId: json['port_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        'type': 'port_removed',
        'port_id': portId,
      };

  @override
  String toString() => 'PortRemoved($portId)';
}

/// A new link appeared in the PipeWire graph.
class LinkAdded extends PwGraphEvent {
  final PwLink link;

  const LinkAdded({required this.link});

  factory LinkAdded.fromJson(Map<String, dynamic> json) => LinkAdded(
        link: PwLink.fromJson(json['link'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'type': 'link_added',
        'link': link.toJson(),
      };

  @override
  String toString() => 'LinkAdded(${link.id})';
}

/// A link was removed from the PipeWire graph.
class LinkRemoved extends PwGraphEvent {
  final int linkId;

  const LinkRemoved({required this.linkId});

  factory LinkRemoved.fromJson(Map<String, dynamic> json) => LinkRemoved(
        linkId: json['link_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        'type': 'link_removed',
        'link_id': linkId,
      };

  @override
  String toString() => 'LinkRemoved($linkId)';
}

/// A link's state changed (e.g. negotiating → active).
class LinkStateChanged extends PwGraphEvent {
  final PwLink link;

  const LinkStateChanged({required this.link});

  factory LinkStateChanged.fromJson(Map<String, dynamic> json) =>
      LinkStateChanged(
        link: PwLink.fromJson(json['link'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'type': 'link_state_changed',
        'link': link.toJson(),
      };

  @override
  String toString() => 'LinkStateChanged(${link.id}, ${link.state})';
}

/// A node's parameter value changed.
class ParamChanged extends PwGraphEvent {
  final int nodeId;
  final String key;
  final Object? value;

  const ParamChanged({
    required this.nodeId,
    required this.key,
    this.value,
  });

  factory ParamChanged.fromJson(Map<String, dynamic> json) => ParamChanged(
        nodeId: json['node_id'] as int,
        key: json['key'] as String,
        value: json['value'],
      );

  Map<String, dynamic> toJson() => {
        'type': 'param_changed',
        'node_id': nodeId,
        'key': key,
        if (value != null) 'value': value,
      };

  @override
  String toString() => 'ParamChanged(node=$nodeId, "$key")';
}

