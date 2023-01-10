package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"

	"github.com/bazelbuild/rules_go/go/runfiles"
	"github.com/golang/glog"
	"github.com/golang/protobuf/proto"

	"google.golang.org/protobuf/encoding/prototext"
	pbplugin "google.golang.org/protobuf/types/pluginpb"
)

const (
	tsDefsRunfilesPath  = "com_github_gonzojive_rules_ts_proto/ts_proto/codegen/protoc-gen-ts.sh"
	genJSRunfilesPath   = "com_google_protobuf_javascript/generator/protoc-gen-js"
	grpcWebRunfilesPath = "com_github_grpc_grpc_web/javascript/net/grpc/web/generator/protoc-gen-grpc-web"

	// Env variable needed by the tsDefsRunfilesPath binary.
	bazelBinDirVar = "BAZEL_BINDIR"
)

func main() {
	flag.Set("alsologtostderr", "true")
	flag.Parse()
	if err := run(context.Background()); err != nil {
		glog.Exitf("error running application:\n  %v", err)
	}
}

func run(ctx context.Context) error {
	bazelBinDir := os.Getenv(bazelBinDirVar)
	if bazelBinDir == "" {
		return fmt.Errorf("invalid environment: Missing %q; env:\n  %s", bazelBinDirVar, strings.Join(os.Environ(), "\n  "))
	}
	// Read CodeGeneratorRequest from stdin per
	// https://developers.google.com/protocol-buffers/docs/reference/other.
	reqBytes, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		return fmt.Errorf("error reading from stdin: %w", err)
	}
	req := &pbplugin.CodeGeneratorRequest{}
	if err := proto.Unmarshal(reqBytes, req); err != nil {
		return fmt.Errorf("error reading CodeGeneratorRequest: %w", err)
	}
	plugin, err := loadUberPlugin()
	if err != nil {
		return err
	}
	resp, err := plugin.generateCode(ctx, req)
	if err != nil {
		return fmt.Errorf("error fulfiling request: %w", err)
	}
	outbytes, err := proto.Marshal(resp)
	if err != nil {
		return fmt.Errorf("error marshaling proto: %w", err)
	}
	if _, err := os.Stdout.Write(outbytes); err != nil {
		return fmt.Errorf("error writing bytes to stdout: %w", err)
	}
	return nil
}

type uberPlugin struct {
	genJSPluginPath, genTSDefsPluginPath, genGRPCPluginPath string
}

func loadUberPlugin() (*uberPlugin, error) {
	out := &uberPlugin{}
	{
		var err error
		out.genTSDefsPluginPath, err = runfiles.Rlocation(tsDefsRunfilesPath)
		if err != nil {
			return nil, fmt.Errorf("error locating runfile: %w; env = %+v, args = %v", err, os.Environ(), os.Args)
		}
	}
	{
		var err error
		out.genJSPluginPath, err = runfiles.Rlocation(genJSRunfilesPath)
		if err != nil {
			return nil, err
		}
	}
	{
		var err error
		out.genGRPCPluginPath, err = runfiles.Rlocation(grpcWebRunfilesPath)
		if err != nil {
			return nil, err
		}
	}
	return out, nil
}

func (up *uberPlugin) generateCode(ctx context.Context, req *pbplugin.CodeGeneratorRequest) (*pbplugin.CodeGeneratorResponse, error) {
	runPluginWithParameter := func(toolPath, param string, postProcessors ...func(req *pbplugin.CodeGeneratorRequest, resp *pbplugin.CodeGeneratorResponse) error) (*pbplugin.CodeGeneratorResponse, error) {
		req := cloneProto(req)
		req.Parameter = proto.String(param)
		resp, err := runPlugin(ctx, toolPath, req)
		if err != nil {
			return nil, err
		}
		for i, proc := range postProcessors {
			if err := proc(req, resp); err != nil {
				return nil, fmt.Errorf("error with post-processor[%d]: %w", i, err)
			}
		}
		return resp, nil
	}
	defsResp, err := runPluginWithParameter(up.genTSDefsPluginPath, "")
	if err != nil {
		return nil, fmt.Errorf("error running ts definition codegen plugin: %w", err)
	}

	jsResp, err := runPluginWithParameter(up.genJSPluginPath, "import_style=es6,binary")
	if err != nil {
		return nil, fmt.Errorf("error running ts definition codegen plugin: %w", err)
	}

	grpcResp, err := runPluginWithParameter(up.genGRPCPluginPath, "import_style=commonjs+dts,mode=grpcweb", processGRPCResponse)
	if err != nil {
		return nil, fmt.Errorf("error running grpc definition codegen plugin: %w", err)
	}

	glog.Infof("got jsResp\n====================\n%s", prototext.Format(jsResp))
	glog.Infof("got defsResp\n====================\n%s", prototext.Format(defsResp))
	glog.Infof("got grpcResp\n====================\n%s", prototext.Format(grpcResp))

	errorField := ""
	if jsResp.GetError() != "" {
		errorField += fmt.Sprintf("JS code generation error: %s", jsResp.GetError())
	}
	if defsResp.GetError() != "" {
		errorField += fmt.Sprintf("Typescript definition code generation error: %s", jsResp.GetError())
	}
	if errorField != "" {
		return &pbplugin.CodeGeneratorResponse{
			Error: proto.String(errorField),
		}, nil
	}
	var files []*pbplugin.CodeGeneratorResponse_File
	files = append(files, jsResp.GetFile()...)
	files = append(files, defsResp.GetFile()...)
	files = append(files, grpcResp.GetFile()...)

	glog.Infof("output files: %s", mapSlice(files, func(f *pbplugin.CodeGeneratorResponse_File) string {
		return f.GetName()
	}))

	return &pbplugin.CodeGeneratorResponse{
		SupportedFeatures: proto.Uint64(jsResp.GetSupportedFeatures()),
		File:              files,
	}, nil
}

func mapSlice[T, R any](s []T, f func(elem T) R) []R {
	var out []R
	for _, x := range s {
		out = append(out, f(x))
	}
	return out
}

func processGRPCResponse(req *pbplugin.CodeGeneratorRequest, resp *pbplugin.CodeGeneratorResponse) error {
	// Rename the _pb.ts.d file because it conflicts with the output of the
	// ts-gen-protoc plugin. We still output the file simply for debugging
	// purposes.
	filenames := map[string]bool{}
	for _, f := range resp.GetFile() {
		filenames[f.GetName()] = true
		if strings.HasSuffix(f.GetName(), "_pb.d.ts") && !strings.HasSuffix(f.GetName(), "grpc_web_pb.d.ts") {
			*f.Name = strings.TrimSuffix(f.GetName(), "_pb.d.ts") + "_pb_DEBUG.d.ts"
		}
	}
	for _, fileToGenerate := range req.GetFileToGenerate() {
		serviceJS := fmt.Sprintf("%s_grpc_web_pb.js", strings.TrimSuffix(fileToGenerate, ".proto"))
		typings := fmt.Sprintf("%s_grpc_web_pb.d.ts", strings.TrimSuffix(fileToGenerate, ".proto"))
		emptyContents := fmt.Sprintf("// GENERATED DO NOT MODIFY\n// empty grpc-web file for %s\n", fileToGenerate)

		if !filenames[serviceJS] {
			resp.File = append(resp.File, &pbplugin.CodeGeneratorResponse_File{
				Name:    proto.String(serviceJS),
				Content: proto.String(emptyContents),
			})
		}
		if !filenames[typings] {
			resp.File = append(resp.File, &pbplugin.CodeGeneratorResponse_File{
				Name:    proto.String(typings),
				Content: proto.String(emptyContents),
			})
		}
	}

	return nil
}

func runPlugin(ctx context.Context, toolPath string, req *pbplugin.CodeGeneratorRequest) (*pbplugin.CodeGeneratorResponse, error) {
	reqBytes, err := proto.Marshal(req)
	if err != nil {
		return nil, err
	}
	cmd := exec.CommandContext(ctx, toolPath)
	cmd.Stderr = os.Stderr
	cmd.Stdin = bytes.NewBuffer(reqBytes)
	cmd.Env = os.Environ()
	respBytes, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("error running tool %q: %w", toolPath, err)
	}
	resp := &pbplugin.CodeGeneratorResponse{}
	if err := proto.Unmarshal(respBytes, resp); err != nil {
		return nil, fmt.Errorf("tool %q ran successfully but gave non-protobuf response: %w", toolPath, err)
	}
	if resp.GetError() != "" {
		return nil, fmt.Errorf("error running plugin %q: %q", toolPath, resp.GetError())
	}
	glog.Infof("output files from tool %s:\n  %s", toolPath, mapSlice(resp.GetFile(), func(f *pbplugin.CodeGeneratorResponse_File) string {
		return f.GetName()
	}))
	return resp, nil
}

func cloneProto[T proto.Message](val T) T {
	return proto.Clone(val).(T)
}
