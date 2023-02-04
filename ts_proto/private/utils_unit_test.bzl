load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":utils.bzl", "relative_path")

# Unit tests based on
# https://bazel.build/rules/testing#testing-starlark-utilities

def _myhelper_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "./bar.xyz", relative_path("foo/bar.xyz", "foo"))
    asserts.equals(env, "./bar.xyz", relative_path("foo/bar.xyz", "foo/"))
    asserts.equals(env, "./bar.xyz", relative_path("foo/bar.xyz/", "foo/"))
    return unittest.end(env)

myhelper_test = unittest.make(_myhelper_test_impl)

# No need for a test_myhelper() setup function.

def myhelpers_test_suite(name):
    # unittest.suite() takes care of instantiating the testing rules and creating
    # a test_suite.
    unittest.suite(
        name,
        myhelper_test,
    )
