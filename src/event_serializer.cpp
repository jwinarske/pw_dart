// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "event_serializer.hpp"

// This file exists for compilation units that need the event serializer
// linked in. The actual implementations are in the header as inline functions
// since they use Glaze template machinery. This .cpp ensures the header
// compiles cleanly as a standalone translation unit.

namespace pw_dart {

// Force instantiation of template functions to verify they compile.
[[maybe_unused]] static void verify_compilation_() {
  NodeAddedEvent e;
  GraphEvent ev = e;
  [[maybe_unused]] auto json = serialize_event(ev);

  GraphSnapshot snap;
  [[maybe_unused]] auto snap_json = serialize_snapshot(snap);
  [[maybe_unused]] auto snap2 = deserialize_snapshot(snap_json);
}

}  // namespace pw_dart
