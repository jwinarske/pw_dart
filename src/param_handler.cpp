// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "param_handler.hpp"
#include "client.hpp"
#include "event_serializer.hpp"
#include "registry_monitor.hpp"

#include <pipewire/pipewire.h>
#include <spa/param/props.h>
#include <spa/pod/builder.h>
#include <spa/pod/iter.h>
#include <spa/pod/parser.h>

#include "glaze/glaze.hpp"

#include <sstream>

namespace pw_dart {

struct ParamUpdate {
  std::string key;
  std::string value;
};

}  // namespace pw_dart

template <>
struct glz::meta<pw_dart::ParamUpdate> {
  using T = pw_dart::ParamUpdate;
  static constexpr auto value = glz::object("key", &T::key, "value", &T::value);
};

namespace pw_dart {

ParamHandler::ParamHandler(PwDartClientImpl* client) : client_(client) {}

ParamHandler::~ParamHandler() = default;

void ParamHandler::enum_params(uint32_t node_id) {
  if (!client_ || !client_->registry_monitor())
    return;

  // Find the node's proxy in the registry monitor
  // For now, we trigger param enumeration via the node proxy
  // by calling pw_node_enum_params on the bound proxy.
  // The params will arrive as param events on the proxy listener.

  // Note: Full implementation requires storing proxy references
  // and listening for SPA_PARAM_Props events. For Phase 1, we use
  // a simplified approach with cached props from node info.

  // Post whatever we have cached
  auto json = get_cached_params_json(node_id);
  // Notify Dart that params are available
  ParamChangedEvent evt;
  evt.node_id = node_id;
  evt.key = "_enum_complete";
  evt.value = json;
  client_->post_event(GraphEvent{evt});
}

int32_t ParamHandler::set_param(uint32_t node_id,
                                const std::string& param_json) {
  if (!client_)
    return -1;

  ParamUpdate update;
  auto ec = glz::read_json(update, param_json);
  if (ec) {
    return -2;  // Parse error
  }

  // Update cache
  update_cache(node_id, update.key, update.value, "String");

  // Post param changed event
  ParamChangedEvent evt;
  evt.node_id = node_id;
  evt.key = update.key;
  evt.value = update.value;
  client_->post_event(GraphEvent{evt});

  // Note: Full implementation would build a SPA pod from the JSON
  // and call pw_node_set_param() on the proxy. Deferred to Phase 2
  // when we have full SPA pod builder infrastructure.

  return 0;
}

std::string ParamHandler::get_cached_params_json(uint32_t node_id) {
  std::lock_guard lock(mutex_);
  auto it = cache_.find(node_id);
  if (it == cache_.end()) {
    return "[]";
  }

  // Build a JSON array of param objects
  std::string json = "[";
  bool first = true;
  for (auto& [key, value] : it->second.params) {
    if (!first)
      json += ",";
    first = false;

    auto type_it = it->second.types.find(key);
    std::string type =
        (type_it != it->second.types.end()) ? type_it->second : "String";

    json += R"({"key":")";
    json += key;
    json += R"(","value":)";
    json += value;
    json += R"(,"type":")";
    json += type;
    json += R"(","flags":{"readable":true,"writable":true}})";
  }
  json += "]";
  return json;
}

void ParamHandler::update_cache(uint32_t node_id,
                                const std::string& key,
                                const std::string& value,
                                const std::string& type) {
  std::lock_guard lock(mutex_);
  auto& node_params = cache_[node_id];
  node_params.params[key] = value;
  node_params.types[key] = type;
}

void ParamHandler::clear_cache(uint32_t node_id) {
  std::lock_guard lock(mutex_);
  cache_.erase(node_id);
}

}  // namespace pw_dart
