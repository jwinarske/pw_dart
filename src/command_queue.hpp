// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// Lock-free single-producer single-consumer (SPSC) ring buffer for
// sending commands from the Dart isolate thread to the PipeWire thread.
// Header-only. Uses std::atomic with acquire/release ordering.

#pragma once

#include <atomic>
#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <variant>

namespace pw_dart {

// ─── Command types (tagged union via std::variant) ───

struct CreateLinkCmd {
    uint32_t output_port_id;
    uint32_t input_port_id;
    int64_t  request_id;  // For correlating async responses
};

struct DestroyLinkCmd {
    uint32_t link_id;
    int64_t  request_id;
};

struct SetParamCmd {
    uint32_t    node_id;
    std::string param_json;  // JSON-encoded parameter key/value
    int64_t     request_id;
};

struct EnumParamsCmd {
    uint32_t node_id;
    int64_t  request_id;
};

struct GetSnapshotCmd {
    int64_t request_id;
};

struct DisconnectCmd {};

/// All command types that can be sent from Dart to the PW thread.
using Command = std::variant<
    CreateLinkCmd,
    DestroyLinkCmd,
    SetParamCmd,
    EnumParamsCmd,
    GetSnapshotCmd,
    DisconnectCmd
>;

// ─── SPSC Ring Buffer ───

/// Lock-free single-producer single-consumer ring buffer.
///
/// Producer (Dart thread) calls try_push().
/// Consumer (PipeWire thread) calls try_pop().
///
/// Template parameter N must be a power of two.
template <typename T, std::size_t N = 256>
class SpscQueue {
    static_assert((N & (N - 1)) == 0, "N must be a power of two");
    static_assert(N >= 2, "N must be at least 2");

public:
    SpscQueue() : head_(0), tail_(0) {}

    // Non-copyable, non-movable
    SpscQueue(const SpscQueue&) = delete;
    SpscQueue& operator=(const SpscQueue&) = delete;
    SpscQueue(SpscQueue&&) = delete;
    SpscQueue& operator=(SpscQueue&&) = delete;

    /// Try to enqueue an item. Returns false if the queue is full.
    /// Thread-safe for a single producer thread.
    bool try_push(const T& item) {
        const auto head = head_.load(std::memory_order_relaxed);
        const auto next = (head + 1) & mask_;
        if (next == tail_.load(std::memory_order_acquire)) {
            return false;  // Full
        }
        buffer_[head] = item;
        head_.store(next, std::memory_order_release);
        return true;
    }

    /// Try to enqueue an item (move version).
    bool try_push(T&& item) {
        const auto head = head_.load(std::memory_order_relaxed);
        const auto next = (head + 1) & mask_;
        if (next == tail_.load(std::memory_order_acquire)) {
            return false;  // Full
        }
        buffer_[head] = std::move(item);
        head_.store(next, std::memory_order_release);
        return true;
    }

    /// Try to dequeue an item. Returns std::nullopt if the queue is empty.
    /// Thread-safe for a single consumer thread.
    std::optional<T> try_pop() {
        const auto tail = tail_.load(std::memory_order_relaxed);
        if (tail == head_.load(std::memory_order_acquire)) {
            return std::nullopt;  // Empty
        }
        T item = std::move(buffer_[tail]);
        tail_.store((tail + 1) & mask_, std::memory_order_release);
        return item;
    }

    /// Check if the queue is empty (approximate — may race).
    [[nodiscard]] bool empty() const noexcept {
        return head_.load(std::memory_order_acquire) ==
               tail_.load(std::memory_order_acquire);
    }

    /// Capacity of the queue (always N - 1 usable slots).
    [[nodiscard]] static constexpr std::size_t capacity() noexcept {
        return N - 1;
    }

    /// Current size (approximate — may race).
    [[nodiscard]] std::size_t size() const noexcept {
        const auto head = head_.load(std::memory_order_acquire);
        const auto tail = tail_.load(std::memory_order_acquire);
        return (head - tail) & mask_;
    }

private:
    static constexpr std::size_t mask_ = N - 1;

    alignas(64) std::atomic<std::size_t> head_;
    alignas(64) std::atomic<std::size_t> tail_;
    std::array<T, N> buffer_;
};

/// The command queue used between Dart isolate and PipeWire threads.
using CommandQueue = SpscQueue<Command, 256>;

}  // namespace pw_dart

