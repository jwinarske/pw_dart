// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// pw_dump — print the current PipeWire graph snapshot as JSON.
//
// Usage:
//   dart run example/pw_dump.dart [--remote NAME] [--pretty]

import 'dart:convert';
import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final remote = _flag(args, '--remote');
  final pretty = args.contains('--pretty');

  final client = await PwClient.connect(remoteName: remote);
  try {
    final json = client.graph.toJson();
    final encoder = pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    stdout.writeln(encoder.convert(json));
  } finally {
    await client.dispose();
  }
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
