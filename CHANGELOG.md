# Changelog

## 0.1.0

- Native: `connect()` now performs two `pw_core_sync` round-trips so the
  initial `getGraphSnapshot()` returns the fully-populated graph instead
  of a partial view that races with registry binding.
- Examples: add `pw_libcamera` (libcamera SPA video sources, with
  `--watch` for hot-plug), `pw_v4l2` (V4L2 sources with grouped device
  properties, ports, and node-param controls), and `pw_spa_modules`
  (filesystem scan of SPA plugin and PipeWire module search paths,
  grouped by factory namespace).
- Examples: add `graph_viewer/`, a Flutter desktop patchbay with pan /
  zoom, drag-to-link, link delete, node inspector with auto-dismiss,
  search filter, fit-to-view, and a Tokyo Night theme.
- `example/README.md` documents every example and the Fedora-specific
  steps for enabling the libcamera SPA path.
- Relicense copyright headers across the package.

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
