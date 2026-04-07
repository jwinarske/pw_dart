// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// Configure, build, and run the C++ unit tests under test/native/.
//
// Usage:
//   dart run tool/test_native.dart            # build + run all tests
//   dart run tool/test_native.dart --clean    # wipe build dir first
//   dart run tool/test_native.dart -- -R name # forward args to ctest
//
// The build hook intentionally turns BUILD_TESTING off for fast iteration.
// This script enables it explicitly into a sibling build directory so it
// does not interfere with the runtime .so used by `dart test`.

import 'dart:io';

Future<void> main(List<String> args) async {
  final clean = args.contains('--clean');
  final ctestArgs = _argsAfterDoubleDash(args);

  final pkgRoot = Directory.current;
  final srcDir = Directory('${pkgRoot.path}/src');
  final buildDir = Directory('${pkgRoot.path}/src/build-tests');

  if (!srcDir.existsSync()) {
    stderr.writeln('error: run from packages/pw_dart (no src/ here)');
    exit(64);
  }

  if (clean && buildDir.existsSync()) {
    stdout.writeln('cleaning ${buildDir.path}');
    await buildDir.delete(recursive: true);
  }
  await buildDir.create(recursive: true);

  final hasNinja = await _which('ninja');

  if (!File('${buildDir.path}/CMakeCache.txt').existsSync()) {
    await _run('cmake', [
      '-S',
      srcDir.path,
      '-B',
      buildDir.path,
      '-DCMAKE_BUILD_TYPE=Debug',
      '-DBUILD_TESTING=ON',
      if (hasNinja) ...['-G', 'Ninja'],
    ]);
  }

  await _run('cmake', ['--build', buildDir.path, '--parallel']);

  await _run('ctest', [
    '--output-on-failure',
    ...ctestArgs,
  ], workingDirectory: buildDir.path);
}

List<String> _argsAfterDoubleDash(List<String> args) {
  final i = args.indexOf('--');
  return i < 0 ? const [] : args.sublist(i + 1);
}

Future<void> _run(
  String exe,
  List<String> args, {
  String? workingDirectory,
}) async {
  final p = await Process.start(
    exe,
    args,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await p.exitCode;
  if (code != 0) {
    stderr.writeln('$exe ${args.join(' ')} failed with exit code $code');
    exit(code);
  }
}

Future<bool> _which(String exe) async {
  final r = await Process.run('which', [exe]);
  return r.exitCode == 0;
}
