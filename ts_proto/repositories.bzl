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
        commit = "b9e6b2922d8b6177d0747f30b738ea467161fc33",
        remote = "https://github.com/gonzojive/rules_proto_grpc.git",
    )

    local_repository(
        name = "com_google_protobuf_javascript",
        path = "/home/red/code/protobuf-javascript",
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
        name = "aspect_rules_js",
        sha256 = "66ecc9f56300dd63fb86f11cfa1e8affcaa42d5300e2746dba08541916e913fd",
        strip_prefix = "rules_js-1.13.0",
        url = "https://github.com/aspect-build/rules_js/archive/refs/tags/v1.13.0.tar.gz",
    )

    local_repository(
        name = "com_github_grpc_grpc_web",
        path = "/home/red/code/grpc-web",
    )

    # git_repository(
    #     name = "com_github_grpc_grpc_web",
    #     commit = "e49389873d887d15ab2870288f620aa2f15b3b85",
    #     remote = "https://github.com/grpc/grpc-web.git",
    # )
