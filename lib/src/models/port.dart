// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

/// Port direction.
enum PwDirection {
  input,
  output;

  static PwDirection fromString(String s) => switch (s) {
        'input' || 'in' => input,
        'output' || 'out' => output,
        _ => input,
      };
}

/// A PipeWire port.
class PwPort {
  /// The global object ID.
  final int id;

  /// The owning node ID.
  final int nodeId;

  /// Port name.
  final String name;

  /// Direction (input/output).
  final PwDirection direction;

  /// Media type / format (e.g. "audio/raw", "video/raw", "application/control").
  final String mediaType;

  /// Physical port flag.
  final bool isPhysical;

  /// Terminal port flag.
  final bool isTerminal;

  /// Port alias.
  final String alias;

  /// All properties as a string map.
  final Map<String, String> properties;

  const PwPort({
    required this.id,
    required this.nodeId,
    required this.name,
    required this.direction,
    this.mediaType = '',
    this.isPhysical = false,
    this.isTerminal = false,
    this.alias = '',
    this.properties = const {},
  });

  factory PwPort.fromJson(Map<String, dynamic> json) => PwPort(
        id: json['id'] as int,
        nodeId: json['node_id'] as int,
        name: (json['name'] as String?) ?? '',
        direction:
            PwDirection.fromString((json['direction'] as String?) ?? 'input'),
        mediaType: (json['media_type'] as String?) ?? '',
        isPhysical: (json['is_physical'] as bool?) ?? false,
        isTerminal: (json['is_terminal'] as bool?) ?? false,
        alias: (json['alias'] as String?) ?? '',
        properties: (json['properties'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'node_id': nodeId,
        'name': name,
        'direction': direction.name,
        'media_type': mediaType,
        'is_physical': isPhysical,
        'is_terminal': isTerminal,
        'alias': alias,
        'properties': properties,
      };

  PwPort copyWith({
    int? id,
    int? nodeId,
    String? name,
    PwDirection? direction,
    String? mediaType,
    bool? isPhysical,
    bool? isTerminal,
    String? alias,
    Map<String, String>? properties,
  }) =>
      PwPort(
        id: id ?? this.id,
        nodeId: nodeId ?? this.nodeId,
        name: name ?? this.name,
        direction: direction ?? this.direction,
        mediaType: mediaType ?? this.mediaType,
        isPhysical: isPhysical ?? this.isPhysical,
        isTerminal: isTerminal ?? this.isTerminal,
        alias: alias ?? this.alias,
        properties: properties ?? this.properties,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PwPort && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PwPort($id, node=$nodeId, "$name", ${direction.name})';
}

