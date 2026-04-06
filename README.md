# pw_dart

First-class PipeWire bindings for Dart/Flutter.

## Features

- Real-time PipeWire graph monitoring via `Stream<PwGraphEvent>`
- Graph control: create/destroy links, get/set node parameters
- Reactive `PwGraph` snapshot updated on every event
- Version detection and compatibility checking
- Zero-copy architecture via `dart:ffi`

## Requirements

- Linux with PipeWire >= 0.3.40
- Dart SDK >= 3.7.0

## Quick Start

```dart
import 'package:pw_dart/pw_dart.dart';

void main() async {
  final client = await PwClient.connect();

  // Listen to graph events
  client.events.listen((event) {
    print('Event: $event');
  });

  // Access the current graph snapshot
  final graph = client.graph;
  for (final node in graph.nodes.values) {
    print('Node: ${node.name} (${node.mediaClass})');
  }

  await client.dispose();
}
```

## License

Apache 2.0

