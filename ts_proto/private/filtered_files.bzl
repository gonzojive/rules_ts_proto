"""A rule for filtering a set of source files by filename patterns."""

def _filtered_files_impl(ctx):
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
        fail("expected exactly one file from {} to end in _pb.mjs, got {}: {} from {}".format(
            ctx.attr.js_library,
            len(main_library_file),
            main_library_file,
            js_library_files,
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

filtered_files = rule(
    implementation = _filtered_files_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            providers = [DefaultInfo],
            doc = "Source files to filter.",
            allow_files = True,
        ),
        "filter": attr.string(
            mandatory = True,
            doc = "What type of files to allow through the filter. Must be 'ts'.",
        ),
        "invert": attr.bool(
            mandatory = False,
            default = False,
            doc = "If true, inverts the filter logic.",
        ),
    },
    toolchains = [],
    provides = [DefaultInfo],
)
