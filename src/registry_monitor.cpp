// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "registry_monitor.hpp"
#include "client.hpp"

#include <pipewire/pipewire.h>
#include <spa/utils/dict.h>
#include <spa/utils/hook.h>

#include <cstring>

namespace pw_dart {

// ─── ProxyData destructor ───

ProxyData::~ProxyData() {
  // Detach our listener from the proxy's hook list before destroying the
  // proxy. unique_ptr<spa_hook>::reset() only frees the hook memory; it
  // does NOT call spa_hook_remove(), so without an explicit removal the
  // proxy would still hold a dangling list node and walking its listener
  // list (e.g. on disconnect) would corrupt the heap.
  if (listener) {
    spa_hook_remove(listener.get());
  }
  if (proxy) {
    pw_proxy_destroy(proxy);
    proxy = nullptr;
  }
}

// ─── Static PW callback trampolines ───

// Registry events

static void registry_global(void* data,
                            uint32_t id,
                            uint32_t permissions,
                            const char* type,
                            uint32_t version,
                            const struct spa_dict* props) {
  auto* monitor = static_cast<RegistryMonitor*>(data);
  monitor->on_global(id, permissions, type, version, props);
}

static void registry_global_remove(void* data, uint32_t id) {
  auto* monitor = static_cast<RegistryMonitor*>(data);
  monitor->on_global_remove(id);
}

static const pw_registry_events registry_events = {
    .version = PW_VERSION_REGISTRY_EVENTS,
    .global = registry_global,
    .global_remove = registry_global_remove,
};

// Node info events

static void proxy_node_info(void* data, const struct pw_node_info* info) {
  auto* pd = static_cast<ProxyData*>(data);
  if (pd->client && pd->client->registry_monitor()) {
    pd->client->registry_monitor()->on_node_info(pd->id, info);
  }
}

static const pw_node_events node_events = {
    .version = PW_VERSION_NODE_EVENTS,
    .info = proxy_node_info,
};

// Port info events

static void proxy_port_info(void* data, const struct pw_port_info* info) {
  auto* pd = static_cast<ProxyData*>(data);
  if (pd->client && pd->client->registry_monitor()) {
    pd->client->registry_monitor()->on_port_info(pd->id, info);
  }
}

static const pw_port_events port_events = {
    .version = PW_VERSION_PORT_EVENTS,
    .info = proxy_port_info,
};

// Link info events

static void proxy_link_info(void* data, const struct pw_link_info* info) {
  auto* pd = static_cast<ProxyData*>(data);
  if (pd->client && pd->client->registry_monitor()) {
    pd->client->registry_monitor()->on_link_info(pd->id, info);
  }
}

static const pw_link_events link_events = {
    .version = PW_VERSION_LINK_EVENTS,
    .info = proxy_link_info,
};

// Device info events

static void proxy_device_info(void* data, const struct pw_device_info* info) {
  auto* pd = static_cast<ProxyData*>(data);
  if (pd->client && pd->client->registry_monitor()) {
    pd->client->registry_monitor()->on_device_info(pd->id, info);
  }
}

static const pw_device_events device_events = {
    .version = PW_VERSION_DEVICE_EVENTS,
    .info = proxy_device_info,
};

// ─── RegistryMonitor implementation ───

RegistryMonitor::RegistryMonitor(PwDartClientImpl* client,
                                 pw_registry* registry)
    : client_(client), registry_(registry) {
  registry_listener_ = std::make_unique<spa_hook>();
  spa_zero(*registry_listener_);
  pw_registry_add_listener(registry_, registry_listener_.get(),
                           &registry_events, this);
}

RegistryMonitor::~RegistryMonitor() {
  // Destroy all bound proxies first. Each ProxyData destructor removes its
  // own listener hook before calling pw_proxy_destroy.
  proxies_.clear();

  // Now detach the registry listener from the registry proxy *before*
  // freeing the hook memory. The registry proxy itself is owned by the
  // PwDartClientImpl and is destroyed after this monitor — if we freed the
  // hook here without removing it, the subsequent pw_proxy_destroy on the
  // registry would walk a dangling listener list and corrupt the heap.
  if (registry_listener_) {
    spa_hook_remove(registry_listener_.get());
    registry_listener_.reset();
  }
}

std::string RegistryMonitor::get_snapshot_json() {
  std::lock_guard lock(mutex_);
  GraphSnapshot snap;
  snap.nodes.reserve(nodes_.size());
  snap.ports.reserve(ports_.size());
  snap.links.reserve(links_.size());
  snap.devices.reserve(devices_.size());

  for (auto& [_, n] : nodes_)
    snap.nodes.push_back(n);
  for (auto& [_, p] : ports_)
    snap.ports.push_back(p);
  for (auto& [_, l] : links_)
    snap.links.push_back(l);
  for (auto& [_, d] : devices_)
    snap.devices.push_back(d);

  return serialize_snapshot(snap);
}

GraphSnapshot RegistryMonitor::get_snapshot() {
  std::lock_guard lock(mutex_);
  GraphSnapshot snap;
  for (auto& [_, n] : nodes_)
    snap.nodes.push_back(n);
  for (auto& [_, p] : ports_)
    snap.ports.push_back(p);
  for (auto& [_, l] : links_)
    snap.links.push_back(l);
  for (auto& [_, d] : devices_)
    snap.devices.push_back(d);
  return snap;
}

void RegistryMonitor::on_global(uint32_t id,
                                uint32_t permissions,
                                const char* type,
                                uint32_t version,
                                const struct spa_dict* props) {
  (void)permissions;

  if (!type)
    return;

  const char* type_str = type;

  // Determine object type and bind proxy
  if (strcmp(type_str, PW_TYPE_INTERFACE_Node) == 0) {
    auto pd = std::make_unique<ProxyData>();
    pd->id = id;
    pd->type = "node";
    pd->client = client_;
    pd->proxy = static_cast<pw_proxy*>(
        pw_registry_bind(registry_, id, type_str, PW_VERSION_NODE, 0));
    if (pd->proxy) {
      pd->listener = std::make_unique<spa_hook>();
      spa_zero(*pd->listener);
      pw_node_add_listener(reinterpret_cast<pw_node*>(pd->proxy),
                           pd->listener.get(), &node_events, pd.get());
    }
    id_types_[id] = "node";

    // Initial info from props
    {
      std::lock_guard lock(mutex_);
      NodeInfo info;
      info.id = id;
      info.name = dict_get(props, PW_KEY_NODE_NAME);
      if (info.name.empty())
        info.name = dict_get(props, PW_KEY_NODE_DESCRIPTION);
      info.media_class = dict_get(props, PW_KEY_MEDIA_CLASS);
      info.state = "creating";
      info.properties = dict_to_map(props);
      nodes_[id] = info;
    }

    proxies_[id] = std::move(pd);

  } else if (strcmp(type_str, PW_TYPE_INTERFACE_Port) == 0) {
    auto pd = std::make_unique<ProxyData>();
    pd->id = id;
    pd->type = "port";
    pd->client = client_;
    pd->proxy = static_cast<pw_proxy*>(
        pw_registry_bind(registry_, id, type_str, PW_VERSION_PORT, 0));
    if (pd->proxy) {
      pd->listener = std::make_unique<spa_hook>();
      spa_zero(*pd->listener);
      pw_port_add_listener(reinterpret_cast<pw_port*>(pd->proxy),
                           pd->listener.get(), &port_events, pd.get());
    }
    id_types_[id] = "port";

    {
      std::lock_guard lock(mutex_);
      PortInfo info;
      info.id = id;
      info.name = dict_get(props, PW_KEY_PORT_NAME);
      info.direction = dict_get(props, PW_KEY_PORT_DIRECTION);
      auto node_id_str = dict_get(props, PW_KEY_NODE_ID);
      info.node_id = node_id_str.empty()
                         ? 0
                         : static_cast<uint32_t>(std::stoul(node_id_str));
      info.media_type = dict_get(props, PW_KEY_FORMAT_DSP);
      info.alias = dict_get(props, PW_KEY_PORT_ALIAS);
      info.properties = dict_to_map(props);
      ports_[id] = info;
    }

    proxies_[id] = std::move(pd);

  } else if (strcmp(type_str, PW_TYPE_INTERFACE_Link) == 0) {
    auto pd = std::make_unique<ProxyData>();
    pd->id = id;
    pd->type = "link";
    pd->client = client_;
    pd->proxy = static_cast<pw_proxy*>(
        pw_registry_bind(registry_, id, type_str, PW_VERSION_LINK, 0));
    if (pd->proxy) {
      pd->listener = std::make_unique<spa_hook>();
      spa_zero(*pd->listener);
      pw_link_add_listener(reinterpret_cast<pw_link*>(pd->proxy),
                           pd->listener.get(), &link_events, pd.get());
    }
    id_types_[id] = "link";

    {
      std::lock_guard lock(mutex_);
      LinkInfo info;
      info.id = id;
      auto onode = dict_get(props, PW_KEY_LINK_OUTPUT_NODE);
      auto oport = dict_get(props, PW_KEY_LINK_OUTPUT_PORT);
      auto inode = dict_get(props, PW_KEY_LINK_INPUT_NODE);
      auto iport = dict_get(props, PW_KEY_LINK_INPUT_PORT);
      info.output_node_id =
          onode.empty() ? 0 : static_cast<uint32_t>(std::stoul(onode));
      info.output_port_id =
          oport.empty() ? 0 : static_cast<uint32_t>(std::stoul(oport));
      info.input_node_id =
          inode.empty() ? 0 : static_cast<uint32_t>(std::stoul(inode));
      info.input_port_id =
          iport.empty() ? 0 : static_cast<uint32_t>(std::stoul(iport));
      info.state = "init";
      info.properties = dict_to_map(props);
      links_[id] = info;
    }

    proxies_[id] = std::move(pd);

  } else if (strcmp(type_str, PW_TYPE_INTERFACE_Device) == 0) {
    auto pd = std::make_unique<ProxyData>();
    pd->id = id;
    pd->type = "device";
    pd->client = client_;
    pd->proxy = static_cast<pw_proxy*>(
        pw_registry_bind(registry_, id, type_str, PW_VERSION_DEVICE, 0));
    if (pd->proxy) {
      pd->listener = std::make_unique<spa_hook>();
      spa_zero(*pd->listener);
      pw_device_add_listener(reinterpret_cast<pw_device*>(pd->proxy),
                             pd->listener.get(), &device_events, pd.get());
    }
    id_types_[id] = "device";

    {
      std::lock_guard lock(mutex_);
      DeviceInfo info;
      info.id = id;
      info.name = dict_get(props, PW_KEY_DEVICE_NAME);
      info.description = dict_get(props, PW_KEY_DEVICE_DESCRIPTION);
      info.media_class = dict_get(props, PW_KEY_MEDIA_CLASS);
      info.api = dict_get(props, PW_KEY_DEVICE_API);
      info.properties = dict_to_map(props);
      devices_[id] = info;
    }

    proxies_[id] = std::move(pd);
  }
  // Unknown types are silently ignored (defensive parsing per section 8.3)
}

void RegistryMonitor::on_global_remove(uint32_t id) {
  auto type_it = id_types_.find(id);
  if (type_it == id_types_.end())
    return;

  const auto& type = type_it->second;

  {
    std::lock_guard lock(mutex_);
    if (type == "node") {
      nodes_.erase(id);
      client_->post_event(GraphEvent{NodeRemovedEvent{.node_id = id}});
    } else if (type == "port") {
      ports_.erase(id);
      client_->post_event(GraphEvent{PortRemovedEvent{.port_id = id}});
    } else if (type == "link") {
      links_.erase(id);
      client_->post_event(GraphEvent{LinkRemovedEvent{.link_id = id}});
    } else if (type == "device") {
      devices_.erase(id);
      // No device removed event in the current hierarchy — could add one
    }
  }

  proxies_.erase(id);
  id_types_.erase(type_it);
}

void RegistryMonitor::on_node_info(uint32_t id,
                                   const struct pw_node_info* info) {
  if (!info)
    return;

  bool is_new = false;
  {
    std::lock_guard lock(mutex_);
    auto it = nodes_.find(id);
    if (it == nodes_.end())
      return;

    auto& node = it->second;
    is_new = (node.state == "creating");

    // Update state
    switch (info->state) {
      case PW_NODE_STATE_ERROR:
        node.state = "error";
        break;
      case PW_NODE_STATE_CREATING:
        node.state = "creating";
        break;
      case PW_NODE_STATE_SUSPENDED:
        node.state = "suspended";
        break;
      case PW_NODE_STATE_IDLE:
        node.state = "idle";
        break;
      case PW_NODE_STATE_RUNNING:
        node.state = "running";
        break;
    }

    // Update properties if available
    if (info->props) {
      node.properties = dict_to_map(info->props);
      auto name = dict_get(info->props, PW_KEY_NODE_NAME);
      if (!name.empty())
        node.name = name;
      auto mc = dict_get(info->props, PW_KEY_MEDIA_CLASS);
      if (!mc.empty())
        node.media_class = mc;
    }

    // Post event
    if (is_new) {
      client_->post_event(GraphEvent{NodeAddedEvent{.node = node}});
    } else {
      client_->post_event(GraphEvent{NodeInfoChangedEvent{.node = node}});
    }
  }
}

void RegistryMonitor::on_port_info(uint32_t id,
                                   const struct pw_port_info* info) {
  if (!info)
    return;

  bool is_new = false;
  {
    std::lock_guard lock(mutex_);
    auto it = ports_.find(id);
    if (it == ports_.end())
      return;

    auto& port = it->second;
    is_new = port.direction.empty() || port.name.empty();

    port.direction =
        (info->direction == PW_DIRECTION_INPUT) ? "input" : "output";

    if (info->props) {
      port.properties = dict_to_map(info->props);
      auto name = dict_get(info->props, PW_KEY_PORT_NAME);
      if (!name.empty())
        port.name = name;
      auto alias = dict_get(info->props, PW_KEY_PORT_ALIAS);
      if (!alias.empty())
        port.alias = alias;
      auto phys = dict_get(info->props, PW_KEY_PORT_PHYSICAL);
      port.is_physical = (phys == "true" || phys == "1");
      auto term = dict_get(info->props, PW_KEY_PORT_TERMINAL);
      port.is_terminal = (term == "true" || term == "1");
    }

    client_->post_event(GraphEvent{PortAddedEvent{.port = port}});
  }
}

void RegistryMonitor::on_link_info(uint32_t id,
                                   const struct pw_link_info* info) {
  if (!info)
    return;

  {
    std::lock_guard lock(mutex_);
    auto it = links_.find(id);
    if (it == links_.end())
      return;

    auto& link = it->second;
    link.output_node_id = info->output_node_id;
    link.output_port_id = info->output_port_id;
    link.input_node_id = info->input_node_id;
    link.input_port_id = info->input_port_id;

    std::string old_state = link.state;

    switch (info->state) {
      case PW_LINK_STATE_ERROR:
        link.state = "error";
        break;
      case PW_LINK_STATE_UNLINKED:
        link.state = "unlinked";
        break;
      case PW_LINK_STATE_INIT:
        link.state = "init";
        break;
      case PW_LINK_STATE_NEGOTIATING:
        link.state = "negotiating";
        break;
      case PW_LINK_STATE_ALLOCATING:
        link.state = "allocating";
        break;
      case PW_LINK_STATE_PAUSED:
        link.state = "paused";
        break;
      case PW_LINK_STATE_ACTIVE:
        link.state = "active";
        break;
    }

    if (info->error) {
      link.error = info->error;
    }

    if (old_state == "init") {
      client_->post_event(GraphEvent{LinkAddedEvent{.link = link}});
    } else {
      client_->post_event(GraphEvent{LinkStateChangedEvent{.link = link}});
    }
  }
}

void RegistryMonitor::on_device_info(uint32_t id,
                                     const struct pw_device_info* info) {
  if (!info)
    return;

  {
    std::lock_guard lock(mutex_);
    auto it = devices_.find(id);
    if (it == devices_.end())
      return;

    auto& device = it->second;
    if (info->props) {
      device.properties = dict_to_map(info->props);
      auto name = dict_get(info->props, PW_KEY_DEVICE_NAME);
      if (!name.empty())
        device.name = name;
      auto desc = dict_get(info->props, PW_KEY_DEVICE_DESCRIPTION);
      if (!desc.empty())
        device.description = desc;
    }
  }
}

// ─── Helpers ───

std::string RegistryMonitor::dict_get(const struct spa_dict* dict,
                                      const char* key) {
  if (!dict || !key)
    return "";
  const char* val = spa_dict_lookup(dict, key);
  return val ? std::string(val) : "";
}

std::map<std::string, std::string> RegistryMonitor::dict_to_map(
    const struct spa_dict* dict) {
  std::map<std::string, std::string> result;
  if (!dict)
    return result;
  const struct spa_dict_item* item;
  spa_dict_for_each(item, dict) {
    if (item->key && item->value) {
      result[item->key] = item->value;
    }
  }
  return result;
}

}  // namespace pw_dart
