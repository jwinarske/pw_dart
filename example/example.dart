// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// Minimal pw_dart example: connect, print the graph summary, dispose.
//
// For richer examples see the other files in this directory:
//   pw_mon.dart   — live event monitor
//   pw_dump.dart  — JSON snapshot
//   pw_dot.dart   — Graphviz renderer
//   pw_link.dart  — list / create / destroy links
//   pw_top.dart   — periodic node table
//   pw_cli.dart   — interactive REPL

import 'package:pw_dart/pw_dart.dart';

Future<void> main() async {
  final client = await PwClient.connect();
  try {
    print('Connected: ${client.graph.summary}');
    print('PipeWire ${client.getVersion()}');

    for (final node in client.graph.nodes.values) {
      print('  node ${node.id}: ${node.name} (${node.mediaClass})');
    }
  } finally {
    await client.dispose();
  }
}
