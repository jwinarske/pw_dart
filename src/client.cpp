// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "client.hpp"
#include "registry_monitor.hpp"
#include "param_handler.hpp"
#include "link_manager.hpp"

#include <pipewire/pipewire.h>
#include <spa/utils/hook.h>
#include <spa/utils/result.h>

#include <cstring>

// Dart FFI: we use Dart_PostCObject_DL to post event strings to Dart.
// This is the dynamic-linked version — resolved at runtime.
// For now, we store the send port and use a simple callback mechanism.
#include "dart_api_dl.h"

namespace pw_dart {

// ─── PipeWire core event callbacks ───

static void on_core_done(void* data, uint32_t id, int seq) {
    // Core sync completed — used for async request tracking
    (void)data;
    (void)id;
    (void)seq;
}

static void on_core_error(void* data, uint32_t id, int seq, int res, const char* message) {
    (void)seq;
    auto* client = static_cast<PwDartClientImpl*>(data);
    // Post error event to Dart
    std::string error_json = R"({"type":"error","id":)" + std::to_string(id) +
                             R"(,"code":)" + std::to_string(res) +
                             R"(,"message":")" + (message ? message : "") + R"("})";
    client->post_event(error_json);
}

static const pw_core_events core_events = {
    .version = PW_VERSION_CORE_EVENTS,
    .done = on_core_done,
    .error = on_core_error,
};

// ─── Loop event callback (wakes PW thread to drain commands) ───

static void on_loop_event(void* data, uint64_t count) {
    (void)count;
    auto* client = static_cast<PwDartClientImpl*>(data);
    client->drain_commands();
}

// ─── PwDartClientImpl ───

PwDartClientImpl::PwDartClientImpl(int64_t dart_send_port)
    : dart_send_port_(dart_send_port) {}

PwDartClientImpl::~PwDartClientImpl() {
    disconnect();
}

bool PwDartClientImpl::connect(const char* remote_name) {
    if (connected_.load(std::memory_order_acquire)) {
        return true;  // Already connected
    }

    // Initialize PipeWire (idempotent)
    pw_init(nullptr, nullptr);

    // Create the main loop
    loop_ = pw_main_loop_new(nullptr);
    if (!loop_) {
        return false;
    }

    // Create context
    context_ = pw_context_new(
        pw_main_loop_get_loop(loop_),
        nullptr, 0);
    if (!context_) {
        pw_main_loop_destroy(loop_);
        loop_ = nullptr;
        return false;
    }

    // Connect to PipeWire
    auto* props = remote_name
        ? pw_properties_new(PW_KEY_REMOTE_NAME, remote_name, nullptr)
        : nullptr;

    core_ = pw_context_connect(context_, props, 0);
    if (!core_) {
        pw_context_destroy(context_);
        pw_main_loop_destroy(loop_);
        context_ = nullptr;
        loop_ = nullptr;
        return false;
    }

    // Add core listener
    core_listener_ = std::make_unique<spa_hook>();
    spa_zero(*core_listener_);
    pw_core_add_listener(core_, core_listener_.get(), &core_events, this);

    // Get registry
    registry_pw_ = pw_core_get_registry(core_, PW_VERSION_REGISTRY, 0);
    if (!registry_pw_) {
        pw_core_disconnect(core_);
        pw_context_destroy(context_);
        pw_main_loop_destroy(loop_);
        core_ = nullptr;
        context_ = nullptr;
        loop_ = nullptr;
        return false;
    }

    // Create sub-components
    registry_ = std::make_unique<RegistryMonitor>(this, registry_pw_);
    params_ = std::make_unique<ParamHandler>(this);
    links_ = std::make_unique<LinkManager>(this);

    // Add event source to wake the PW loop when commands arrive
    auto* loop = pw_main_loop_get_loop(loop_);
    loop_event_source_ = pw_loop_add_event(loop, on_loop_event, this);

    connected_.store(true, std::memory_order_release);

    // Start the PW thread
    loop_thread_ = std::jthread([this](std::stop_token st) {
        this->loop_func(st);
    });

    return true;
}

void PwDartClientImpl::disconnect() {
    if (!connected_.load(std::memory_order_acquire)) {
        return;
    }

    connected_.store(false, std::memory_order_release);

    // Ask the loop to quit. PipeWire APIs are not thread-safe, so we must
    // schedule pw_main_loop_quit() onto the loop thread itself via
    // pw_loop_invoke() rather than calling it directly from this thread.
    if (loop_) {
        pw_loop_invoke(
            pw_main_loop_get_loop(loop_),
            [](spa_loop*, bool, uint32_t, const void*, size_t, void* data) -> int {
                pw_main_loop_quit(static_cast<pw_main_loop*>(data));
                return 0;
            },
            0, nullptr, 0, false, loop_);
    }

    // Wait for the loop thread to exit pw_main_loop_run(). After this point
    // the loop thread is gone and it is safe to call PipeWire APIs from this
    // thread again.
    if (loop_thread_.joinable()) {
        loop_thread_.request_stop();
        loop_thread_.join();
    }

    // Tear down sub-components first. Each one is responsible for removing
    // its own spa_hook listeners from the proxies it owns *before* destroying
    // those proxies (see RegistryMonitor::~RegistryMonitor).
    registry_.reset();
    params_.reset();
    links_.reset();

    // The event source must be destroyed while the loop still exists.
    if (loop_event_source_ && loop_) {
        pw_loop_destroy_source(pw_main_loop_get_loop(loop_),
                               static_cast<spa_source*>(loop_event_source_));
        loop_event_source_ = nullptr;
    }

    // Destroy the registry proxy before disconnecting the core.
    if (registry_pw_) {
        pw_proxy_destroy(reinterpret_cast<pw_proxy*>(registry_pw_));
        registry_pw_ = nullptr;
    }

    // Detach the core listener from the core's hook list *before* freeing the
    // hook memory. unique_ptr::reset() alone would delete the spa_hook while
    // it is still linked, leaving a dangling node in the core's listener list
    // and corrupting the heap when the core is disconnected.
    if (core_listener_) {
        spa_hook_remove(core_listener_.get());
        core_listener_.reset();
    }

    if (core_) {
        pw_core_disconnect(core_);
        core_ = nullptr;
    }

    if (context_) {
        pw_context_destroy(context_);
        context_ = nullptr;
    }

    if (loop_) {
        pw_main_loop_destroy(loop_);
        loop_ = nullptr;
    }
}

std::string PwDartClientImpl::get_graph_snapshot() {
    std::lock_guard lock(snapshot_mutex_);
    if (!registry_) {
        return R"({"nodes":[],"ports":[],"links":[],"devices":[]})";
    }
    return registry_->get_snapshot_json();
}

std::string PwDartClientImpl::get_node_params(uint32_t node_id) {
    if (!params_) {
        return "[]";
    }
    return params_->get_cached_params_json(node_id);
}

int32_t PwDartClientImpl::create_link(uint32_t output_port_id, uint32_t input_port_id) {
    if (!connected_.load(std::memory_order_acquire)) {
        return -1;
    }
    CreateLinkCmd cmd{.output_port_id = output_port_id, .input_port_id = input_port_id, .request_id = 0};
    return cmd_queue_.try_push(Command{cmd}) ? 0 : -2;  // -2 = queue full
}

int32_t PwDartClientImpl::destroy_link(uint32_t link_id) {
    if (!connected_.load(std::memory_order_acquire)) {
        return -1;
    }
    DestroyLinkCmd cmd{.link_id = link_id, .request_id = 0};
    return cmd_queue_.try_push(Command{cmd}) ? 0 : -2;
}

int32_t PwDartClientImpl::set_node_param(uint32_t node_id, const char* param_json) {
    if (!connected_.load(std::memory_order_acquire) || !param_json) {
        return -1;
    }
    SetParamCmd cmd{.node_id = node_id, .param_json = param_json, .request_id = 0};
    return cmd_queue_.try_push(Command{cmd}) ? 0 : -2;
}

void PwDartClientImpl::post_event(const std::string& json) {
    if (dart_send_port_ == 0) return;

    // Post JSON string to Dart via Dart_PostCObject_DL.
    // The Dart side receives this as a String on its ReceivePort.
    Dart_CObject obj;
    obj.type = Dart_CObject_kString;
    obj.value.as_string = const_cast<char*>(json.c_str());
    Dart_PostCObject_DL(dart_send_port_, &obj);
}

void PwDartClientImpl::post_event(const GraphEvent& event) {
    post_event(serialize_event(event));
}

void PwDartClientImpl::loop_func(std::stop_token stop_token) {
    // Run the PipeWire main loop.
    // The loop exits when pw_main_loop_quit() is called (from disconnect()).
    if (loop_) {
        pw_main_loop_run(loop_);
    }
}

void PwDartClientImpl::drain_commands() {
    while (auto cmd = cmd_queue_.try_pop()) {
        process_command(*cmd);
    }
}

void PwDartClientImpl::process_command(Command& cmd) {
    std::visit([this](auto& c) {
        using T = std::decay_t<decltype(c)>;

        if constexpr (std::is_same_v<T, CreateLinkCmd>) {
            if (links_) {
                links_->create_link(c.output_port_id, c.input_port_id);
            }
        } else if constexpr (std::is_same_v<T, DestroyLinkCmd>) {
            if (links_) {
                links_->destroy_link(c.link_id);
            }
        } else if constexpr (std::is_same_v<T, SetParamCmd>) {
            if (params_) {
                params_->set_param(c.node_id, c.param_json);
            }
        } else if constexpr (std::is_same_v<T, EnumParamsCmd>) {
            if (params_) {
                params_->enum_params(c.node_id);
            }
        } else if constexpr (std::is_same_v<T, GetSnapshotCmd>) {
            // Snapshot is handled synchronously via get_graph_snapshot()
        } else if constexpr (std::is_same_v<T, DisconnectCmd>) {
            if (loop_) {
                pw_main_loop_quit(loop_);
            }
        }
    }, cmd);
}

}  // namespace pw_dart

