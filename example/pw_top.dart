// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// pw_top — live table of PipeWire nodes refreshed periodically.
//
// Usage:
//   dart run example/pw_top.dart [--interval SECONDS]

import 'dart:async';
import 'dart:io';

import 'package:pw_dart/pw_dart.dart';

Future<void> main(List<String> args) async {
  final intervalArg = _flag(args, '--interval');
  final interval = Duration(seconds: int.tryParse(intervalArg ?? '') ?? 1);

  final client = await PwClient.connect();

  void render() {
    // Clear screen + home cursor (ANSI).
    stdout.write('\x1B[2J\x1B[H');
    final g = client.graph;
    stdout.writeln(
      'pw_top — ${g.summary} — '
      '${DateTime.now().toIso8601String().substring(11, 19)}',
    );
    stdout.writeln('');
    stdout.writeln('  ID    STATE       MEDIA-CLASS                  NAME');
    stdout.writeln('  ----  ----------  ---------------------------  ----');
    final sorted =
        g.nodes.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final n in sorted) {
      stdout.writeln(
        '  ${n.id.toString().padRight(4)}  '
        '${n.state.name.padRight(10)}  '
        '${_trim(n.mediaClass, 27).padRight(27)}  '
        '${_trim(n.name, 40)}',
      );
    }
  }

  render();
  final timer = Timer.periodic(interval, (_) => render());

  ProcessSignal.sigint.watch().listen((_) async {
    timer.cancel();
    await client.dispose();
    stdout.writeln('');
    exit(0);
  });
}

String _trim(String s, int n) =>
    s.length <= n ? s : '${s.substring(0, n - 1)}…';

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
