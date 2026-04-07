// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// pw_dart_native.h — extern "C" interface consumed by dart:ffi
//
// This is the stable ABI between the Dart FFI layer and the C++23
// native implementation. All PipeWire interactions are hidden behind
// this interface.

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PwDartClient PwDartClient;

// === Client Lifecycle ===

/// Connect to PipeWire and start the event loop thread.
/// @param remote_name PipeWire remote name (NULL for default).
/// @param dart_send_port Dart SendPort for posting events.
/// @return Opaque client handle, or NULL on failure.
PwDartClient* pw_dart_connect(const char* remote_name, int64_t dart_send_port);

/// Disconnect and free all resources. Blocks until the PW thread exits.
void pw_dart_disconnect(PwDartClient* client);

// === Graph Queries (returns JSON, caller must free with pw_dart_free_string) ===

/// Get a JSON snapshot of the entire PipeWire graph.
/// @return JSON string (caller must free), or NULL on error.
char* pw_dart_get_graph_snapshot(PwDartClient* client);

/// Get JSON-encoded parameters for a node.
/// @return JSON string (caller must free), or NULL on error.
char* pw_dart_get_node_params(PwDartClient* client, uint32_t node_id);

/// Free a string returned by pw_dart_get_graph_snapshot or pw_dart_get_node_params.
void pw_dart_free_string(char* str);

// === Graph Mutations ===

/// Create a link between two ports.
/// @return 0 on success, negative error code on failure.
int32_t pw_dart_create_link(PwDartClient* client,
                            uint32_t output_port_id, uint32_t input_port_id);

/// Destroy a link by its global ID.
/// @return 0 on success, negative error code on failure.
int32_t pw_dart_destroy_link(PwDartClient* client, uint32_t link_id);

/// Set a node parameter. param_json is a JSON object with "key" and "value".
/// @return 0 on success, negative error code on failure.
int32_t pw_dart_set_node_param(PwDartClient* client,
                               uint32_t node_id, const char* param_json);

// === Version Introspection ===

/// Get the PipeWire header version (compile-time).
/// Returns packed version: (major << 16) | (minor << 8) | micro.
uint32_t pw_dart_get_pw_header_version(void);

/// Get the PipeWire library version (runtime).
/// Returns packed version: (major << 16) | (minor << 8) | micro.
uint32_t pw_dart_get_pw_library_version(void);

#ifdef __cplusplus
}
#endif