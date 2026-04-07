// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'dart:isolate';

import 'package:pw_dart/pw_dart.dart';

/// Minimal in-memory PwNativeBridge for widget tests.
class FakeBridge extends PwNativeBridge {
  FakeBridge(this._snapshot) : super.forTesting();

  final PwGraph _snapshot;
  bool _connected = false;
  final List<(int, int)> createdLinks = [];
  final List<int> destroyedLinks = [];

  @override
  bool get isConnected => _connected;

  @override
  void connect({String? remoteName, required SendPort sendPort}) {
    _connected = true;
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  PwGraph getGraphSnapshot() => _snapshot;

  @override
  Map<String, PwParam> getNodeParams(int nodeId) => const {};

  @override
  int createLink(int outputPortId, int inputPortId) {
    createdLinks.add((outputPortId, inputPortId));
    return 9999;
  }

  @override
  void destroyLink(int linkId) => destroyedLinks.add(linkId);

  @override
  void setNodeParam(int nodeId, String key, Object value) {}

  @override
  PwVersionInfo getVersionInfo() => const PwVersionInfo(
        headerVersion: (0, 3, 77),
        libraryVersion: (0, 3, 77),
      );
}

PwGraph buildSampleGraph() {
  const src = PwNode(
    id: 1,
    name: 'Test Source',
    mediaClass: 'Audio/Source',
    state: PwNodeState.running,
  );
  const sink = PwNode(
    id: 2,
    name: 'Test Sink',
    mediaClass: 'Audio/Sink',
    state: PwNodeState.running,
  );
  const outPort = PwPort(
    id: 10,
    nodeId: 1,
    name: 'output_FL',
    direction: PwDirection.output,
    mediaType: 'audio/raw',
  );
  const inPort = PwPort(
    id: 20,
    nodeId: 2,
    name: 'playback_FL',
    direction: PwDirection.input,
    mediaType: 'audio/raw',
  );
  return const PwGraph(
    nodes: {1: src, 2: sink},
    ports: {10: outPort, 20: inPort},
    links: {},
    devices: {},
  );
}
