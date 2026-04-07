# Changelog

## 0.0.1

Initial release.

- Connect to a PipeWire daemon and stream graph events as a typed
  `Stream<PwGraphEvent>` (nodes, ports, links, devices, params).
- Reactive `PwGraph` snapshot maintained from registry events.
- Graph mutation: create / destroy links, get / set node parameters.
- PipeWire version detection and compile-vs-runtime compatibility check.
- Six command-line examples (`pw_mon`, `pw_dump`, `pw_dot`, `pw_link`,
  `pw_top`, `pw_cli`) demonstrating the API.
- Native build hook (`package:hooks` 1.0) drives CMake to compile the
  C++23 backend and declares the resulting `.so` as a `CodeAsset`.
- Linux-only (`platforms: linux`).
