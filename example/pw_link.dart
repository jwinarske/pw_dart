// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// pw_link — list, create, or destroy PipeWire links.
//
// Usage:
//   dart run example/pw_link.dart list
//   dart run example/pw_link.dart create <out_port_id> <in_port_id>
//   dart run example/pw_link.dart destroy <link_id>

import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(64);
  }

  final client = await PwClient.connect();
  try {
    switch (args.first) {
      case 'list':
        for (final link in client.graph.links.values) {
          stdout.writeln(
            '${link.id}\t'
            '${link.outputNodeId}:${link.outputPortId} -> '
            '${link.inputNodeId}:${link.inputPortId}\t'
            '[${link.state.name}]',
          );
        }
      case 'create':
        if (args.length < 3) {
          _usage();
          exit(64);
        }
        final out = int.parse(args[1]);
        final inp = int.parse(args[2]);
        final link = await client.createLink(out, inp);
        stdout.writeln('created link ${link.id}: ${link.state.name}');
      case 'destroy':
        if (args.length < 2) {
          _usage();
          exit(64);
        }
        final id = int.parse(args[1]);
        await client.destroyLink(id);
        stdout.writeln('destroyed link $id');
      default:
        _usage();
        exit(64);
    }
  } finally {
    await client.dispose();
  }
}

void _usage() {
  stderr.writeln('usage: pw_link list');
  stderr.writeln('       pw_link create <out_port_id> <in_port_id>');
  stderr.writeln('       pw_link destroy <link_id>');
}
