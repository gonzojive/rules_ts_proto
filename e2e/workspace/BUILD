"""Provides a simple way test of ts_proto_library."""

load("@rules_proto//proto:defs.bzl", "proto_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_gazelle//:def.bzl", "gazelle")
load("@com_github_gonzojive_rules_ts_proto//ts_proto:defs.bzl", "ts_proto_library")

# Replace with a usage of your rule/macro
filegroup(name = "empty")

build_test(
    name = "smoke_test",
    targets = [
        # targets you add above
        ":empty",
    ],
)

# gazelle:prefix github.com/gonzojive/rules_ts_proto/e2e/workspace
# gazelle:go_generate_proto false
gazelle(name = "gazelle")

proto_library(
    name = "com_example_greeting_v1_proto",
    srcs = ["greeting.proto"],
    visibility = ["//visibility:public"],
)

ts_proto_library(
    name = "flub",
    proto = ":com_example_greeting_v1_proto",
    visibility = ["//visibility:public"],
)
