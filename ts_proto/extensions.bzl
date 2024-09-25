"""Extensions for bzlmod."""

dep_config = tag_class(attrs = {
    "js_import": attr.string(doc = """\
One of "grpc-web", "google-protobuf", "@types/google-protobuf".
""", mandatory = True),

    "ts_project_dep": attr.label(
        doc = "Dependency to add to a generated ts_project for this dependency.",
        mandatory = True,
    ),
})

def _my_extension(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            if toolchain.name != _DEFAULT_NAME and not mod.is_root:
                fail("""\
                Only the root module may override the default name for the mylang toolchain.
                This prevents conflicting registrations in the global namespace of external repos.
                """)
            if toolchain.name not in registrations.keys():
                registrations[toolchain.name] = []
            registrations[toolchain.name].append(toolchain.mylang_version)
    for name, versions in registrations.items():
        if len(versions) > 1:
            # TODO: should be semver-aware, using MVS
            selected = sorted(versions, reverse = True)[0]

            # buildifier: disable=print
            print("NOTE: mylang toolchain {} has multiple versions {}, selected {}".format(name, versions, selected))
        else:
            selected = versions[0]

        mylang_register_toolchains(
            name = name,
            mylang_version = selected,
            register = False,
        )

ts_proto_config = module_extension(
    implementation = _my_extension,
    tag_classes = {"implicit_dep": dep_config},
)
