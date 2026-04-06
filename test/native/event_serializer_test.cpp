// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

#include "event_serializer.hpp"

#include <gtest/gtest.h>

using namespace pw_dart;

TEST(EventSerializerTest, SerializeNodeAdded) {
    NodeAddedEvent e;
    e.node = {
        .id = 42,
        .name = "alsa_output",
        .media_class = "Audio/Sink",
        .state = "running",
        .properties = {{"node.name", "alsa_output"}, {"audio.rate", "48000"}}
    };
    GraphEvent event = e;
    auto json = serialize_event(event);

    EXPECT_NE(json.find("\"type\":\"node_added\""), std::string::npos);
    EXPECT_NE(json.find("\"id\":42"), std::string::npos);
    EXPECT_NE(json.find("\"name\":\"alsa_output\""), std::string::npos);
    EXPECT_NE(json.find("\"media_class\":\"Audio/Sink\""), std::string::npos);
    EXPECT_NE(json.find("\"state\":\"running\""), std::string::npos);
}

TEST(EventSerializerTest, SerializeNodeRemoved) {
    NodeRemovedEvent e;
    e.node_id = 99;
    auto json = serialize_event(GraphEvent{e});

    EXPECT_NE(json.find("\"type\":\"node_removed\""), std::string::npos);
    EXPECT_NE(json.find("\"node_id\":99"), std::string::npos);
}

TEST(EventSerializerTest, SerializePortAdded) {
    PortAddedEvent e;
    e.port = {
        .id = 10,
        .node_id = 42,
        .name = "output_FL",
        .direction = "output",
        .media_type = "audio/raw",
        .is_physical = true,
        .is_terminal = false,
        .alias = "Front Left",
    };
    auto json = serialize_event(GraphEvent{e});

    EXPECT_NE(json.find("\"type\":\"port_added\""), std::string::npos);
    EXPECT_NE(json.find("\"node_id\":42"), std::string::npos);
    EXPECT_NE(json.find("\"direction\":\"output\""), std::string::npos);
    EXPECT_NE(json.find("\"is_physical\":true"), std::string::npos);
}

TEST(EventSerializerTest, SerializeLinkAdded) {
    LinkAddedEvent e;
    e.link = {
        .id = 100,
        .output_node_id = 1,
        .output_port_id = 10,
        .input_node_id = 2,
        .input_port_id = 20,
        .state = "active",
    };
    auto json = serialize_event(GraphEvent{e});

    EXPECT_NE(json.find("\"type\":\"link_added\""), std::string::npos);
    EXPECT_NE(json.find("\"output_port_id\":10"), std::string::npos);
    EXPECT_NE(json.find("\"state\":\"active\""), std::string::npos);
}

TEST(EventSerializerTest, SerializeLinkRemoved) {
    auto json = serialize_event(GraphEvent{LinkRemovedEvent{.link_id = 55}});
    EXPECT_NE(json.find("\"link_id\":55"), std::string::npos);
}

TEST(EventSerializerTest, SerializeLinkStateChanged) {
    LinkStateChangedEvent e;
    e.link = {.id = 77, .state = "paused"};
    auto json = serialize_event(GraphEvent{e});

    EXPECT_NE(json.find("\"type\":\"link_state_changed\""), std::string::npos);
    EXPECT_NE(json.find("\"state\":\"paused\""), std::string::npos);
}

TEST(EventSerializerTest, SerializeParamChanged) {
    ParamChangedEvent e;
    e.node_id = 5;
    e.key = "volume";
    e.value = "0.75";
    auto json = serialize_event(GraphEvent{e});

    EXPECT_NE(json.find("\"type\":\"param_changed\""), std::string::npos);
    EXPECT_NE(json.find("\"key\":\"volume\""), std::string::npos);
}

TEST(EventSerializerTest, SerializeAndDeserializeSnapshot) {
    GraphSnapshot snap;
    snap.nodes.push_back({.id = 1, .name = "node1", .media_class = "Audio/Sink", .state = "running"});
    snap.nodes.push_back({.id = 2, .name = "node2", .media_class = "Audio/Source", .state = "idle"});
    snap.ports.push_back({.id = 10, .node_id = 1, .name = "port1", .direction = "output"});
    snap.links.push_back({.id = 100, .output_node_id = 1, .output_port_id = 10, .input_node_id = 2, .input_port_id = 20, .state = "active"});
    snap.devices.push_back({.id = 200, .name = "ALSA", .media_class = "Audio/Device"});

    auto json = serialize_snapshot(snap);
    auto snap2 = deserialize_snapshot(json);

    ASSERT_EQ(snap2.nodes.size(), 2u);
    EXPECT_EQ(snap2.nodes[0].id, 1u);
    EXPECT_EQ(snap2.nodes[0].name, "node1");
    EXPECT_EQ(snap2.nodes[1].id, 2u);

    ASSERT_EQ(snap2.ports.size(), 1u);
    EXPECT_EQ(snap2.ports[0].node_id, 1u);

    ASSERT_EQ(snap2.links.size(), 1u);
    EXPECT_EQ(snap2.links[0].state, "active");

    ASSERT_EQ(snap2.devices.size(), 1u);
    EXPECT_EQ(snap2.devices[0].name, "ALSA");
}

TEST(EventSerializerTest, EmptySnapshot) {
    GraphSnapshot snap;
    auto json = serialize_snapshot(snap);
    auto snap2 = deserialize_snapshot(json);
    EXPECT_TRUE(snap2.nodes.empty());
    EXPECT_TRUE(snap2.ports.empty());
    EXPECT_TRUE(snap2.links.empty());
    EXPECT_TRUE(snap2.devices.empty());
}

TEST(EventSerializerTest, NodeWithProperties) {
    NodeAddedEvent e;
    e.node = {
        .id = 1,
        .name = "test",
        .properties = {
            {"node.name", "test-node"},
            {"media.class", "Audio/Sink"},
            {"audio.channels", "2"},
        }
    };
    auto json = serialize_event(GraphEvent{e});

    // Verify round-trip: deserialize the event and check properties
    NodeAddedEvent e2;
    auto ec = glz::read_json(e2, json);
    EXPECT_FALSE(static_cast<bool>(ec));
    EXPECT_EQ(e2.node.properties.size(), 3u);
    EXPECT_EQ(e2.node.properties["audio.channels"], "2");
}

