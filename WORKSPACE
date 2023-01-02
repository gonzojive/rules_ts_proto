# Declare the local Bazel workspace.
workspace(
    # If your ruleset is "official"
    # (i.e. is in the bazelbuild GitHub org)
    # then this should just be named "rules_ts_proto"
    # see https://docs.bazel.build/versions/main/skylark/deploying.html#workspace
    name = "com_github_gonzojive_rules_ts_proto",
)

load(":internal_deps.bzl", "rules_ts_proto_internal_deps")

# Fetch deps needed only locally for development
rules_ts_proto_internal_deps()

load("//ts_proto:repositories.bzl", "rules_ts_proto_dependencies")

# Fetch dependencies which users need as well
rules_ts_proto_dependencies()

# For running our own unit tests
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

############################################
# Gazelle, for generating bzl_library targets
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.19.3")

gazelle_dependencies()

############################################
# rules_proto

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

rules_proto_dependencies()

rules_proto_toolchains()

# From https://github.com/aspect-build/rules_js/releases/tag/v1.13.0
load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@rules_nodejs//nodejs:repositories.bzl", "DEFAULT_NODE_VERSION", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "nodejs",
    node_version = DEFAULT_NODE_VERSION,
)

# Based on
# https://github.com/aspect-build/rules_js/blob/main/docs/faq.md#can-i-use-bazel-managed-pnpm
load("@aspect_rules_js//npm:npm_import.bzl", "pnpm_repository")

pnpm_repository(name = "pnpm")

# load("@aspect_rules_js//npm:npm_import.bzl", "npm_translate_lock")

# npm_translate_lock(
#     name = "npm",
#     pnpm_lock = "//:pnpm-lock.yaml",
#     verify_node_modules_ignored = "//:.bazelignore",
# )

# load("@npm//:repositories.bzl", "npm_repositories")

# npm_repositories()
