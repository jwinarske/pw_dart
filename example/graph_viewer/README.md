# graph_viewer

A Flutter example app for `pw_dart` — a real-time PipeWire patchbay/graph viewer.

## Features

- Live graph from a connected PipeWire daemon, organized into source / process / sink columns.
- Pan/zoom canvas (`InteractiveViewer` + `CustomPainter`) with bezier links.
- Drag from a port dot to another port to create a link; right-click a link to destroy it.
- Click a node to open the inspector panel (properties + params).
- Search/filter nodes by name or media class.
- Tokyo Night-inspired dark theme — low-contrast, easy on the eyes.

## Run

```sh
cd example/graph_viewer
flutter run -d linux
```

Requires a running PipeWire daemon and the `pw_dart` native bindings built via the
parent package's build hook.

## Design

The visual layout (source-on-left, sinks-on-right, bezier links between port dots)
follows the conventional patchbay idiom shared by tools like Helvum and Catia. No
code from any of those projects was consulted; this is an original Flutter
implementation under Apache 2.0.
