## Notes

Managing dependencies...

```shell
bazel run -- @pnpm//:pnpm uninstall --dir $PWD --lockfile-only -D google-protobuf
```

```shell
bazel run -- @pnpm//:pnpm add grpc-web --dir $PWD
```