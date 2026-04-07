// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:pw_dart/pw_dart.dart';
import 'package:pw_dart/src/ffi/native_bridge.dart';

/// Mock implementation of [PwNativeBridge] for unit testing.
///
/// Simulates PipeWire behavior without requiring the native library
/// or a PipeWire daemon. Allows tests to inject events, configure
/// snapshot responses, and verify method calls.
class MockPwNativeBridge extends PwNativeBridge {
  bool connectCalled = false;
  bool disconnectCalled = false;
  String? lastRemoteName;
  SendPort? capturedSendPort;

  // Configurable responses
  String snapshotJson =
      '{"nodes":[],"ports":[],"links":[],"devices":[]}';
  String paramsJson = '[]';
  int createLinkResult = 0;
  int destroyLinkResult = 0;
  int setParamResult = 0;

  // Call tracking
  final List<String> calls = [];
  final List<(int, int)> createdLinks = [];
  final List<int> destroyedLinks = [];
  final List<(int, String, Object)> setParams = [];
  final List<int> queriedParams = [];

  // Version info
  (int, int, int) headerVer = (0, 3, 77);
  (int, int, int) libraryVer = (0, 3, 77);

  MockPwNativeBridge() : super.forTesting();

  @override
  bool get isConnected => connectCalled && !disconnectCalled;

  @override
  void connect({String? remoteName, required SendPort sendPort}) {
    connectCalled = true;
    lastRemoteName = remoteName;
    capturedSendPort = sendPort;
    calls.add('connect');
  }

  @override
  void disconnect() {
    disconnectCalled = true;
    calls.add('disconnect');
  }

  @override
  PwGraph getGraphSnapshot() {
    calls.add('getGraphSnapshot');
    return PwGraph.fromJsonString(snapshotJson);
  }

  @override
  Map<String, PwParam> getNodeParams(int nodeId) {
    calls.add('getNodeParams($nodeId)');
    queriedParams.add(nodeId);
    return PwEventDeserializer.deserializeParams(paramsJson);
  }

  @override
  int createLink(int outputPortId, int inputPortId) {
    calls.add('createLink($outputPortId, $inputPortId)');
    createdLinks.add((outputPortId, inputPortId));
    return createLinkResult;
  }

  @override
  void destroyLink(int linkId) {
    calls.add('destroyLink($linkId)');
    destroyedLinks.add(linkId);
  }

  @override
  void setNodeParam(int nodeId, String key, Object value) {
    calls.add('setNodeParam($nodeId, $key, $value)');
    setParams.add((nodeId, key, value));
  }

  @override
  PwVersionInfo getVersionInfo() {
    calls.add('getVersionInfo');
    return PwVersionInfo(
      headerVersion: headerVer,
      libraryVersion: libraryVer,
    );
  }

  /// Simulate sending an event from native to Dart.
  void simulateEvent(Map<String, dynamic> eventJson) {
    capturedSendPort?.send(jsonEncode(eventJson));
  }

  /// Simulate sending a raw string event.
  void simulateRawEvent(String json) {
    capturedSendPort?.send(json);
  }
}


