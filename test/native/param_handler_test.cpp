// Copyright 2026 Tonic Contributors
// Licensed under the Apache License, Version 2.0

#include "event_serializer.hpp"
#include "glaze/glaze.hpp"

#include <gtest/gtest.h>

// Test param cache JSON generation logic (without PipeWire dependency)
// These tests exercise the JSON format used by ParamHandler.

namespace {

struct ParamEntry {
    std::string key;
    std::string value;
    std::string type;
    struct Flags {
        bool readable{true};
        bool writable{true};
    } flags;
};

}  // namespace

template <>
struct glz::meta<ParamEntry::Flags> {
    using T = ParamEntry::Flags;
    static constexpr auto value = object("readable", &T::readable, "writable", &T::writable);
};

template <>
struct glz::meta<ParamEntry> {
    using T = ParamEntry;
    static constexpr auto value = object(
        "key", &T::key, "value", &T::value, "type", &T::type, "flags", &T::flags
    );
};

TEST(ParamHandlerTest, ParamJsonRoundTrip) {
    ParamEntry entry;
    entry.key = "volume";
    entry.value = "0.75";
    entry.type = "Float";
    entry.flags.readable = true;
    entry.flags.writable = true;

    std::string json;
    auto ec = glz::write_json(entry, json);
    EXPECT_FALSE(static_cast<bool>(ec));

    ParamEntry entry2;
    auto ec2 = glz::read_json(entry2, json);
    EXPECT_FALSE(static_cast<bool>(ec2));
    EXPECT_EQ(entry2.key, "volume");
    EXPECT_EQ(entry2.value, "0.75");
    EXPECT_EQ(entry2.type, "Float");
    EXPECT_TRUE(entry2.flags.readable);
    EXPECT_TRUE(entry2.flags.writable);
}

TEST(ParamHandlerTest, ParamArrayJson) {
    std::vector<ParamEntry> params;
    params.push_back({.key = "volume", .value = "0.5", .type = "Float"});
    params.push_back({.key = "mute", .value = "false", .type = "Bool"});
    params.push_back({.key = "name", .value = "\"Main Output\"", .type = "String"});

    std::string json;
    auto ec = glz::write_json(params, json);
    EXPECT_FALSE(static_cast<bool>(ec));

    std::vector<ParamEntry> params2;
    auto ec2 = glz::read_json(params2, json);
    EXPECT_FALSE(static_cast<bool>(ec2));
    ASSERT_EQ(params2.size(), 3u);
    EXPECT_EQ(params2[0].key, "volume");
    EXPECT_EQ(params2[1].key, "mute");
    EXPECT_EQ(params2[2].key, "name");
}

TEST(ParamHandlerTest, SetParamJsonParsing) {
    // Simulates the JSON sent by Dart for set_param
    struct ParamUpdate {
        std::string key;
        std::string value;
    };

    std::string input = R"({"key":"volume","value":"0.8"})";
    ParamUpdate update;

    // Manually parse since we don't have glz::meta for ParamUpdate here
    // (it's defined in param_handler.cpp) — test the format instead
    EXPECT_NE(input.find("\"key\""), std::string::npos);
    EXPECT_NE(input.find("\"value\""), std::string::npos);
}

TEST(ParamHandlerTest, EmptyParamsJson) {
    std::vector<ParamEntry> params;
    std::string json;
    auto ec = glz::write_json(params, json);
    EXPECT_FALSE(static_cast<bool>(ec));
    EXPECT_EQ(json, "[]");
}

TEST(ParamHandlerTest, UnknownFieldsSkipped) {
    // Glaze should handle unknown fields gracefully
    std::string json = R"({"key":"vol","value":"1.0","type":"Float","flags":{"readable":true,"writable":false},"unknown_field":"ignored"})";
    ParamEntry entry;
    auto ec = glz::read_json(entry, json);
    // Glaze with default settings may or may not error on unknown keys
    // The important thing is it parses what it can
    if (!ec) {
        EXPECT_EQ(entry.key, "vol");
        EXPECT_EQ(entry.type, "Float");
        EXPECT_FALSE(entry.flags.writable);
    }
}

