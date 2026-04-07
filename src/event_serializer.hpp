// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0
//
// Event serializer: converts internal C++ graph events into JSON strings
// using Glaze for posting to Dart via Dart_PostCObject.

#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <variant>

#include "glaze/glaze.hpp"

namespace pw_dart {

// ─── Event data structs ───

struct NodeInfo {
  uint32_t id{};
  std::string name;
  std::string media_class;
  std::string state;
  std::map<std::string, std::string> properties;
};

struct PortInfo {
  uint32_t id{};
  uint32_t node_id{};
  std::string name;
  std::string direction;
  std::string media_type;
  bool is_physical{false};
  bool is_terminal{false};
  std::string alias;
  std::map<std::string, std::string> properties;
};

struct LinkInfo {
  uint32_t id{};
  uint32_t output_node_id{};
  uint32_t output_port_id{};
  uint32_t input_node_id{};
  uint32_t input_port_id{};
  std::string state;
  std::string error;
  std::map<std::string, std::string> properties;
};

struct DeviceInfo {
  uint32_t id{};
  std::string name;
  std::string description;
  std::string media_class;
  std::string api;
  std::map<std::string, std::string> properties;
};

// ─── Event types ───

struct NodeAddedEvent {
  std::string type{"node_added"};
  NodeInfo node;
};

struct NodeRemovedEvent {
  std::string type{"node_removed"};
  uint32_t node_id{};
};

struct NodeInfoChangedEvent {
  std::string type{"node_info_changed"};
  NodeInfo node;
};

struct PortAddedEvent {
  std::string type{"port_added"};
  PortInfo port;
};

struct PortRemovedEvent {
  std::string type{"port_removed"};
  uint32_t port_id{};
};

struct LinkAddedEvent {
  std::string type{"link_added"};
  LinkInfo link;
};

struct LinkRemovedEvent {
  std::string type{"link_removed"};
  uint32_t link_id{};
};

struct LinkStateChangedEvent {
  std::string type{"link_state_changed"};
  LinkInfo link;
};

struct ParamChangedEvent {
  std::string type{"param_changed"};
  uint32_t node_id{};
  std::string key;
  std::string value;  // JSON-encoded value
};

/// All event types.
using GraphEvent = std::variant<NodeAddedEvent,
                                NodeRemovedEvent,
                                NodeInfoChangedEvent,
                                PortAddedEvent,
                                PortRemovedEvent,
                                LinkAddedEvent,
                                LinkRemovedEvent,
                                LinkStateChangedEvent,
                                ParamChangedEvent>;

// ─── Graph snapshot ───

struct GraphSnapshot {
  std::vector<NodeInfo> nodes;
  std::vector<PortInfo> ports;
  std::vector<LinkInfo> links;
  std::vector<DeviceInfo> devices;
};

}  // namespace pw_dart

// ─── Glaze reflection metadata ───

template <>
struct glz::meta<pw_dart::NodeInfo> {
  using T = pw_dart::NodeInfo;
  static constexpr auto value = object("id",
                                       &T::id,
                                       "name",
                                       &T::name,
                                       "media_class",
                                       &T::media_class,
                                       "state",
                                       &T::state,
                                       "properties",
                                       &T::properties);
};

template <>
struct glz::meta<pw_dart::PortInfo> {
  using T = pw_dart::PortInfo;
  static constexpr auto value = object("id",
                                       &T::id,
                                       "node_id",
                                       &T::node_id,
                                       "name",
                                       &T::name,
                                       "direction",
                                       &T::direction,
                                       "media_type",
                                       &T::media_type,
                                       "is_physical",
                                       &T::is_physical,
                                       "is_terminal",
                                       &T::is_terminal,
                                       "alias",
                                       &T::alias,
                                       "properties",
                                       &T::properties);
};

template <>
struct glz::meta<pw_dart::LinkInfo> {
  using T = pw_dart::LinkInfo;
  static constexpr auto value = object("id",
                                       &T::id,
                                       "output_node_id",
                                       &T::output_node_id,
                                       "output_port_id",
                                       &T::output_port_id,
                                       "input_node_id",
                                       &T::input_node_id,
                                       "input_port_id",
                                       &T::input_port_id,
                                       "state",
                                       &T::state,
                                       "error",
                                       &T::error,
                                       "properties",
                                       &T::properties);
};

template <>
struct glz::meta<pw_dart::DeviceInfo> {
  using T = pw_dart::DeviceInfo;
  static constexpr auto value = object("id",
                                       &T::id,
                                       "name",
                                       &T::name,
                                       "description",
                                       &T::description,
                                       "media_class",
                                       &T::media_class,
                                       "api",
                                       &T::api,
                                       "properties",
                                       &T::properties);
};

template <>
struct glz::meta<pw_dart::NodeAddedEvent> {
  using T = pw_dart::NodeAddedEvent;
  static constexpr auto value = object("type", &T::type, "node", &T::node);
};

template <>
struct glz::meta<pw_dart::NodeRemovedEvent> {
  using T = pw_dart::NodeRemovedEvent;
  static constexpr auto value =
      object("type", &T::type, "node_id", &T::node_id);
};

template <>
struct glz::meta<pw_dart::NodeInfoChangedEvent> {
  using T = pw_dart::NodeInfoChangedEvent;
  static constexpr auto value = object("type", &T::type, "node", &T::node);
};

template <>
struct glz::meta<pw_dart::PortAddedEvent> {
  using T = pw_dart::PortAddedEvent;
  static constexpr auto value = object("type", &T::type, "port", &T::port);
};

template <>
struct glz::meta<pw_dart::PortRemovedEvent> {
  using T = pw_dart::PortRemovedEvent;
  static constexpr auto value =
      object("type", &T::type, "port_id", &T::port_id);
};

template <>
struct glz::meta<pw_dart::LinkAddedEvent> {
  using T = pw_dart::LinkAddedEvent;
  static constexpr auto value = object("type", &T::type, "link", &T::link);
};

template <>
struct glz::meta<pw_dart::LinkRemovedEvent> {
  using T = pw_dart::LinkRemovedEvent;
  static constexpr auto value =
      object("type", &T::type, "link_id", &T::link_id);
};

template <>
struct glz::meta<pw_dart::LinkStateChangedEvent> {
  using T = pw_dart::LinkStateChangedEvent;
  static constexpr auto value = object("type", &T::type, "link", &T::link);
};

template <>
struct glz::meta<pw_dart::ParamChangedEvent> {
  using T = pw_dart::ParamChangedEvent;
  static constexpr auto value = object("type",
                                       &T::type,
                                       "node_id",
                                       &T::node_id,
                                       "key",
                                       &T::key,
                                       "value",
                                       &T::value);
};

template <>
struct glz::meta<pw_dart::GraphSnapshot> {
  using T = pw_dart::GraphSnapshot;
  static constexpr auto value = object("nodes",
                                       &T::nodes,
                                       "ports",
                                       &T::ports,
                                       "links",
                                       &T::links,
                                       "devices",
                                       &T::devices);
};

namespace pw_dart {

// ─── Serialization functions ───

/// Serialize any GraphEvent variant to JSON.
inline std::string serialize_event(const GraphEvent& event) {
  return std::visit(
      [](const auto& e) -> std::string {
        std::string json;
        auto ec = glz::write_json(e, json);
        if (ec) {
          return R"({"type":"error","message":"serialization_failed"})";
        }
        return json;
      },
      event);
}

/// Serialize a graph snapshot to JSON.
inline std::string serialize_snapshot(const GraphSnapshot& snapshot) {
  std::string json;
  auto ec = glz::write_json(snapshot, json);
  if (ec) {
    return R"({"nodes":[],"ports":[],"links":[],"devices":[]})";
  }
  return json;
}

/// Deserialize a graph snapshot from JSON.
inline GraphSnapshot deserialize_snapshot(const std::string& json) {
  GraphSnapshot snapshot;
  auto ec = glz::read_json(snapshot, json);
  if (ec) {
    return {};
  }
  return snapshot;
}

}  // namespace pw_dart
