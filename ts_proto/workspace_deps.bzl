"A function to call in WORKSPACE files for projects that use rules_ts_proto."

# Based on
# https://github.com/aspect-build/rules_js/blob/main/docs/faq.md#can-i-use-bazel-managed-pnpm
load("@aspect_rules_js//npm:npm_import.bzl", "npm_translate_lock", "pnpm_repository")

_REQUIRED_NPM_PACKAGE_NAMES = ["google-protobuf", "@types/google-protobuf"]

def _config_bzl_contents(js_import_bazel_target_map):
    missing_keys = [
        required_key
        for required_key in _REQUIRED_NPM_PACKAGE_NAMES
        if required_key not in js_import_bazel_target_map
    ]

    if len(missing_keys) > 0:
        fail("js_import_bazel_target_map dictionary is missing {n} required keys: {keys}".format(
            n = len(missing_keys),
            keys = missing_keys,
        ))

    return """

JS_IMPORT_BAZEL_TARGET_MAP = {map}

""".format(map = json.encode(js_import_bazel_target_map))

def _config_repository_impl(repo_ctx):
    repo_ctx.file("ts_proto_library_config.bzl", repo_ctx.attr.bzl_contents)
    repo_ctx.file("BUILD.bazel", """
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

bzl_library(
    name = "ts_proto_library_config",
    srcs = ["ts_proto_library_config.bzl"],
    visibility = ["{rules_ts_proto_repo}//:__subpackages__"],
)
""".format(
        rules_ts_proto_repo = repo_ctx.attr.rules_ts_proto_repo_only_for_internal_use,
    ))

_config_repository = repository_rule(
    _config_repository_impl,
    attrs = {
        "rules_ts_proto_repo_only_for_internal_use": attr.string(
            default = "@com_github_gonzojive_rules_ts_proto",
        ),
        "bzl_contents": attr.string(
            doc = "Contents of the ts_proto_library_config.bzl file to generate.",
            mandatory = True,
        ),
    },
)

def install_rules_ts_proto(dep_targets = None):
    """Installs rules_ts_proto dependencies in the workspace after rules_ts_proto_dependencies.

    Args:
        dep_targets: A dictionary from NPM package name to a target that supplies that
            dependency. Required keys in the dictionary are "google-protobuf",
            "@types/google-protobuf". A typical value for this attribute is {
                "google-protobuf": "//:node_modules/google-protobuf",
                "@types/google-protobuf": "//:node_modules/@types/google-protobuf",
            }
    """
    if type(dep_targets) != "dict":
        fail("dep_targets attribute must be a dictionary, got {}".format(type(dep_targets)))

    pnpm_repository(name = "pnpm")

    npm_translate_lock(
        name = "rules_ts_proto_npm",
        pnpm_lock = "@com_github_gonzojive_rules_ts_proto//:pnpm-lock.yaml",
        verify_node_modules_ignored = "@com_github_gonzojive_rules_ts_proto//:.bazelignore",
    )

    _config_repository(
        name = "com_github_gonzojive_rules_ts_proto_config",
        bzl_contents = _config_bzl_contents(dep_targets),
    )
