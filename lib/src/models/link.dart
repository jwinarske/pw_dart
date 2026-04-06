// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

/// PipeWire link state.
enum PwLinkState {
  error,
  unlinked,
  init,
  negotiating,
  allocating,
  paused,
  active;

  static PwLinkState fromString(String s) => switch (s) {
        'error' => error,
        'unlinked' => unlinked,
        'init' => init,
        'negotiating' => negotiating,
        'allocating' => allocating,
        'paused' => paused,
        'active' => active,
        _ => error,
      };
}

/// A PipeWire link connecting an output port to an input port.
class PwLink {
  /// The global object ID.
  final int id;

  /// Source node ID.
  final int outputNodeId;

  /// Source port ID.
  final int outputPortId;

  /// Destination node ID.
  final int inputNodeId;

  /// Destination port ID.
  final int inputPortId;

  /// Current link state.
  final PwLinkState state;

  /// Error string (non-empty only when state == error).
  final String error;

  /// All properties as a string map.
  final Map<String, String> properties;

  const PwLink({
    required this.id,
    required this.outputNodeId,
    required this.outputPortId,
    required this.inputNodeId,
    required this.inputPortId,
    required this.state,
    this.error = '',
    this.properties = const {},
  });

  factory PwLink.fromJson(Map<String, dynamic> json) => PwLink(
        id: json['id'] as int,
        outputNodeId: json['output_node_id'] as int,
        outputPortId: json['output_port_id'] as int,
        inputNodeId: json['input_node_id'] as int,
        inputPortId: json['input_port_id'] as int,
        state:
            PwLinkState.fromString((json['state'] as String?) ?? 'error'),
        error: (json['error'] as String?) ?? '',
        properties: (json['properties'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'output_node_id': outputNodeId,
        'output_port_id': outputPortId,
        'input_node_id': inputNodeId,
        'input_port_id': inputPortId,
        'state': state.name,
        'error': error,
        'properties': properties,
      };

  PwLink copyWith({
    int? id,
    int? outputNodeId,
    int? outputPortId,
    int? inputNodeId,
    int? inputPortId,
    PwLinkState? state,
    String? error,
    Map<String, String>? properties,
  }) =>
      PwLink(
        id: id ?? this.id,
        outputNodeId: outputNodeId ?? this.outputNodeId,
        outputPortId: outputPortId ?? this.outputPortId,
        inputNodeId: inputNodeId ?? this.inputNodeId,
        inputPortId: inputPortId ?? this.inputPortId,
        state: state ?? this.state,
        error: error ?? this.error,
        properties: properties ?? this.properties,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PwLink && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PwLink($id, $outputNodeId:$outputPortId → $inputNodeId:$inputPortId, $state)';
}

