// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:async';
import 'dart:isolate';

import 'events.dart';
import 'ffi/native_bridge.dart';
import 'ffi/serialization.dart';
import 'graph.dart';
import 'models/models.dart';
import 'version.dart';

/// Connect to PipeWire and receive real-time graph updates.
///
/// This is the primary Dart-side entry point for the `pw_dart` package.
/// It manages the native client connection, deserializes events from
/// the PipeWire thread, maintains a reactive graph snapshot, and
/// exposes graph mutation operations.
///
/// ```dart
/// final client = await PwClient.connect();
/// client.events.listen((event) => print(event));
/// print(client.graph.summary);
/// await client.dispose();
/// ```
class PwClient {
  final PwNativeBridge _bridge;
  final ReceivePort _receivePort;
  final StreamController<PwGraphEvent> _eventController;
  PwGraph _graph;
  bool _disposed = false;

  PwClient._({
    required PwNativeBridge bridge,
    required ReceivePort receivePort,
    required StreamController<PwGraphEvent> eventController,
    required PwGraph initialGraph,
  })  : _bridge = bridge,
        _receivePort = receivePort,
        _eventController = eventController,
        _graph = initialGraph;

  /// Connect to PipeWire and start receiving graph events.
  ///
  /// [remoteName] optionally specifies a PipeWire remote name.
  /// [bridge] optionally provides a custom (or mock) native bridge.
  static Future<PwClient> connect({
    String? remoteName,
    PwNativeBridge? bridge,
  }) async {
    final effectiveBridge = bridge ?? PwNativeBridge();
    final receivePort = ReceivePort();
    final eventController = StreamController<PwGraphEvent>.broadcast();

    // Connect to PipeWire
    effectiveBridge.connect(
      remoteName: remoteName,
      sendPort: receivePort.sendPort,
    );

    // Get initial graph snapshot
    final initialGraph = effectiveBridge.getGraphSnapshot();

    final client = PwClient._(
      bridge: effectiveBridge,
      receivePort: receivePort,
      eventController: eventController,
      initialGraph: initialGraph,
    );

    // Start listening for native events
    client._startListening();

    return client;
  }

  /// The current graph snapshot. Updated on every event.
  PwGraph get graph => _graph;

  /// Stream of graph events. New subscribers get events from the
  /// point of subscription (broadcast stream).
  Stream<PwGraphEvent> get events => _eventController.stream;

  /// Whether this client has been disposed.
  bool get isDisposed => _disposed;

  /// Create a link between an output port and an input port.
  Future<PwLink> createLink(int outputPortId, int inputPortId) async {
    _ensureNotDisposed();
    _bridge.createLink(outputPortId, inputPortId);

    // Wait for the LinkAdded event to arrive with the actual link info
    final event = await events
        .where((e) =>
            e is LinkAdded &&
            e.link.outputPortId == outputPortId &&
            e.link.inputPortId == inputPortId)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException(
          'Timed out waiting for link creation confirmation');
    });

    return (event as LinkAdded).link;
  }

  /// Destroy a link by its global ID.
  Future<void> destroyLink(int linkId) async {
    _ensureNotDisposed();
    _bridge.destroyLink(linkId);
  }

  /// Set a parameter on a node.
  Future<void> setNodeParam(int nodeId, String paramKey, Object value) async {
    _ensureNotDisposed();
    _bridge.setNodeParam(nodeId, paramKey, value);
  }

  /// Get all parameters for a node.
  Future<Map<String, PwParam>> getNodeParams(int nodeId) async {
    _ensureNotDisposed();
    return _bridge.getNodeParams(nodeId);
  }

  /// Get PipeWire version information.
  PwVersion getVersion() {
    _ensureNotDisposed();
    return PwVersion(_bridge.getVersionInfo());
  }

  /// Refresh the graph snapshot from native.
  void refreshGraph() {
    _ensureNotDisposed();
    _graph = _bridge.getGraphSnapshot();
  }

  /// Disconnect and free all resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _receivePort.close();
    await _eventController.close();
    _bridge.disconnect();
  }

  // ─── Private ───

  void _startListening() {
    _receivePort.listen((dynamic message) {
      if (_disposed) return;

      if (message is String) {
        final event = PwEventDeserializer.deserializeEvent(message);
        if (event != null) {
          // Update graph snapshot
          _graph = _graph.applyEvent(event);
          // Emit event
          if (!_eventController.isClosed) {
            _eventController.add(event);
          }
        }
      }
    });
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PwClient has been disposed');
    }
  }
}

