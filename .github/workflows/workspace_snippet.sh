#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
PREFIX="rules_ts_proto-${TAG:1}"
SHA=$(git archive --format=tar --prefix=${PREFIX}/ ${TAG} | gzip | shasum -a 256 | awk '{print $1}')

cat << EOF
WORKSPACE snippet:
\`\`\`starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "com_github_gonzojive_rules_ts_proto",
    sha256 = "${SHA}",
    strip_prefix = "${PREFIX}",
    url = "https://github.com/gonzojive/rules_ts_proto/archive/refs/tags/${TAG}.tar.gz",
)
EOF

awk 'f;/--SNIP--/{f=1}' e2e/workspace/WORKSPACE
echo "\`\`\`" 
