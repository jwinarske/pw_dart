// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// pw_v4l2 — list V4L2 video sources, their device properties, and any
// controls (brightness, contrast, exposure, etc.) the V4L2 SPA exposes
// as PipeWire node params.
//
// Usage:
//   dart run example/pw_v4l2.dart [--remote NAME] [--all] [--id N]
//
//   --all   include nodes from any device.api (default: only v4l2)
//   --id N  inspect a single node by id

import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final remote = _flag(args, '--remote');
  final all = args.contains('--all');
  final filterId = int.tryParse(_flag(args, '--id') ?? '');

  final client = await PwClient.connect(remoteName: remote);
  try {
    final cameras =
        client.graph.nodes.values
            .where((n) => n.mediaClass.startsWith('Video/Source'))
            .where((n) => all || n.properties['device.api'] == 'v4l2')
            .where((n) => filterId == null || n.id == filterId)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    if (cameras.isEmpty) {
      stderr.writeln(
        filterId != null
            ? 'No Video/Source node with id $filterId.'
            : 'No V4L2 video sources found. '
                'Try `--all` to include other APIs (e.g. libcamera).',
      );
      return;
    }

    for (final node in cameras) {
      await _printNode(client, node);
      stdout.writeln('');
    }
  } finally {
    await client.dispose();
  }
}

Future<void> _printNode(PwClient client, PwNode node) async {
  stdout.writeln('━━ id ${node.id}  ${node.name}');
  stdout.writeln('   media.class : ${node.mediaClass}');
  stdout.writeln('   state       : ${node.state.name}');

  // Group V4L2-relevant properties for readability.
  const propGroups = <String, List<String>>{
    'Device': [
      'node.description',
      'device.api',
      'device.product.name',
      'device.vendor.name',
      'device.serial',
      'device.bus',
      'device.bus-path',
      'device.subsystem',
    ],
    'V4L2': [
      'api.v4l2.path',
      'api.v4l2.cap.driver',
      'api.v4l2.cap.card',
      'api.v4l2.cap.bus_info',
      'api.v4l2.cap.version',
      'api.v4l2.cap.capabilities',
      'api.v4l2.cap.device-caps',
    ],
    'Media': ['media.role', 'media.class', 'priority.session'],
  };

  for (final entry in propGroups.entries) {
    final present =
        entry.value
            .where(
              (k) =>
                  node.properties.containsKey(k) &&
                  node.properties[k]!.isNotEmpty,
            )
            .toList();
    if (present.isEmpty) continue;
    stdout.writeln('   [${entry.key}]');
    for (final k in present) {
      stdout.writeln('     ${k.padRight(26)} ${node.properties[k]}');
    }
  }

  // Ports.
  final ports = client.graph.portsForNode(node.id);
  if (ports.isNotEmpty) {
    stdout.writeln('   [Ports]');
    for (final p in ports) {
      stdout.writeln(
        '     ${p.id.toString().padLeft(4)}  ${p.direction.name.padRight(6)} '
        '${p.name.padRight(14)} ${p.mediaType}',
      );
    }
  }

  // Controls — V4L2 controls surface as node params (brightness, gain,
  // exposure, white-balance, focus, zoom, ...).
  Map<String, PwParam> params;
  try {
    params = await client.getNodeParams(node.id);
  } catch (e) {
    stdout.writeln('   [Controls] (failed to query: $e)');
    return;
  }

  if (params.isEmpty) {
    stdout.writeln(
      '   [Controls] (none reported — node may be suspended; '
      'try opening the camera in another app first)',
    );
    return;
  }

  stdout.writeln('   [Controls]');
  final keys = params.keys.toList()..sort();
  for (final k in keys) {
    final p = params[k]!;
    final flagStr = p.flags.writable ? 'rw' : 'r-';
    final range =
        (p.min != null && p.max != null) ? '  [${p.min}…${p.max}]' : '';
    final def = p.defaultValue != null ? '  default=${p.defaultValue}' : '';
    stdout.writeln(
      '     $flagStr  ${p.key.padRight(26)} = ${p.value}'
      '  (${p.type.toJsonString()})$range$def',
    );
  }
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
