// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0
//
// PwDartClientImpl — owns the PipeWire connection, event loop thread,
// registry monitor, and command queue.

#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "command_queue.hpp"
#include "event_serializer.hpp"

// Forward declarations for PipeWire types (avoid including PW headers in this header)
struct pw_main_loop;
struct pw_context;
struct pw_core;
struct pw_registry;
struct spa_hook;

namespace pw_dart {

// Forward declare
class RegistryMonitor;
class ParamHandler;
class LinkManager;

/// Internal implementation of the PipeWire client.
///
/// Manages:
/// - A std::jthread running pw_main_loop
/// - A CommandQueue for Dart → PW thread communication
/// - A RegistryMonitor for tracking graph objects
/// - Event posting to Dart via Dart_PostCObject
class PwDartClientImpl {
public:
    /// Create a client but don't connect yet.
    explicit PwDartClientImpl(int64_t dart_send_port);
    ~PwDartClientImpl();

    // Non-copyable, non-movable
    PwDartClientImpl(const PwDartClientImpl&) = delete;
    PwDartClientImpl& operator=(const PwDartClientImpl&) = delete;

    /// Connect to PipeWire and start the event loop.
    /// @param remote_name PipeWire remote (nullptr for default).
    /// @return true on success.
    bool connect(const char* remote_name);

    /// Disconnect and stop the event loop. Blocks until the thread exits.
    void disconnect();

    /// Get a JSON snapshot of the graph.
    std::string get_graph_snapshot();

    /// Get JSON-encoded params for a node.
    std::string get_node_params(uint32_t node_id);

    /// Queue a create-link command.
    int32_t create_link(uint32_t output_port_id, uint32_t input_port_id);

    /// Queue a destroy-link command.
    int32_t destroy_link(uint32_t link_id);

    /// Queue a set-param command.
    int32_t set_node_param(uint32_t node_id, const char* param_json);

    /// Post a serialized event to Dart.
    void post_event(const std::string& json);

    /// Post a GraphEvent to Dart.
    void post_event(const GraphEvent& event);

    /// Access the command queue (for the PW thread to drain).
    CommandQueue& command_queue() { return cmd_queue_; }

    /// Access the registry monitor.
    RegistryMonitor* registry_monitor() { return registry_.get(); }

    /// Access the param handler.
    ParamHandler* param_handler() { return params_.get(); }

    /// Access the link manager.
    LinkManager* link_manager() { return links_.get(); }

    /// Check if connected.
    bool is_connected() const { return connected_.load(std::memory_order_acquire); }

    /// Get the pw_core (for sub-components).
    pw_core* core() const { return core_; }

    /// Get the pw_registry (for sub-components).
    pw_registry* registry() const { return registry_pw_; }

private:
    /// The PipeWire event loop function (runs on the jthread).
    void loop_func(std::stop_token stop_token);

    /// Drain the command queue (called on PW thread each loop iteration).
    void drain_commands();

    /// Process a single command (called on PW thread).
    void process_command(Command& cmd);

    int64_t dart_send_port_;
    std::atomic<bool> connected_{false};

    // PipeWire objects (owned, destroyed in disconnect)
    pw_main_loop* loop_{nullptr};
    pw_context* context_{nullptr};
    pw_core* core_{nullptr};
    pw_registry* registry_pw_{nullptr};

    // SPA hooks for core/registry listeners
    std::unique_ptr<spa_hook> core_listener_;
    std::unique_ptr<spa_hook> registry_listener_;

    // Sub-components
    std::unique_ptr<RegistryMonitor> registry_;
    std::unique_ptr<ParamHandler> params_;
    std::unique_ptr<LinkManager> links_;

    // Threading
    CommandQueue cmd_queue_;
    std::jthread loop_thread_;
    std::mutex snapshot_mutex_;  // Protects snapshot reads from non-PW threads

    // Loop event source for waking the PW thread when commands arrive
    // (platform-specific, initialized in connect())
    void* loop_event_source_{nullptr};
};

}  // namespace pw_dart

