/// PipeWire bindings for Dart/Flutter.
///
/// Provides first-class PipeWire integration via C++23 native code
/// communicated through `dart:ffi`.
library;

// Models
export 'src/models/models.dart';

// Events
export 'src/events.dart';

// Graph
export 'src/graph.dart';

// FFI bridge
export 'src/ffi/native_bridge.dart' show PwNativeBridge, PwVersionInfo;
export 'src/ffi/serialization.dart' show PwEventDeserializer;

// Version
export 'src/version.dart';

// Client
export 'src/client.dart';
