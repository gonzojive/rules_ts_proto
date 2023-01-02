"""Define a ts_project library from a proto_library."""

load(
    "@rules_proto_grpc//:defs.bzl",
    "ProtoPluginInfo",
    "proto_compile_attrs",
    "proto_compile_impl",
)
#load("@aspect_rules_js//npm:defs.bzl", "npm_package")

#load("//bazel:mgh_ts_library.bzl", "ts_library")
# load("@aspect_rules_js//js:defs.bzl", "js_library")

def _google_js_plugin_compile_impl(ctx):
    """Implementation function for google_js_plugin_compile.

    Args:
        ctx: The Bazel rule execution context object.

    Returns:
        Providers:
            - ProtoCompileInfo
            - DefaultInfo
    """
    base_env = {
        # Make up for https://github.com/bazelbuild/bazel/issues/15470.
        "BAZEL_BINDIR": ctx.bin_dir.path,
    }
    return proto_compile_impl(ctx, base_env = base_env)

# based on https://github.com/aspect-build/rules_js/issues/397
_google_js_plugin_compile = rule(
    implementation = _google_js_plugin_compile_impl,
    attrs = dict(
        proto_compile_attrs,
        _plugins = attr.label_list(
            providers = [ProtoPluginInfo],
            default = [
                # TODO(reddaly): Modify to use
                # https://github.com/protocolbuffers/protobuf-javascript
                # npm package: https://www.npmjs.com/package/google-protobuf
                Label("//ts_proto/codegen:google_js_plugin"),

                # Generate type definitions for the generated .js code.
                Label("//ts_proto/codegen:ts_protoc_gen_plugin"),
            ],
            doc = "List of protoc plugins to apply",
        ),
    ),
    toolchains = [
        str(Label("@rules_proto_grpc//protobuf:toolchain_type")),
    ],
)

def ts_proto_library(name, proto, visibility = None, deps = []):
    """A rule for compiling protobufs into a ts_project.

    Args:
        name: Name of the ts_project to produce.
        proto: proto_library rule to compile.
        visibility: Visibility of output library.
        deps: TypeScript dependencies.
    """

    _google_js_plugin_compile(
        name = name + "_compile",
        protos = [
            proto,
        ],
        visibility = visibility,
        verbose = 4,
    )

    # implicit_deps = [
    #     "//:node_modules/@types/google-protobuf",
    #     "//:node_modules/google-protobuf",
    # ]
    # deps = [x for x in deps]
    # for want_dep in implicit_deps:
    #     if want_dep not in deps:
    #         deps.append(want_dep)

    # js_library(
    #     name = name + "_lib",
    #     srcs = [
    #         name + "_uber",
    #     ],
    #     deps = deps,
    #     visibility = visibility,
    # )

    # # TypeScript import resolution description:
    # # https://www.typescriptlang.org/docs/handbook/module-resolution.html
    # npm_package(
    #     name = name + "_npm",
    #     srcs = [
    #         name,
    #     ],
    #     root_paths = [
    #         #name + "_uber",
    #         ".",
    #     ],
    #     visibility = visibility,
    # )

    # _protobuf_ts_compile(
    #     name = name + "_protobuf_ts",
    #     protos = [proto],
    #     visibility = visibility,
    #     verbose = 4,
    # )

    # _ts_unofficial_compile(
    #     name = name + "_ts_unofficial",
    #     protos = [proto],
    #     visibility = visibility,
    #     verbose = 4,
    # )
