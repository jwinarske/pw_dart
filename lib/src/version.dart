// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'ffi/native_bridge.dart';

export 'ffi/native_bridge.dart' show PwVersionInfo;

/// PipeWire version detection and compatibility checking.
///
/// Wraps the native version introspection functions to provide
/// compile-time vs runtime version comparison.
class PwVersion {
  final PwVersionInfo _info;

  const PwVersion(this._info);

  /// The PipeWire header version used at compile time.
  (int, int, int) get headerVersion => _info.headerVersion;

  /// The PipeWire library version available at runtime.
  (int, int, int) get libraryVersion => _info.libraryVersion;

  /// Whether the runtime library is compatible with compiled headers.
  ///
  /// True if the major versions match and the runtime minor version
  /// is >= the header minor version.
  bool get isCompatible => _info.isCompatible;

  /// Human-readable header version string.
  String get headerVersionString => _info.headerVersionString;

  /// Human-readable library version string.
  String get libraryVersionString => _info.libraryVersionString;

  /// Minimum supported PipeWire version.
  static const minVersion = (0, 3, 40);

  /// Whether the runtime version meets the minimum requirement.
  bool get meetsMinimumVersion {
    final (major, minor, micro) = libraryVersion;
    final (minMajor, minMinor, minMicro) = minVersion;
    if (major != minMajor) return major > minMajor;
    if (minor != minMinor) return minor > minMinor;
    return micro >= minMicro;
  }

  @override
  String toString() =>
      'PwVersion('
      'header=$headerVersionString, '
      'lib=$libraryVersionString, '
      'compatible=$isCompatible, '
      'meetsMin=$meetsMinimumVersion)';
}
