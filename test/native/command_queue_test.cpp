// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

#include "command_queue.hpp"

#include <gtest/gtest.h>
#include <thread>
#include <vector>

using namespace pw_dart;

TEST(SpscQueueTest, PushPopSingle) {
  SpscQueue<int, 4> q;
  EXPECT_TRUE(q.empty());
  EXPECT_EQ(q.size(), 0u);

  EXPECT_TRUE(q.try_push(42));
  EXPECT_FALSE(q.empty());
  EXPECT_EQ(q.size(), 1u);

  auto val = q.try_pop();
  ASSERT_TRUE(val.has_value());
  EXPECT_EQ(*val, 42);
  EXPECT_TRUE(q.empty());
}

TEST(SpscQueueTest, PopFromEmpty) {
  SpscQueue<int, 4> q;
  auto val = q.try_pop();
  EXPECT_FALSE(val.has_value());
}

TEST(SpscQueueTest, PushUntilFull) {
  SpscQueue<int, 4> q;  // capacity = 3 (N-1)
  EXPECT_EQ((SpscQueue<int, 4>::capacity()), 3u);

  EXPECT_TRUE(q.try_push(1));
  EXPECT_TRUE(q.try_push(2));
  EXPECT_TRUE(q.try_push(3));
  EXPECT_FALSE(q.try_push(4));  // Full
  EXPECT_EQ(q.size(), 3u);
}

TEST(SpscQueueTest, FIFOOrdering) {
  SpscQueue<int, 8> q;
  for (int i = 0; i < 7; ++i) {
    EXPECT_TRUE(q.try_push(i));
  }
  for (int i = 0; i < 7; ++i) {
    auto val = q.try_pop();
    ASSERT_TRUE(val.has_value());
    EXPECT_EQ(*val, i);
  }
}

TEST(SpscQueueTest, WrapAround) {
  SpscQueue<int, 4> q;
  // Fill and drain multiple times to force wrap-around
  for (int round = 0; round < 10; ++round) {
    EXPECT_TRUE(q.try_push(round * 10 + 1));
    EXPECT_TRUE(q.try_push(round * 10 + 2));

    auto v1 = q.try_pop();
    ASSERT_TRUE(v1.has_value());
    EXPECT_EQ(*v1, round * 10 + 1);

    auto v2 = q.try_pop();
    ASSERT_TRUE(v2.has_value());
    EXPECT_EQ(*v2, round * 10 + 2);
  }
}

TEST(SpscQueueTest, MoveSemantics) {
  SpscQueue<std::string, 4> q;
  std::string s = "hello";
  EXPECT_TRUE(q.try_push(std::move(s)));

  auto val = q.try_pop();
  ASSERT_TRUE(val.has_value());
  EXPECT_EQ(*val, "hello");
}

TEST(CommandQueueTest, VariantTypeDiscrimination) {
  CommandQueue q;

  // Push different command types
  EXPECT_TRUE(q.try_push(CreateLinkCmd{
      .output_port_id = 1, .input_port_id = 2, .request_id = 100}));
  EXPECT_TRUE(q.try_push(DestroyLinkCmd{.link_id = 5, .request_id = 101}));
  EXPECT_TRUE(
      q.try_push(SetParamCmd{.node_id = 3,
                             .param_json = R"({"key":"vol","value":0.5})",
                             .request_id = 102}));
  EXPECT_TRUE(q.try_push(EnumParamsCmd{.node_id = 7, .request_id = 103}));
  EXPECT_TRUE(q.try_push(GetSnapshotCmd{.request_id = 104}));
  EXPECT_TRUE(q.try_push(DisconnectCmd{}));

  // Pop and verify variant types
  {
    auto cmd = q.try_pop();
    ASSERT_TRUE(cmd.has_value());
    ASSERT_TRUE(std::holds_alternative<CreateLinkCmd>(*cmd));
    auto& c = std::get<CreateLinkCmd>(*cmd);
    EXPECT_EQ(c.output_port_id, 1u);
    EXPECT_EQ(c.input_port_id, 2u);
    EXPECT_EQ(c.request_id, 100);
  }
  {
    auto cmd = q.try_pop();
    ASSERT_TRUE(cmd.has_value());
    ASSERT_TRUE(std::holds_alternative<DestroyLinkCmd>(*cmd));
    EXPECT_EQ(std::get<DestroyLinkCmd>(*cmd).link_id, 5u);
  }
  {
    auto cmd = q.try_pop();
    ASSERT_TRUE(cmd.has_value());
    ASSERT_TRUE(std::holds_alternative<SetParamCmd>(*cmd));
    auto& c = std::get<SetParamCmd>(*cmd);
    EXPECT_EQ(c.node_id, 3u);
    EXPECT_EQ(c.param_json, R"({"key":"vol","value":0.5})");
  }
  {
    auto cmd = q.try_pop();
    ASSERT_TRUE(cmd.has_value());
    ASSERT_TRUE(std::holds_alternative<EnumParamsCmd>(*cmd));
  }
  {
    auto cmd = q.try_pop();
    ASSERT_TRUE(cmd.has_value());
    ASSERT_TRUE(std::holds_alternative<GetSnapshotCmd>(*cmd));
  }
  {
    auto cmd = q.try_pop();
    ASSERT_TRUE(cmd.has_value());
    ASSERT_TRUE(std::holds_alternative<DisconnectCmd>(*cmd));
  }
  // Queue should be empty now
  EXPECT_FALSE(q.try_pop().has_value());
}

TEST(SpscQueueTest, ConcurrentProducerConsumer) {
  constexpr int count = 100000;
  SpscQueue<int, 1024> q;
  std::vector<int> received;
  received.reserve(count);

  // Consumer thread
  std::thread consumer([&] {
    int remaining = count;
    while (remaining > 0) {
      if (auto val = q.try_pop()) {
        received.push_back(*val);
        --remaining;
      }
    }
  });

  // Producer thread (this thread)
  for (int i = 0; i < count; ++i) {
    while (!q.try_push(i)) {
      // Spin until space available
    }
  }

  consumer.join();

  // Verify FIFO ordering preserved under concurrency
  ASSERT_EQ(received.size(), static_cast<size_t>(count));
  for (int i = 0; i < count; ++i) {
    EXPECT_EQ(received[i], i);
  }
}
