// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

#include "pw_dart_native.h"
#include "client.hpp"
#include "dart_api_dl.h"

#include <pipewire/pipewire.h>
#include <cstring>

using namespace pw_dart;

// === Client Lifecycle ===

PwDartClient* pw_dart_connect(const char* remote_name, int64_t dart_send_port) {
    auto* impl = new (std::nothrow) PwDartClientImpl(dart_send_port);
    if (!impl) return nullptr;

    if (!impl->connect(remote_name)) {
        delete impl;
        return nullptr;
    }

    return reinterpret_cast<PwDartClient*>(impl);
}

void pw_dart_disconnect(PwDartClient* client) {
    if (!client) return;
    auto* impl = reinterpret_cast<PwDartClientImpl*>(client);
    impl->disconnect();
    delete impl;
}

// === Graph Queries ===

char* pw_dart_get_graph_snapshot(PwDartClient* client) {
    if (!client) return nullptr;
    auto* impl = reinterpret_cast<PwDartClientImpl*>(client);
    auto json = impl->get_graph_snapshot();
    char* result = static_cast<char*>(malloc(json.size() + 1));
    if (result) {
        memcpy(result, json.c_str(), json.size() + 1);
    }
    return result;
}

char* pw_dart_get_node_params(PwDartClient* client, uint32_t node_id) {
    if (!client) return nullptr;
    auto* impl = reinterpret_cast<PwDartClientImpl*>(client);
    auto json = impl->get_node_params(node_id);
    char* result = static_cast<char*>(malloc(json.size() + 1));
    if (result) {
        memcpy(result, json.c_str(), json.size() + 1);
    }
    return result;
}

void pw_dart_free_string(char* str) {
    free(str);
}

// === Graph Mutations ===

int32_t pw_dart_create_link(PwDartClient* client,
                            uint32_t output_port_id, uint32_t input_port_id) {
    if (!client) return -1;
    auto* impl = reinterpret_cast<PwDartClientImpl*>(client);
    return impl->create_link(output_port_id, input_port_id);
}

int32_t pw_dart_destroy_link(PwDartClient* client, uint32_t link_id) {
    if (!client) return -1;
    auto* impl = reinterpret_cast<PwDartClientImpl*>(client);
    return impl->destroy_link(link_id);
}

int32_t pw_dart_set_node_param(PwDartClient* client,
                               uint32_t node_id, const char* param_json) {
    if (!client || !param_json) return -1;
    auto* impl = reinterpret_cast<PwDartClientImpl*>(client);
    return impl->set_node_param(node_id, param_json);
}

// === Version Introspection ===

uint32_t pw_dart_get_pw_header_version(void) {
    // PW_MAJOR, PW_MINOR, PW_MICRO are compile-time macros
    return (PW_MAJOR << 16) | (PW_MINOR << 8) | PW_MICRO;
}

uint32_t pw_dart_get_pw_library_version(void) {
    // pw_get_library_version() returns a "major.minor.micro" string at runtime
    const char* ver = pw_get_library_version();
    uint32_t major = 0, minor = 0, micro = 0;
    if (ver) {
        sscanf(ver, "%u.%u.%u", &major, &minor, &micro);
    }
    return (major << 16) | (minor << 8) | micro;
}

