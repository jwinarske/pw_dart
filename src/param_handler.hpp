// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// ParamHandler — handles node parameter enumeration, get, and set
// via SPA pod parsing and JSON conversion.

#pragma once

#include <cstdint>
#include <map>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace pw_dart {

class PwDartClientImpl;

/// Cached parameter information for a node.
struct ParamCache {
    uint32_t node_id;
    std::string json;  // Cached JSON representation
    bool valid{false};
};

/// Handles parameter enumeration and modification for PipeWire nodes.
///
/// Parameters are accessed via SPA pods. This handler:
/// - Converts SPA pods to JSON (for Dart consumption)
/// - Converts JSON back to SPA pods (for setting params)
/// - Caches param results per-node
class ParamHandler {
public:
    explicit ParamHandler(PwDartClientImpl* client);
    ~ParamHandler();

    // Non-copyable
    ParamHandler(const ParamHandler&) = delete;
    ParamHandler& operator=(const ParamHandler&) = delete;

    /// Enumerate parameters for a node. Results posted as events.
    void enum_params(uint32_t node_id);

    /// Set a parameter on a node.
    /// @param node_id Target node ID.
    /// @param param_json JSON with "key" and "value" fields.
    /// @return 0 on success, negative on error.
    int32_t set_param(uint32_t node_id, const std::string& param_json);

    /// Get cached params as JSON array.
    std::string get_cached_params_json(uint32_t node_id);

    /// Update param cache (called from PW thread when params arrive).
    void update_cache(uint32_t node_id, const std::string& key,
                      const std::string& value, const std::string& type);

    /// Clear cache for a node.
    void clear_cache(uint32_t node_id);

private:
    PwDartClientImpl* client_;

    mutable std::mutex mutex_;

    /// Cached parameters per node: node_id -> (key -> json_value)
    struct NodeParams {
        std::map<std::string, std::string> params;  // key -> JSON value
        std::map<std::string, std::string> types;   // key -> type string
    };
    std::unordered_map<uint32_t, NodeParams> cache_;
};

}  // namespace pw_dart

