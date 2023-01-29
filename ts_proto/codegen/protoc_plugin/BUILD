load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "protoc_plugin_lib",
    srcs = ["protoc_plugin.go"],
    data = [
        "//ts_proto/codegen:protoc-gen-ts",
        "@com_github_grpc_grpc_web//javascript/net/grpc/web/generator:protoc-gen-grpc-web",
        "@com_google_protobuf_javascript//generator:protoc-gen-js",
    ],
    importpath = "github.com/gonzojive/rules_ts_proto/ts_proto/codegen/protoc_plugin",
    visibility = ["//visibility:private"],
    deps = [
        "@com_github_golang_glog//:go_default_library",
        "@io_bazel_rules_go//go/runfiles:go_default_library",
        "@org_golang_google_protobuf//proto:go_default_library",
        "@org_golang_google_protobuf//types/pluginpb:go_default_library",
    ],
)

go_binary(
    name = "protoc_plugin",
    embed = [":protoc_plugin_lib"],
    visibility = ["//visibility:public"],
)
