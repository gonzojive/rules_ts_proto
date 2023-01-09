"""Define a ts_project library from a proto_library."""

load(
    "@rules_proto_grpc//:defs.bzl",
    "ProtoPluginInfo",
    "proto_compile_attrs",
    "proto_compile_impl",
)
#load("@aspect_rules_js//npm:defs.bzl", "npm_package")

#load("//bazel:mgh_ts_library.bzl", "ts_library")
load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@aspect_rules_js//js:libs.bzl", "js_library_lib")
load("@bazel_skylib//lib:paths.bzl", "paths")

TsProtoInfo = provider(
    "Describes a generated proto library for TypeScript.",
    fields = {
        "proto_info": "ProtoInfo for the library.",
        #"js_info": "JsInfo for the library",
        "primary_js_file": "JavaScript file that should be imported when depending on this library to import messages, enums, etc.",
        "grpc_web_js_file": "JavaScript file that should be imported when depending on this library to import messages, enums, etc.",
        #"ts_proto_info_deps": "depset of TsProtoInfos needed by this library",
    },
)

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

    # Generate a mapping from proto import path to JS import path.
    #
    # To do this, we need to get the primary_js_file for each proto
    # file in deps and figure out how it would be imported from
    # a .js file within the directory of the BUILD file where the
    # rule appears.

    generated_code_dir = paths.join(ctx.bin_dir.path, ctx.label.package)

    map_entries = [_import_map_entry(dep) for dep in ctx.attr.deps]
    map_entries = [x for x in map_entries if x != None]

    if len(map_entries) == 1:
        fail("got map entries {}.... from ctx with generated_code_dir {}".format(
            map_entries,
            generated_code_dir,
        ))

    # js_library_files = ctx.attr.js_library[JsInfo].sources.to_list()

    # Build a map of proto file to

    return proto_compile_impl(ctx, base_env = base_env)

def _import_map_entry(dep):
    #if not (TsProtoInfo in dep):
    #    return None
    ts_proto_info = dep[TsProtoInfo]
    proto_info = ts_proto_info.proto_info
    relative_import = _relative_path(
        ts_proto_info.primary_js_file.path,
        generated_code_dir,
    )
    return struct(
        proto_import_path = _import_paths_of_direct_sources(proto_info)[0],
        js_import_path = relative_import,
    )

# based on https://github.com/aspect-build/rules_js/issues/397
_google_js_plugin_compile = rule(
    implementation = _google_js_plugin_compile_impl,
    attrs = dict(
        proto_compile_attrs,
        deps = attr.label_list(
            # see
            providers = [
                # ts_proto_library deps should be be used to provide the mapping
                # from proto file -> generated js file.
                #
                # The ts_proto_library rule provide everything that js_library
                # does and the TsProtoInfo provider.
                [TsProtoInfo] + js_library_lib.provides,

                # js_library deps are permitted.
                js_library_lib.provides,
            ],
            doc = "js_library and ts_proto_library dependencies",
        ),
        _plugins = attr.label_list(
            providers = [ProtoPluginInfo],
            default = [
                # TODO(reddaly): Modify to use
                # https://github.com/protocolbuffers/protobuf-javascript
                # npm package: https://www.npmjs.com/package/google-protobuf
                Label("//ts_proto/codegen:google_js_plugin"),

                # Generate type definitions for the generated .js code.
                Label("//ts_proto/codegen:ts_protoc_gen_plugin"),

                # Generates gRPC-web code.
                Label("//ts_proto/codegen:com_github_grpc_grpc_web"),
            ],
            doc = "List of protoc plugins to apply",
        ),
    ),
    toolchains = [
        str(Label("@rules_proto_grpc//protobuf:toolchain_type")),
    ],
)

def _ts_proto_library_rule_impl(ctx):
    """Implementation function for ts_proto_library_rule.

    Args:
        ctx: The Bazel rule execution context object.

    Returns:
        Providers:
            - ProtoCompileInfo
            - DefaultInfo
    """

    # Could probably also use ctx.attr.js_library[DefaultInfo].files.to_list()
    js_library_files = ctx.attr.js_library[DefaultInfo].files.to_list()

    main_library_file = [
        f
        for f in js_library_files
        if f.path.endswith("_pb.js") and not (f.path.endswith("grpc_web_pb.js"))
    ]
    if len(main_library_file) != 1:
        fail("expected exactly one file from {} to end in _pb.js, got {}: {}".format(
            ctx.attr.js_library,
            len(main_library_file),
            main_library_file,
        ))
    main_library_file = main_library_file[0]

    grpc_web_library_file = [
        f
        for f in js_library_files
        if f.path.endswith("_grpc_web_pb.js")
    ]
    if len(grpc_web_library_file) != 1:
        fail("expected exactly one file from {} to end in _pb.js, got {}: {}".format(
            ctx.attr.js_library,
            len(grpc_web_library_file),
            grpc_web_library_file,
        ))
    grpc_web_library_file = grpc_web_library_file[0]

    proto_info = ctx.attr.proto[ProtoInfo]
    if len(proto_info.direct_sources) != 1:
        fail(
            "expected proto_library {} to have exactly 1 srcs, got {}: {}",
            ctx.attr.proto,
            len(proto_info.direct_sources),
            proto_info.direct_sources,
        )

    return [
        # Provide everything from the js_library of generated files.
        ctx.attr.js_library[provider]
        for provider in js_library_lib.provides
    ] + [
        # Also provide TsProtoInfo.
        TsProtoInfo(
            proto_info = ctx.attr.proto[ProtoInfo],
            #js_info = ctx.attr.js_library[JsInfo],
            primary_js_file = main_library_file,
            grpc_web_js_file = grpc_web_library_file,
        ),
    ]

# based on https://github.com/aspect-build/rules_js/issues/397
_ts_proto_library_rule = rule(
    implementation = _ts_proto_library_rule_impl,
    attrs = {
        "proto": attr.label(
            mandatory = True,
            providers = [ProtoInfo],
            doc = "Label that that provides ProtoInfo such as proto_library from rules_proto.",
        ),
        "js_library": attr.label(
            mandatory = True,
            providers = [DefaultInfo, JsInfo],
            doc = "Label that provides JsInfo for the generated JavaScript for this rule.",
        ),
        # "js_library": attr.label_list(
        #     mandatory = True,
        #     providers = [JsInfo],
        #     doc = "Label that provides JsInfo for the generated JavaScript for this rule.",
        # ),
        # "options": attr.string_list_dict(
        #     doc = "Extra options to pass to plugins, as a dict of plugin label -> list of strings. The key * can be used exclusively to apply to all plugins",
        # ),
        # "verbose": attr.int(
        #     doc = "The verbosity level. Supported values and results are 0: Show nothing, 1: Show command, 2: Show command and sandbox after running protoc, 3: Show command and sandbox before and after running protoc, 4. Show env, command, expected outputs and sandbox before and after running protoc",
        # ),
        # "prefix_path": attr.string(
        #     doc = "Path to prefix to the generated files in the output directory",
        # ),
        # "extra_protoc_args": attr.string_list(
        #     doc = "A list of extra args to pass directly to protoc, not as plugin options",
        # ),
        # "extra_protoc_files": attr.label_list(
        #     allow_files = True,
        #     doc = "List of labels that provide extra files to be available during protoc execution",
        # ),
        # "output_mode": attr.string(
        #     default = "PREFIXED",
        #     values = ["PREFIXED", "NO_PREFIX", "NO_PREFIX_FLAT"],
        #     doc = "The output mode for the target. PREFIXED (the default) will output to a directory named by the target within the current package root, NO_PREFIX will output files directly to the current package, NO_PREFIX_FLAT will ouput directly to the current package without mirroring the package tree. Using NO_PREFIX may lead to conflicting writes",
        # ),
    },
    toolchains = [],
    provides = [TsProtoInfo] + js_library_lib.provides,
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
        # visibility = visibility,
        verbose = 4,
        deps = deps,
        output_mode = "NO_PREFIX_FLAT",
    )

    implicit_deps = [
        "@com_github_gonzojive_rules_ts_proto//:node_modules/@types/google-protobuf",
        "@com_github_gonzojive_rules_ts_proto//:node_modules/google-protobuf",
    ]
    deps = [x for x in deps]
    for want_dep in implicit_deps:
        if want_dep not in deps:
            deps.append(want_dep)

    js_library(
        name = name + "_lib",
        srcs = [
            name + "_compile",
        ],
        deps = deps,
        visibility = visibility,
    )

    _ts_proto_library_rule(
        name = name,
        proto = proto,
        js_library = name + "_lib",
        visibility = visibility,
    )

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

def _import_paths_of_direct_sources(proto_info):
    """Extracts the path used to import srcs of ProtoInfo.

    Args:
        proto_info: A ProtoInfo instance.

    Returns:
        A list of strings with import paths
    """
    return [
        # TODO(reddaly): This won't work on windows.
        paths.relativize(src.path, proto_info.proto_source_root)
        for src in proto_info.direct_sources
    ]

# From skylib pull request.
# https://github.com/bazelbuild/bazel-skylib/pull/44/files
def _relative_path(target, start):
    """Returns a relative path to `target` from `start`.

    Args:
      target: path that we want to get relative path to.
      start: path to directory from which we are starting.
    Returns:
      string: relative path to `target`.
    """
    t_pieces = target.split("/")
    s_pieces = start.split("/")
    common_part_len = 0

    for tp, rp in zip(t_pieces, s_pieces):
        if tp == rp:
            common_part_len += 1
        else:
            break

    result = [".."] * (len(s_pieces) - common_part_len)
    result += t_pieces[common_part_len:]

    return "/".join(result) if len(result) > 0 else "."
