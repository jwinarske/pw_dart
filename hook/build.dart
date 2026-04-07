// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// Native assets build hook for pw_dart.
//
// Conforms to the `package:hooks` protocol: parses the BuildInput passed
// by the Dart tooling, drives CMake to compile libpw_dart_native.so, then
// declares the resulting shared library as a CodeAsset so it can be
// loaded via `DynamicLibrary.open('package:pw_dart/src/ffi/bindings.dart')`
// in dev runs and bundled automatically by `flutter build`.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    if (Platform.environment.containsKey('SKIP_NATIVE_BUILD')) {
      stderr.writeln('SKIP_NATIVE_BUILD set — skipping native build.');
      return;
    }

    final srcDir = input.packageRoot.resolve('src/').toFilePath();
    final buildDir = input.outputDirectory.resolve('cmake/').toFilePath();

    await Directory(buildDir).create(recursive: true);

    final hasNinja = await _which('ninja');

    if (!File('${buildDir}CMakeCache.txt').existsSync()) {
      await _run('cmake', [
        '-S', srcDir,
        '-B', buildDir,
        '-DCMAKE_BUILD_TYPE=Release',
        '-DBUILD_TESTING=OFF',
        if (hasNinja) ...['-G', 'Ninja'],
      ]);
    }

    await _run('cmake', ['--build', buildDir, '--parallel']);

    final libFile = File('${buildDir}libpw_dart_native.so');
    if (!libFile.existsSync()) {
      throw StateError('libpw_dart_native.so not found at ${libFile.path}');
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/ffi/bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: libFile.uri,
      ),
    );

    // Re-run the hook whenever any C/C++ source under src/ changes.
    final srcDirectory = Directory(srcDir);
    if (srcDirectory.existsSync()) {
      for (final entity in srcDirectory.listSync(recursive: true)) {
        if (entity is File &&
            (entity.path.endsWith('.cpp') ||
                entity.path.endsWith('.hpp') ||
                entity.path.endsWith('.h') ||
                entity.path.endsWith('.c') ||
                entity.path.endsWith('CMakeLists.txt'))) {
          output.dependencies.add(entity.uri);
        }
      }
    }

    stderr.writeln('pw_dart_native built: ${libFile.path}');
  });
}

Future<void> _run(String exe, List<String> args) async {
  final p = await Process.start(
    exe,
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await p.exitCode;
  if (code != 0) {
    throw ProcessException(exe, args, 'exit code $code', code);
  }
}

Future<bool> _which(String exe) async {
  final r = await Process.run('which', [exe]);
  return r.exitCode == 0;
}
