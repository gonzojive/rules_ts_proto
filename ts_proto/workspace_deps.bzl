"A function to call in WORKSPACE files for projects that use rules_ts_proto."

# Based on
# https://github.com/aspect-build/rules_js/blob/main/docs/faq.md#can-i-use-bazel-managed-pnpm
load("@aspect_rules_js//npm:npm_import.bzl", "npm_translate_lock", "pnpm_repository")

def install_rules_ts_proto():
    "Installs rules_ts_proto dependencies in the workspace after rules_ts_proto_dependencies."
    pnpm_repository(name = "pnpm")

    npm_translate_lock(
        name = "rules_ts_proto_npm",
        pnpm_lock = "@com_github_gonzojive_rules_ts_proto//:pnpm-lock.yaml",
        verify_node_modules_ignored = "@com_github_gonzojive_rules_ts_proto//:.bazelignore",
    )
