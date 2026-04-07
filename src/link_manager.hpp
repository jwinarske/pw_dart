// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// LinkManager — creates and destroys PipeWire links.

#pragma once

#include <cstdint>
#include <expected>
#include <string>

namespace pw_dart {

class PwDartClientImpl;

/// Error codes for link operations.
enum class LinkError {
    NotConnected,
    InvalidPort,
    CreateFailed,
    DestroyFailed,
    NotFound,
};

/// Manages PipeWire link creation and destruction.
class LinkManager {
public:
    explicit LinkManager(PwDartClientImpl* client);
    ~LinkManager();

    // Non-copyable
    LinkManager(const LinkManager&) = delete;
    LinkManager& operator=(const LinkManager&) = delete;

    /// Create a link between output port and input port.
    /// @return The new link's global ID, or an error.
    std::expected<uint32_t, LinkError> create_link(
        uint32_t output_port_id, uint32_t input_port_id);

    /// Destroy a link by its global ID.
    /// @return success or error.
    std::expected<void, LinkError> destroy_link(uint32_t link_id);

private:
    PwDartClientImpl* client_;
};

}  // namespace pw_dart

