// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

/// A PipeWire device.
class PwDevice {
  /// The global object ID.
  final int id;

  /// Device name.
  final String name;

  /// Device description.
  final String description;

  /// Media class (e.g. "Audio/Device").
  final String mediaClass;

  /// API type (e.g. "alsa", "v4l2", "bluez5").
  final String api;

  /// All properties as a string map.
  final Map<String, String> properties;

  const PwDevice({
    required this.id,
    required this.name,
    this.description = '',
    this.mediaClass = '',
    this.api = '',
    this.properties = const {},
  });

  factory PwDevice.fromJson(Map<String, dynamic> json) => PwDevice(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        mediaClass: (json['media_class'] as String?) ?? '',
        api: (json['api'] as String?) ?? '',
        properties: (json['properties'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'media_class': mediaClass,
        'api': api,
        'properties': properties,
      };

  PwDevice copyWith({
    int? id,
    String? name,
    String? description,
    String? mediaClass,
    String? api,
    Map<String, String>? properties,
  }) =>
      PwDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        mediaClass: mediaClass ?? this.mediaClass,
        api: api ?? this.api,
        properties: properties ?? this.properties,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PwDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PwDevice($id, "$name", $mediaClass)';
}

