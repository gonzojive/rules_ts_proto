"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@bazel_tools//tools/build_defs/repo:git.bzl", _git_repository = "git_repository")

def http_archive(name, **kwargs):
    maybe(_http_archive, name = name, **kwargs)

def git_repository(name, **kwargs):
    maybe(_git_repository, name = name, **kwargs)

def local_repository(name, **kwargs):
    maybe(native.local_repository, name = name, **kwargs)

# WARNING: any changes in this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
# This is all fixed by bzlmod, so we just tolerate it for now.
def rules_ts_proto_dependencies():
    """Repositories required by rules_ts_proto."""

    # The minimal version of bazel_skylib we require
    http_archive(
        name = "bazel_skylib",
        sha256 = "f7be3474d42aae265405a592bb7da8e171919d74c16f082a5457840f06054728",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
        ],
    )

    git_repository(
        name = "rules_proto_grpc",
        commit = "44120f5fbd14da73009a102313e87316f5bf9ac3",
        remote = "https://github.com/gonzojive/rules_proto_grpc.git",
    )

    git_repository(
        name = "com_google_protobuf_javascript",
        commit = "dfa5a70a44926f183bdf4fd001dcca869a4f4ad6",
        remote = "https://github.com/gonzojive/protobuf-javascript.git",
    )

    http_archive(
        name = "rules_proto",
        sha256 = "dc3fb206a2cb3441b485eb1e423165b231235a1ea9b031b4433cf7bc1fa460dd",
        strip_prefix = "rules_proto-5.3.0-21.7",
        urls = [
            "https://github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
        ],
    )

    http_archive(
        name = "io_bazel_rules_go",
        sha256 = "56d8c5a5c91e1af73eca71a6fab2ced959b67c86d12ba37feedb0a2dfea441a6",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
        ],
    )

    http_archive(
        name = "aspect_bazel_lib",
        sha256 = "79623d656aa23ad3fd4692ab99786c613cd36e49f5566469ed97bc9b4c655f03",
        strip_prefix = "bazel-lib-1.23.3",
        url = "https://github.com/aspect-build/bazel-lib/archive/refs/tags/v1.23.3.tar.gz",
    )

    http_archive(
        name = "aspect_rules_js",
        sha256 = "9f51475dd2f99abb015939b1cf57ab5f15ef36ca6d2a67104450893fd0aa5c8b",
        strip_prefix = "rules_js-1.16.0",
        url = "https://github.com/aspect-build/rules_js/archive/refs/tags/v1.16.0.tar.gz",
    )

    # git_repository(
    #     name = "aspect_rules_js",
    #     commit = "fc9bd0cfc52d0cfbaf69538e6425094bb077afe9",
    #     remote = "https://github.com/gonzojive/rules_js.git",
    # )

    # Sometimes pushed to the reddaly-dev branch of
    # https://github.com/gonzojive/grpc-web.git
    # local_repository(
    #     name = "com_github_grpc_grpc_web",
    #     path = "/home/red/code/grpc-web",
    # )

    # https://github.com/aspect-build/rules_ts/releases/tag/v1.2.0
    http_archive(
        name = "aspect_rules_ts",
        sha256 = "acb20a4e41295d07441fa940c8da9fd02f8637391fd74a14300586a3ee244d59",
        strip_prefix = "rules_ts-1.2.0",
        url = "https://github.com/aspect-build/rules_ts/archive/refs/tags/v1.2.0.tar.gz",
    )

    # git_repository(
    #     name = "com_github_grpc_grpc_web",
    #     commit = "e49389873d887d15ab2870288f620aa2f15b3b85",
    #     remote = "https://github.com/grpc/grpc-web.git",
    # )

    git_repository(
        name = "com_github_grpc_grpc_web",
        commit = "f6eb07753a3d004ea0022eec541bed975e7fa0e8",
        remote = "https://github.com/gonzojive/grpc-web.git",
    )
