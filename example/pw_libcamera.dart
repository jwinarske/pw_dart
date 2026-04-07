// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// pw_libcamera — list video sources exposed by the libcamera SPA plugin.
//
// PipeWire's libcamera SPA (spa-libcamera) exposes cameras as
// `Video/Source` nodes whose `device.api` property is `libcamera`.
// This example connects to PipeWire, filters the graph for those nodes,
// prints their info and ports, and then watches for hot-plug events.
//
// Usage:
//   dart run example/pw_libcamera.dart [--remote NAME] [--watch]

import 'dart:async';
import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final remote = _flag(args, '--remote');
  final watch = args.contains('--watch');

  final client = await PwClient.connect(remoteName: remote);

  try {
    final cameras = _libcameraNodes(client.graph);
    if (cameras.isEmpty) {
      stderr.writeln(
        'No libcamera nodes found.\n'
        'Make sure spa-libcamera is installed and at least one camera is '
        'available (try `pw-cli ls Node | grep libcamera`).',
      );
    } else {
      stdout.writeln('Found ${cameras.length} libcamera node(s):\n');
      for (final node in cameras) {
        _printCamera(client.graph, node);
      }
    }

    if (!watch) return;

    stdout.writeln('\nWatching for libcamera hot-plug events. Ctrl+C to exit.');
    final sub = client.events.listen((event) {
      switch (event) {
        case NodeAdded(:final node) when _isLibcamera(node):
          stdout.writeln('+ added   ${node.id}  ${node.name}');
        case NodeRemoved(:final nodeId):
          stdout.writeln('- removed $nodeId');
        case NodeInfoChanged(:final node) when _isLibcamera(node):
          stdout.writeln('~ changed ${node.id}  state=${node.state.name}');
        default:
      }
    });

    // Park forever until SIGINT.
    final done = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) => done.complete());
    await done.future;
    await sub.cancel();
  } finally {
    await client.dispose();
  }
}

List<PwNode> _libcameraNodes(PwGraph graph) =>
    graph.nodes.values.where(_isLibcamera).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

bool _isLibcamera(PwNode node) {
  if (node.properties['device.api'] == 'libcamera') return true;
  if (node.properties['factory.name']?.contains('libcamera') ?? false) {
    return true;
  }
  // Fall back to media class for nodes that don't expose device.api on the
  // node itself (sometimes only the parent device carries it).
  return node.mediaClass.startsWith('Video/Source') &&
      (node.name.contains('libcamera') || node.name.contains('libcam'));
}

void _printCamera(PwGraph graph, PwNode node) {
  stdout.writeln('  id ${node.id}  ${node.name}');
  stdout.writeln('    media.class : ${node.mediaClass}');
  stdout.writeln('    state       : ${node.state.name}');
  for (final key in const [
    'node.description',
    'device.api',
    'device.product.name',
    'device.vendor.name',
    'api.libcamera.location',
    'api.libcamera.rotation',
  ]) {
    final v = node.properties[key];
    if (v != null && v.isNotEmpty) {
      stdout.writeln('    ${key.padRight(12)}: $v');
    }
  }
  final ports = graph.portsForNode(node.id);
  if (ports.isNotEmpty) {
    stdout.writeln('    ports:');
    for (final p in ports) {
      stdout.writeln(
        '      ${p.id}  ${p.direction.name.padRight(6)} ${p.name}'
        '  (${p.mediaType})',
      );
    }
  }
  stdout.writeln('');
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
