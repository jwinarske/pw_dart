// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:ffi';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../graph.dart';
import '../models/models.dart';
import 'bindings.dart';
import 'serialization.dart';

/// High-level bridge wrapping raw FFI calls with Dart-friendly signatures.
///
/// This is the **mockable boundary** for Dart unit tests. All PwClient
/// operations go through this class, which can be replaced with a
/// [MockPwNativeBridge] in tests.
class PwNativeBridge {
  late final PwDartNativeBindings _bindings;
  Pointer<Void>? _clientHandle;

  PwNativeBridge({PwDartNativeBindings? bindings}) {
    if (bindings != null) {
      _bindings = bindings;
    }
    // If null, _bindings is initialized lazily on first use.
    // Subclasses (mocks) that override all methods never touch _bindings.
  }

  /// Create a bridge with explicit bindings (for production use).
  PwNativeBridge.withBindings(PwDartNativeBindings bindings)
      : _bindings = bindings;

  /// Protected constructor for subclasses (mocks) that don't need bindings.
  PwNativeBridge.forTesting();

  /// Whether we have an active native client handle.
  bool get isConnected => _clientHandle != null && _clientHandle != nullptr;

  /// Connect to PipeWire. The [sendPort] receives JSON event strings.
  @mustCallSuper
  void connect({String? remoteName, required SendPort sendPort}) {
    final nativePort = sendPort.nativePort;
    _clientHandle = _bindings.pwDartConnect(remoteName, nativePort);
    if (_clientHandle == null || _clientHandle == nullptr) {
      throw StateError('Failed to connect to PipeWire');
    }
  }

  /// Disconnect from PipeWire and free resources.
  @mustCallSuper
  void disconnect() {
    if (_clientHandle != null) {
      _bindings.pwDartDisconnect(_clientHandle!);
      _clientHandle = null;
    }
  }

  /// Get the current graph snapshot.
  PwGraph getGraphSnapshot() {
    _ensureConnected();
    final json = _bindings.pwDartGetGraphSnapshot(_clientHandle!);
    return PwGraph.fromJsonString(json);
  }

  /// Get parameters for a node.
  Map<String, PwParam> getNodeParams(int nodeId) {
    _ensureConnected();
    final json = _bindings.pwDartGetNodeParams(_clientHandle!, nodeId);
    return PwEventDeserializer.deserializeParams(json);
  }

  /// Create a link between two ports.
  int createLink(int outputPortId, int inputPortId) {
    _ensureConnected();
    final result = _bindings.pwDartCreateLink(
        _clientHandle!, outputPortId, inputPortId);
    if (result < 0) {
      throw StateError('Failed to create link: error $result');
    }
    return result;
  }

  /// Destroy a link by ID.
  void destroyLink(int linkId) {
    _ensureConnected();
    final result = _bindings.pwDartDestroyLink(_clientHandle!, linkId);
    if (result < 0) {
      throw StateError('Failed to destroy link: error $result');
    }
  }

  /// Set a node parameter.
  void setNodeParam(int nodeId, String key, Object value) {
    _ensureConnected();
    final json = '{"key":"$key","value":"$value"}';
    final result = _bindings.pwDartSetNodeParam(_clientHandle!, nodeId, json);
    if (result < 0) {
      throw StateError('Failed to set param: error $result');
    }
  }

  /// Get PipeWire version info.
  PwVersionInfo getVersionInfo() {
    final headerPacked = _bindings.pwDartGetPwHeaderVersion();
    final libraryPacked = _bindings.pwDartGetPwLibraryVersion();
    return PwVersionInfo(
      headerVersion: _unpackVersion(headerPacked),
      libraryVersion: _unpackVersion(libraryPacked),
    );
  }

  static (int, int, int) _unpackVersion(int packed) => (
        (packed >> 16) & 0xFF,
        (packed >> 8) & 0xFF,
        packed & 0xFF,
      );

  void _ensureConnected() {
    if (!isConnected) {
      throw StateError('Not connected to PipeWire');
    }
  }
}

/// PipeWire version information.
class PwVersionInfo {
  /// Compile-time PipeWire header version (major, minor, micro).
  final (int, int, int) headerVersion;

  /// Runtime PipeWire library version (major, minor, micro).
  final (int, int, int) libraryVersion;

  const PwVersionInfo({
    required this.headerVersion,
    required this.libraryVersion,
  });

  /// Whether the runtime library is compatible with the compiled headers.
  bool get isCompatible {
    final (hMajor, hMinor, _) = headerVersion;
    final (lMajor, lMinor, _) = libraryVersion;
    return lMajor == hMajor && lMinor >= hMinor;
  }

  String get headerVersionString {
    final (major, minor, micro) = headerVersion;
    return '$major.$minor.$micro';
  }

  String get libraryVersionString {
    final (major, minor, micro) = libraryVersion;
    return '$major.$minor.$micro';
  }

  @override
  String toString() =>
      'PwVersionInfo(header=$headerVersionString, lib=$libraryVersionString, compatible=$isCompatible)';
}

