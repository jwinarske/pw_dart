// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// pw_dot — render the PipeWire graph as a Graphviz dot file.
//
// Usage:
//   dart run example/pw_dot.dart [--remote NAME] > graph.dot
//   dot -Tsvg graph.dot -o graph.svg

import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final remote = _flag(args, '--remote');

  final client = await PwClient.connect(remoteName: remote);
  try {
    final g = client.graph;
    final out = StringBuffer()
      ..writeln('digraph pipewire {')
      ..writeln('  rankdir=LR;')
      ..writeln('  node [shape=record, fontname="Helvetica", fontsize=10];');

    for (final node in g.nodes.values) {
      final inputs = g.portsForNode(node.id).where((p) => p.direction == PwDirection.input).toList();
      final outputs = g.portsForNode(node.id).where((p) => p.direction == PwDirection.output).toList();
      final inLabels = inputs.map((p) => '<i${p.id}> ${_esc(p.name)}').join('|');
      final outLabels = outputs.map((p) => '<o${p.id}> ${_esc(p.name)}').join('|');
      final body = [
        if (inLabels.isNotEmpty) '{$inLabels}',
        '${_esc(node.name)}\\n[${_esc(node.mediaClass)}]',
        if (outLabels.isNotEmpty) '{$outLabels}',
      ].join('|');
      out.writeln('  n${node.id} [label="{$body}"];');
    }

    for (final link in g.links.values) {
      out.writeln('  n${link.outputNodeId}:o${link.outputPortId} -> '
          'n${link.inputNodeId}:i${link.inputPortId};');
    }

    out.writeln('}');
    stdout.write(out.toString());
  } finally {
    await client.dispose();
  }
}

String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('|', '\\|').replaceAll('<', '\\<').replaceAll('>', '\\>').replaceAll('{', '\\{').replaceAll('}', '\\}');

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
