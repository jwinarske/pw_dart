// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

/// PipeWire node state.
enum PwNodeState {
  error,
  creating,
  suspended,
  idle,
  running;

  static PwNodeState fromString(String s) => switch (s) {
        'error' => error,
        'creating' => creating,
        'suspended' => suspended,
        'idle' => idle,
        'running' => running,
        _ => error,
      };
}

/// A PipeWire node.
class PwNode {
  /// The global object ID.
  final int id;

  /// Node name from properties.
  final String name;

  /// Media class (e.g. "Audio/Sink", "Audio/Source", "Stream/Output/Audio").
  final String mediaClass;

  /// Current state.
  final PwNodeState state;

  /// All properties as a string map.
  final Map<String, String> properties;

  const PwNode({
    required this.id,
    required this.name,
    required this.mediaClass,
    required this.state,
    this.properties = const {},
  });

  /// Deserialize from a JSON map.
  factory PwNode.fromJson(Map<String, dynamic> json) => PwNode(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        mediaClass: (json['media_class'] as String?) ?? '',
        state: PwNodeState.fromString((json['state'] as String?) ?? 'error'),
        properties: (json['properties'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            const {},
      );

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'media_class': mediaClass,
        'state': state.name,
        'properties': properties,
      };

  PwNode copyWith({
    int? id,
    String? name,
    String? mediaClass,
    PwNodeState? state,
    Map<String, String>? properties,
  }) =>
      PwNode(
        id: id ?? this.id,
        name: name ?? this.name,
        mediaClass: mediaClass ?? this.mediaClass,
        state: state ?? this.state,
        properties: properties ?? this.properties,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PwNode && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PwNode($id, "$name", $mediaClass, $state)';
}

