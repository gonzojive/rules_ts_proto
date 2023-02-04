"""A rule for filtering a set of source files by filename patterns."""

def _filtered_files_impl(ctx):
    """Implementation function for ts_proto_library_rule.

    Args:
        ctx: The Bazel rule execution context object.

    Returns:
        Providers:
            - DefaultInfo
    """

    # Could probably also use ctx.attr.js_library[DefaultInfo].files.to_list()
    all_files = []
    for src in ctx.attr.srcs:
        all_files += src[DefaultInfo].files.to_list()

    def filter(f):
        passed = True
        if ctx.attr.filter == "ts":
            passed = f.path.endswith(".ts")
        if ctx.attr.invert:
            passed = not passed
        return passed

    passed_files = [
        f
        for f in all_files
        if filter(f)
    ]

    return [
        DefaultInfo(
            files = depset(direct = passed_files),
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
