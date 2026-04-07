// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// pw_spa_modules — list SPA plugin shared objects available to PipeWire
// and the PipeWire modules currently loaded by the daemon.
//
// SPA plugins live on disk under one of:
//   - $SPA_PLUGIN_DIR (if set)
//   - /usr/lib64/spa-0.2  (Fedora, RHEL, openSUSE)
//   - /usr/lib/spa-0.2    (Debian, Ubuntu, Arch)
//   - /usr/lib/x86_64-linux-gnu/spa-0.2  (Debian multiarch)
//
// Each subdirectory groups one factory namespace (alsa, bluez5, audioconvert,
// v4l2, libcamera, audiotestsrc, …) and contains one or more `.so` files
// that PipeWire dlopens on demand.
//
// PipeWire *modules* (libpipewire-module-*.so) are a different thing —
// they live under e.g. /usr/lib64/pipewire-0.3 and are listed alongside
// the SPA plugins below for completeness.
//
// Usage:
//   dart run example/pw_spa_modules.dart [--paths]
//
//   --paths   also print every search path inspected (including missing).

import 'dart:io';

void main(List<String> args) {
  final showPaths = args.contains('--paths');

  final spaDirs = _existingDirs([
    Platform.environment['SPA_PLUGIN_DIR'],
    '/usr/lib64/spa-0.2',
    '/usr/lib/spa-0.2',
    '/usr/lib/x86_64-linux-gnu/spa-0.2',
    '/usr/local/lib64/spa-0.2',
    '/usr/local/lib/spa-0.2',
  ]);

  final pwModuleDirs = _existingDirs([
    Platform.environment['PIPEWIRE_MODULE_DIR'],
    '/usr/lib64/pipewire-0.3',
    '/usr/lib/pipewire-0.3',
    '/usr/lib/x86_64-linux-gnu/pipewire-0.3',
    '/usr/local/lib64/pipewire-0.3',
    '/usr/local/lib/pipewire-0.3',
  ]);

  if (showPaths) {
    stdout.writeln('SPA search paths:');
    for (final p in [
      Platform.environment['SPA_PLUGIN_DIR'],
      '/usr/lib64/spa-0.2',
      '/usr/lib/spa-0.2',
      '/usr/lib/x86_64-linux-gnu/spa-0.2',
      '/usr/local/lib64/spa-0.2',
      '/usr/local/lib/spa-0.2',
    ]) {
      if (p == null) continue;
      final exists = Directory(p).existsSync();
      stdout.writeln('  ${exists ? "✓" : "·"} $p');
    }
    stdout.writeln('');
  }

  if (spaDirs.isEmpty) {
    stderr.writeln('No SPA plugin directories found.');
    exitCode = 1;
    return;
  }

  for (final dir in spaDirs) {
    _printSpaDir(dir);
  }

  if (pwModuleDirs.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('━━ PipeWire modules ${'━' * 50}');
    for (final dir in pwModuleDirs) {
      _printPwModuleDir(dir);
    }
  }
}

List<String> _existingDirs(Iterable<String?> candidates) {
  final seen = <String>{};
  final out = <String>[];
  for (final c in candidates) {
    if (c == null || c.isEmpty) continue;
    if (!seen.add(c)) continue;
    if (Directory(c).existsSync()) out.add(c);
  }
  return out;
}

void _printSpaDir(String root) {
  stdout.writeln('━━ SPA plugins in $root ${'━' * 10}');

  final children = Directory(root).listSync(followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));

  // Each immediate subdirectory is a factory namespace; loose .so files
  // (rare) are listed under "(root)".
  final byNamespace = <String, List<File>>{};
  for (final ent in children) {
    if (ent is Directory) {
      final ns = ent.path.split(Platform.pathSeparator).last;
      byNamespace[ns] =
          ent
              .listSync(followLinks: false)
              .whereType<File>()
              .where((f) => f.path.endsWith('.so'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
    } else if (ent is File && ent.path.endsWith('.so')) {
      byNamespace.putIfAbsent('(root)', () => []).add(ent);
    }
  }

  if (byNamespace.isEmpty) {
    stdout.writeln('  (empty)');
    return;
  }

  final namespaces = byNamespace.keys.toList()..sort();
  for (final ns in namespaces) {
    final files = byNamespace[ns]!;
    stdout.writeln('');
    stdout.writeln('  [$ns]  ${_describeNamespace(ns)}');
    for (final f in files) {
      _printSoFile(f, indent: '    ');
    }
  }
  stdout.writeln('');
}

void _printPwModuleDir(String root) {
  stdout.writeln('');
  stdout.writeln('  $root');
  final files =
      Directory(root)
          .listSync(followLinks: false, recursive: false)
          .whereType<File>()
          .where((f) {
            final n = f.path.split(Platform.pathSeparator).last;
            return n.startsWith('libpipewire-module-') && n.endsWith('.so');
          })
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stdout.writeln('    (none)');
    return;
  }
  for (final f in files) {
    _printSoFile(f, indent: '    ', stripPrefix: 'libpipewire-module-');
  }
}

void _printSoFile(File f, {required String indent, String? stripPrefix}) {
  final stat = f.statSync();
  var name = f.path.split(Platform.pathSeparator).last;
  if (stripPrefix != null && name.startsWith(stripPrefix)) {
    name = name.substring(stripPrefix.length);
  }
  if (name.endsWith('.so')) name = name.substring(0, name.length - 3);
  final size = _humanSize(stat.size);
  final mtime = stat.modified.toIso8601String().split('T').first;
  stdout.writeln('$indent${name.padRight(34)} $size  $mtime');
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '${bytes}B'.padLeft(7);
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}K'.padLeft(7);
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M'.padLeft(7);
}

String _describeNamespace(String ns) => switch (ns) {
  'alsa' => 'ALSA PCM/sequencer/UCM',
  'audioconvert' => 'channel/format conversion, resampling, mixing',
  'audiomixer' => 'audio mixing',
  'audiotestsrc' => 'sine/noise/silence test source',
  'avb' => 'IEEE 1722 Audio Video Bridging',
  'bluez5' => 'BlueZ A2DP / HFP / HSP / LDAC / aptX',
  'control' => 'control bus',
  'dbus' => 'DBus integration',
  'jack' => 'JACK passthrough',
  'libcamera' => 'libcamera ISP-aware video sources',
  'support' => 'helper plugins (loop, dbus, system, …)',
  'v4l2' => 'Video4Linux2 cameras',
  'videoconvert' => 'video format conversion',
  'videotestsrc' => 'test video source',
  'vulkan' => 'Vulkan compute',
  '(root)' => 'loose plugin files',
  _ => '',
};
