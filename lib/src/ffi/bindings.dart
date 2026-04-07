// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Raw dart:ffi bindings to libpw_dart_native.so.
///
/// Hand-written for Phase 1's small API surface. Can be replaced
/// with ffigen-generated bindings later.
class PwDartNativeBindings {
  final DynamicLibrary _lib;

  PwDartNativeBindings._(this._lib);

  /// Load the native library.
  factory PwDartNativeBindings({String? libraryPath}) {
    final path = libraryPath ?? _defaultLibraryPath();
    final lib = DynamicLibrary.open(path);
    return PwDartNativeBindings._(lib);
  }

  static String _defaultLibraryPath() {
    // Search order: local build, system install
    final candidates = [
      'src/build/libpw_dart_native.so',
      'build/libpw_dart_native.so',
      '/usr/local/lib/libpw_dart_native.so',
      'libpw_dart_native.so',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return 'libpw_dart_native.so'; // Let dlopen search LD_LIBRARY_PATH
  }

  // === Client Lifecycle ===

  late final _pwDartConnect = _lib.lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>, Int64),
      Pointer<Void> Function(Pointer<Utf8>, int)>('pw_dart_connect');

  late final _pwDartDisconnect = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pw_dart_disconnect');

  /// Connect to PipeWire.
  Pointer<Void> pwDartConnect(String? remoteName, int dartSendPort) {
    final namePtr = remoteName != null
        ? remoteName.toNativeUtf8()
        : nullptr;
    try {
      return _pwDartConnect(namePtr ?? Pointer<Utf8>.fromAddress(0), dartSendPort);
    } finally {
      if (namePtr != null) calloc.free(namePtr);
    }
  }

  /// Disconnect from PipeWire.
  void pwDartDisconnect(Pointer<Void> client) => _pwDartDisconnect(client);

  // === Graph Queries ===

  late final _pwDartGetGraphSnapshot = _lib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Void>),
      Pointer<Utf8> Function(Pointer<Void>)>('pw_dart_get_graph_snapshot');

  late final _pwDartGetNodeParams = _lib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Void>, Uint32),
      Pointer<Utf8> Function(Pointer<Void>, int)>('pw_dart_get_node_params');

  late final _pwDartFreeString = _lib.lookupFunction<
      Void Function(Pointer<Utf8>),
      void Function(Pointer<Utf8>)>('pw_dart_free_string');

  /// Get graph snapshot as JSON. Caller must not free the returned string.
  String pwDartGetGraphSnapshot(Pointer<Void> client) {
    final ptr = _pwDartGetGraphSnapshot(client);
    if (ptr == nullptr) return '{"nodes":[],"ports":[],"links":[],"devices":[]}';
    try {
      return ptr.toDartString();
    } finally {
      _pwDartFreeString(ptr);
    }
  }

  /// Get node params as JSON.
  String pwDartGetNodeParams(Pointer<Void> client, int nodeId) {
    final ptr = _pwDartGetNodeParams(client, nodeId);
    if (ptr == nullptr) return '[]';
    try {
      return ptr.toDartString();
    } finally {
      _pwDartFreeString(ptr);
    }
  }

  // === Graph Mutations ===

  late final _pwDartCreateLink = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Uint32),
      int Function(Pointer<Void>, int, int)>('pw_dart_create_link');

  late final _pwDartDestroyLink = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)>('pw_dart_destroy_link');

  late final _pwDartSetNodeParam = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Pointer<Utf8>),
      int Function(Pointer<Void>, int, Pointer<Utf8>)>('pw_dart_set_node_param');

  /// Create a link.
  int pwDartCreateLink(Pointer<Void> client, int outputPortId, int inputPortId) =>
      _pwDartCreateLink(client, outputPortId, inputPortId);

  /// Destroy a link.
  int pwDartDestroyLink(Pointer<Void> client, int linkId) =>
      _pwDartDestroyLink(client, linkId);

  /// Set a node parameter.
  int pwDartSetNodeParam(Pointer<Void> client, int nodeId, String paramJson) {
    final jsonPtr = paramJson.toNativeUtf8();
    try {
      return _pwDartSetNodeParam(client, nodeId, jsonPtr);
    } finally {
      calloc.free(jsonPtr);
    }
  }

  // === Version ===

  late final _pwDartGetPwHeaderVersion = _lib.lookupFunction<
      Uint32 Function(),
      int Function()>('pw_dart_get_pw_header_version');

  late final _pwDartGetPwLibraryVersion = _lib.lookupFunction<
      Uint32 Function(),
      int Function()>('pw_dart_get_pw_library_version');

  /// Get PipeWire header version (packed).
  int pwDartGetPwHeaderVersion() => _pwDartGetPwHeaderVersion();

  /// Get PipeWire library version (packed).
  int pwDartGetPwLibraryVersion() => _pwDartGetPwLibraryVersion();
}

