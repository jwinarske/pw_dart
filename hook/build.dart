/// Build hook for pw_dart native code.
///
/// Uses CMake to build libpw_dart_native.so and bundles it with the package.
library;

import 'dart:io';

// This build hook is invoked by `native_assets_cli` during `dart run` / `flutter build`.
// It compiles the C++23 native library using CMake.
void main(List<String> args) async {
  final packageRoot = Directory.current.path;
  final srcDir = '$packageRoot/src';
  final buildDir = '$packageRoot/src/build';

  // Create build directory
  await Directory(buildDir).create(recursive: true);

  // Configure
  final configResult = await Process.run(
    'cmake',
    [
      '-S', srcDir,
      '-B', buildDir,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DBUILD_TESTING=OFF',
    ],
  );
  if (configResult.exitCode != 0) {
    stderr.writeln('CMake configure failed:\n${configResult.stderr}');
    exit(1);
  }

  // Build
  final buildResult = await Process.run(
    'cmake',
    ['--build', buildDir, '--parallel'],
  );
  if (buildResult.exitCode != 0) {
    stderr.writeln('CMake build failed:\n${buildResult.stderr}');
    exit(1);
  }

  stdout.writeln('pw_dart_native built successfully.');
}

