"""Define a ts_project library from a proto_library."""

load(
    "@rules_proto_grpc//:defs.bzl",
    "ProtoPluginInfo",
    "proto_compile_attrs",
    "proto_compile_impl",
)
load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@aspect_rules_js//js:libs.bzl", "js_library_lib")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@aspect_bazel_lib//lib:base64.bzl", "base64")

TsProtoInfo = provider(
    "Describes a generated proto library for TypeScript.",
    fields = {
        "proto_info": "ProtoInfo for the library.",
        "ts_proto_library_label": "Label of the ts_proto_library that produced the generated code.",
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
    # Generate a mapping from proto import path to JS import path.
    #
    # To do this, we need to get the primary_js_file for each proto
    # file in deps and figure out how it would be imported from
    # a .js file within the directory of the BUILD file where the
    # rule appears.

    generated_code_dir = paths.join(ctx.bin_dir.path, ctx.label.package)

    map_entries = [_import_map_entry(generated_code_dir, dep) for dep in ctx.attr.deps]
    map_entries = [x for x in map_entries if x != None]
    map_entries.append(_this_rule_import_map_entry(ctx))

    config_json = json.encode(struct(
        action_description = "Generating JS/TS code as part of {}".format(ctx.label),
        mapping_entries = map_entries,
    ))

    # Pass
    options = {
        Label("//ts_proto/codegen:delegating_plugin"): [
            "config=" + base64.encode(config_json),
        ],
    }

    # Execute with extracted attrs
    return proto_compile_impl(ctx, options_override = options)

def _this_rule_import_map_entry(ctx):
    """Returns an object that specifies how to import the current rule's messages.

    The returned struct must match the JSON spec in protoc_plugin.go.
    """
    proto_info = ctx.attr.protos[0][ProtoInfo]
    proto_filename = _import_paths_of_direct_sources(proto_info)[0]
    js_import = "./" + paths.basename(proto_filename).removesuffix(".proto") + "_pb"
    return struct(
        proto_import = proto_filename,
        js_import = js_import,
        ts_proto_library_label = _label_for_printing(ctx.label),
    )

def _import_map_entry(generated_code_dir, dep):
    """Returns an object that specifies how to import a dep.

    The returned struct must match the JSON spec in protoc_plugin.go.
    """
    if not (TsProtoInfo in dep):
        return None
    ts_proto_info = dep[TsProtoInfo]
    proto_info = ts_proto_info.proto_info
    relative_import = _relative_path_for_import(
        ts_proto_info.primary_js_file.path,
        generated_code_dir,
    )
    return struct(
        proto_import = _import_paths_of_direct_sources(proto_info)[0],
        js_import = relative_import,
        ts_proto_library_label = _label_for_printing(
            ts_proto_info.ts_proto_library_label,
        ),
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
                Label("//ts_proto/codegen:delegating_plugin"),
                # TODO(reddaly): Modify to use
                # https://github.com/protocolbuffers/protobuf-javascript
                # npm package: https://www.npmjs.com/package/google-protobuf
                #Label("//ts_proto/codegen:google_js_plugin"),

                # Generate type definitions for the generated .js code.
                #Label("//ts_proto/codegen:ts_protoc_gen_plugin"),

                # Generates gRPC-web code.
                #Label("//ts_proto/codegen:com_github_grpc_grpc_web"),
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
        if f.path.endswith("_pb.mjs") and not (f.path.endswith("grpc_web_pb.mjs"))
    ]
    if len(main_library_file) != 1:
        fail("expected exactly one file from {} to end in _pb.mjs, got {}: {}".format(
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
            ts_proto_library_label = ctx.label,
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
            providers = js_library_lib.provides,
            doc = "Label that provides JsInfo for the generated JavaScript for this rule.",
        ),
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
        #verbose = 4,
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
        _relative_path_for_import(src.path, proto_info.proto_source_root)
        for src in proto_info.direct_sources
    ]

# TODO: Come up with a principled way of deciding whether imports get a suffix or not.
_INCLUDE_SUFFIX_IN_IMPORT = False

def _relative_path_for_import(target, start):
    """JS import path to `target` from `start`.

    Args:
      target: path that we want to get relative path to.
      start: path to directory from which we are starting.

    Returns:
      string: relative path to `target`.
    """
    p = _relative_path(target, start)
    if p.endswith(".mjs"):
        p = p.removesuffix(".mjs") + ".js"
    if p.endswith(".cjs"):
        p = p.removesuffix(".cjs") + ".js"

    if not _INCLUDE_SUFFIX_IN_IMPORT:
        p = p.removesuffix(".js")

    return p

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
    if len(result) == 1:
        result = ["."] + result

    return "/".join(result) if len(result) > 0 else "."

def _label_for_printing(label):
    return "{}".format(label)
