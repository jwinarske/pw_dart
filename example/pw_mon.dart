// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// pw_mon — stream live PipeWire graph events to stdout.
//
// Usage:
//   dart run example/pw_mon.dart [--remote NAME]

import 'dart:async';
import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final remote = _flag(args, '--remote');

  final client = await PwClient.connect(remoteName: remote);
  stdout.writeln('connected: ${client.graph.summary}');
  stdout.writeln('-- streaming events (Ctrl-C to quit) --');

  final sub = client.events.listen((event) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    stdout.writeln('[$ts] $event');
  });

  ProcessSignal.sigint.watch().listen((_) async {
    await sub.cancel();
    await client.dispose();
    exit(0);
  });
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
