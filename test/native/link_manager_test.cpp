// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "event_serializer.hpp"

#include <gtest/gtest.h>

// Link manager tests — exercise the data structures and JSON formats
// used by LinkManager. Actual PipeWire link creation requires a daemon,
// so these test the supporting infrastructure.

TEST(LinkManagerTest, LinkInfoSerialization) {
  pw_dart::LinkInfo link{
      .id = 100,
      .output_node_id = 1,
      .output_port_id = 10,
      .input_node_id = 2,
      .input_port_id = 20,
      .state = "active",
      .error = "",
      .properties = {{"link.output.port", "10"}, {"link.input.port", "20"}}};

  pw_dart::LinkAddedEvent event{.link = link};
  pw_dart::GraphEvent ge = event;
  auto json = pw_dart::serialize_event(ge);

  EXPECT_NE(json.find("\"type\":\"link_added\""), std::string::npos);
  EXPECT_NE(json.find("\"output_port_id\":10"), std::string::npos);
  EXPECT_NE(json.find("\"input_port_id\":20"), std::string::npos);
  EXPECT_NE(json.find("\"state\":\"active\""), std::string::npos);
}

TEST(LinkManagerTest, LinkRemovedSerialization) {
  pw_dart::LinkRemovedEvent event{.link_id = 42};
  pw_dart::GraphEvent ge = event;
  auto json = pw_dart::serialize_event(ge);

  EXPECT_NE(json.find("\"type\":\"link_removed\""), std::string::npos);
  EXPECT_NE(json.find("\"link_id\":42"), std::string::npos);
}

TEST(LinkManagerTest, LinkStateChangeSerialization) {
  pw_dart::LinkInfo link{
      .id = 50,
      .output_node_id = 3,
      .output_port_id = 30,
      .input_node_id = 4,
      .input_port_id = 40,
      .state = "paused",
  };

  pw_dart::LinkStateChangedEvent event{.link = link};
  auto json = pw_dart::serialize_event(pw_dart::GraphEvent{event});

  EXPECT_NE(json.find("\"type\":\"link_state_changed\""), std::string::npos);
  EXPECT_NE(json.find("\"state\":\"paused\""), std::string::npos);
}

TEST(LinkManagerTest, LinkErrorState) {
  pw_dart::LinkInfo link{
      .id = 60,
      .state = "error",
      .error = "format negotiation failed",
  };

  pw_dart::LinkAddedEvent event{.link = link};
  auto json = pw_dart::serialize_event(pw_dart::GraphEvent{event});

  EXPECT_NE(json.find("\"state\":\"error\""), std::string::npos);
  EXPECT_NE(json.find("format negotiation failed"), std::string::npos);
}

TEST(LinkManagerTest, LinkSnapshotRoundTrip) {
  pw_dart::GraphSnapshot snap;
  snap.links.push_back({.id = 1,
                        .output_node_id = 10,
                        .output_port_id = 100,
                        .input_node_id = 20,
                        .input_port_id = 200,
                        .state = "active"});
  snap.links.push_back({.id = 2,
                        .output_node_id = 30,
                        .output_port_id = 300,
                        .input_node_id = 40,
                        .input_port_id = 400,
                        .state = "paused"});

  auto json = pw_dart::serialize_snapshot(snap);
  auto snap2 = pw_dart::deserialize_snapshot(json);

  ASSERT_EQ(snap2.links.size(), 2u);
  EXPECT_EQ(snap2.links[0].id, 1u);
  EXPECT_EQ(snap2.links[0].state, "active");
  EXPECT_EQ(snap2.links[1].id, 2u);
  EXPECT_EQ(snap2.links[1].state, "paused");
}
