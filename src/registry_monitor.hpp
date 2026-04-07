// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// RegistryMonitor — tracks all PipeWire global objects and maintains
// an in-memory graph snapshot. Posts events to Dart on add/remove/change.

#pragma once

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

#include "event_serializer.hpp"

// Forward declarations — these are C structs in global scope
struct pw_registry;
struct pw_proxy;
struct spa_hook;
struct spa_dict;
struct pw_node_info;
struct pw_port_info;
struct pw_link_info;
struct pw_device_info;

namespace pw_dart {

class PwDartClientImpl;

/// Proxy wrapper — holds a pw_proxy and its listener hook.
struct ProxyData {
    pw_proxy* proxy{nullptr};
    std::unique_ptr<spa_hook> listener;
    PwDartClientImpl* client{nullptr};
    uint32_t id{};
    std::string type;

    ~ProxyData();
};

/// Monitors the PipeWire registry and maintains a graph snapshot.
///
/// Registers pw_registry_events to receive global/global_remove callbacks.
/// For each interesting object type (Node, Port, Link, Device), binds a
/// proxy and listens for info changes.
class RegistryMonitor {
public:
    RegistryMonitor(PwDartClientImpl* client, pw_registry* registry);
    ~RegistryMonitor();

    // Non-copyable
    RegistryMonitor(const RegistryMonitor&) = delete;
    RegistryMonitor& operator=(const RegistryMonitor&) = delete;

    /// Get the current graph snapshot as JSON.
    std::string get_snapshot_json();

    /// Get the snapshot data (thread-safe copy).
    GraphSnapshot get_snapshot();

    // ─── Callbacks from PW thread ───

    /// Called when a new global object appears.
    void on_global(uint32_t id, uint32_t permissions, const char* type,
                   uint32_t version, const ::spa_dict* props);

    /// Called when a global object is removed.
    void on_global_remove(uint32_t id);

    /// Called when node info changes.
    void on_node_info(uint32_t id, const ::pw_node_info* info);

    /// Called when port info changes.
    void on_port_info(uint32_t id, const ::pw_port_info* info);

    /// Called when link info changes.
    void on_link_info(uint32_t id, const ::pw_link_info* info);

    /// Called when device info changes.
    void on_device_info(uint32_t id, const ::pw_device_info* info);

private:
    PwDartClientImpl* client_;
    pw_registry* registry_;
    std::unique_ptr<spa_hook> registry_listener_;

    // Object tracking
    std::unordered_map<uint32_t, std::unique_ptr<ProxyData>> proxies_;

    // Graph snapshot (protected by mutex for cross-thread reads)
    mutable std::mutex mutex_;
    std::unordered_map<uint32_t, NodeInfo> nodes_;
    std::unordered_map<uint32_t, PortInfo> ports_;
    std::unordered_map<uint32_t, LinkInfo> links_;
    std::unordered_map<uint32_t, DeviceInfo> devices_;

    /// Type string for the removed object (to know which map to erase from).
    std::unordered_map<uint32_t, std::string> id_types_;

    /// Helper to extract string from spa_dict.
    static std::string dict_get(const ::spa_dict* dict, const char* key);

    /// Helper to extract all properties from spa_dict.
    static std::map<std::string, std::string> dict_to_map(const ::spa_dict* dict);
};

}  // namespace pw_dart

