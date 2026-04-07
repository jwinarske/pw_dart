// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "link_manager.hpp"
#include "client.hpp"

#include <pipewire/pipewire.h>

#include <cstring>

namespace pw_dart {

LinkManager::LinkManager(PwDartClientImpl* client)
    : client_(client) {}

LinkManager::~LinkManager() = default;

std::expected<uint32_t, LinkError> LinkManager::create_link(
    uint32_t output_port_id, uint32_t input_port_id) {

    if (!client_ || !client_->is_connected()) {
        return std::unexpected(LinkError::NotConnected);
    }

    auto* core = client_->core();
    if (!core) {
        return std::unexpected(LinkError::NotConnected);
    }

    // Create a link using pw_core_create_object with the link factory
    auto* props = pw_properties_new(
        PW_KEY_LINK_OUTPUT_PORT, std::to_string(output_port_id).c_str(),
        PW_KEY_LINK_INPUT_PORT, std::to_string(input_port_id).c_str(),
        PW_KEY_OBJECT_LINGER, "true",
        nullptr
    );

    if (!props) {
        return std::unexpected(LinkError::CreateFailed);
    }

    auto* proxy = static_cast<pw_proxy*>(
        pw_core_create_object(core,
                              "link-factory",
                              PW_TYPE_INTERFACE_Link,
                              PW_VERSION_LINK,
                              &props->dict,
                              0)
    );

    pw_properties_free(props);

    if (!proxy) {
        return std::unexpected(LinkError::CreateFailed);
    }

    // The link ID will be assigned by PipeWire and arrive via the
    // registry global callback. Return a placeholder — the real ID
    // comes through the event stream.
    uint32_t proxy_id = pw_proxy_get_bound_id(proxy);
    return proxy_id;
}

std::expected<void, LinkError> LinkManager::destroy_link(uint32_t link_id) {
    if (!client_ || !client_->is_connected()) {
        return std::unexpected(LinkError::NotConnected);
    }

    auto* registry = client_->registry();
    if (!registry) {
        return std::unexpected(LinkError::NotConnected);
    }

    // Destroy the link via the registry
    int result = pw_registry_destroy(registry, link_id);
    if (result < 0) {
        return std::unexpected(LinkError::DestroyFailed);
    }

    return {};
}

}  // namespace pw_dart

