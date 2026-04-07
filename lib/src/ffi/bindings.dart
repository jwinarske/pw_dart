// Copyright 2026 Joel Winarske
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
  ///
  /// Pass [libraryPath] to override the search. By default, looks for the
  /// `.so` produced by `hook/build.dart` under `.dart_tool/hooks_runner/`,
  /// then falls back to a local CMake build, then to the system loader.
  factory PwDartNativeBindings({String? libraryPath}) {
    final path = libraryPath ?? _defaultLibraryPath();
    return PwDartNativeBindings._(DynamicLibrary.open(path));
  }

  static const _libName = 'libpw_dart_native.so';

  static String _defaultLibraryPath() {
    // 1. Most recent build produced by the package:hooks build hook. Walk up
    //    from CWD looking for a `.dart_tool/hooks_runner/shared/pw_dart`
    //    directory (works whether you run from the package root, the workspace
    //    root, or anywhere in between).
    final fromHook = _findInHooksRunner();
    if (fromHook != null) return fromHook;

    // 2. Common ad-hoc CMake build locations (e.g. when invoking cmake by hand
    //    during native development).
    const candidates = [
      'src/build/$_libName',
      'build/$_libName',
      '/usr/local/lib/$_libName',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }

    // 3. Last resort: let dlopen search LD_LIBRARY_PATH / system dirs.
    return _libName;
  }

  static String? _findInHooksRunner() {
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final root = Directory(
        '${dir.path}/.dart_tool/hooks_runner/shared/pw_dart/build',
      );
      if (root.existsSync()) {
        File? newest;
        DateTime newestTime = DateTime.fromMillisecondsSinceEpoch(0);
        for (final entity in root.listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('/$_libName')) {
            final mtime = entity.statSync().modified;
            if (mtime.isAfter(newestTime)) {
              newest = entity;
              newestTime = mtime;
            }
          }
        }
        if (newest != null) return newest.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  // === Client Lifecycle ===

  late final _pwDartConnect = _lib.lookupFunction<
    Pointer<Void> Function(Pointer<Utf8>, Int64),
    Pointer<Void> Function(Pointer<Utf8>, int)
  >('pw_dart_connect');

  late final _pwDartDisconnect = _lib.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)
  >('pw_dart_disconnect');

  /// Connect to PipeWire.
  Pointer<Void> pwDartConnect(String? remoteName, int dartSendPort) {
    final namePtr = remoteName != null ? remoteName.toNativeUtf8() : nullptr;
    try {
      return _pwDartConnect(namePtr.cast<Utf8>(), dartSendPort);
    } finally {
      if (remoteName != null) calloc.free(namePtr);
    }
  }

  /// Disconnect from PipeWire.
  void pwDartDisconnect(Pointer<Void> client) => _pwDartDisconnect(client);

  // === Graph Queries ===

  late final _pwDartGetGraphSnapshot = _lib.lookupFunction<
    Pointer<Utf8> Function(Pointer<Void>),
    Pointer<Utf8> Function(Pointer<Void>)
  >('pw_dart_get_graph_snapshot');

  late final _pwDartGetNodeParams = _lib.lookupFunction<
    Pointer<Utf8> Function(Pointer<Void>, Uint32),
    Pointer<Utf8> Function(Pointer<Void>, int)
  >('pw_dart_get_node_params');

  late final _pwDartFreeString = _lib.lookupFunction<
    Void Function(Pointer<Utf8>),
    void Function(Pointer<Utf8>)
  >('pw_dart_free_string');

  /// Get graph snapshot as JSON. Caller must not free the returned string.
  String pwDartGetGraphSnapshot(Pointer<Void> client) {
    final ptr = _pwDartGetGraphSnapshot(client);
    if (ptr == nullptr) {
      return '{"nodes":[],"ports":[],"links":[],"devices":[]}';
    }
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
    int Function(Pointer<Void>, int, int)
  >('pw_dart_create_link');

  late final _pwDartDestroyLink = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Uint32),
    int Function(Pointer<Void>, int)
  >('pw_dart_destroy_link');

  late final _pwDartSetNodeParam = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Uint32, Pointer<Utf8>),
    int Function(Pointer<Void>, int, Pointer<Utf8>)
  >('pw_dart_set_node_param');

  /// Create a link.
  int pwDartCreateLink(
    Pointer<Void> client,
    int outputPortId,
    int inputPortId,
  ) => _pwDartCreateLink(client, outputPortId, inputPortId);

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

  late final _pwDartGetPwHeaderVersion = _lib
      .lookupFunction<Uint32 Function(), int Function()>(
        'pw_dart_get_pw_header_version',
      );

  late final _pwDartGetPwLibraryVersion = _lib
      .lookupFunction<Uint32 Function(), int Function()>(
        'pw_dart_get_pw_library_version',
      );

  /// Get PipeWire header version (packed).
  int pwDartGetPwHeaderVersion() => _pwDartGetPwHeaderVersion();

  /// Get PipeWire library version (packed).
  int pwDartGetPwLibraryVersion() => _pwDartGetPwLibraryVersion();
}
