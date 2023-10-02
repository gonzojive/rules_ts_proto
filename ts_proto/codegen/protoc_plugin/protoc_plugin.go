package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/bazelbuild/rules_go/go/runfiles"
	"github.com/golang/glog"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/pluginpb"
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
	req := &pluginpb.CodeGeneratorRequest{}
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

func (up *uberPlugin) generateCode(ctx context.Context, req *pluginpb.CodeGeneratorRequest) (*pluginpb.CodeGeneratorResponse, error) {
	cfg, err := configFromRequest(req)
	if err != nil {
		return nil, err
	}
	glog.Infof("got config: %+v", cfg)

	runPluginWithParameter := func(toolPath, param string, postProcessors ...func(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) error) (*pluginpb.CodeGeneratorResponse, error) {
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
	importsReplacer := protoImportsReplacer(cfg)

	jsResp, err := runPluginWithParameter(up.genJSPluginPath, "import_style=es6,binary", importsReplacer, ensureMJSExtension)
	if err != nil {
		return nil, fmt.Errorf("error running ts definition codegen plugin: %w", err)
	}

	// The options for the grpc-web plugin are documented here:
	// https://github.com/grpc/grpc-web#import-style
	grpcResp, err := runPluginWithParameter(up.genGRPCPluginPath, "import_style=commonjs+dts,mode=grpcweb", processGRPCResponse, importsReplacer)
	if err != nil {
		return nil, fmt.Errorf("error running grpc definition codegen plugin: %w", err)
	}

	grpcTypescriptResp, err := runPluginWithParameter(up.genGRPCPluginPath, "import_style=typescript,mode=grpcweb", importsReplacer, grpcWebTypescriptModeProcessor)
	if err != nil {
		return nil, fmt.Errorf("error running grpc definition codegen plugin (typescript): %w", err)
	}

	errorField := ""
	if jsResp.GetError() != "" {
		errorField += fmt.Sprintf("JS code generation error: %s", jsResp.GetError())
	}
	if grpcResp.GetError() != "" {
		errorField += fmt.Sprintf("grpc-web code generation error: %s", jsResp.GetError())
	}
	if grpcTypescriptResp.GetError() != "" {
		errorField += fmt.Sprintf("grpc-web code generation error (ts): %s", jsResp.GetError())
	}
	if errorField != "" {
		return &pluginpb.CodeGeneratorResponse{
			Error: proto.String(errorField),
		}, nil
	}
	var files []*pluginpb.CodeGeneratorResponse_File
	files = append(files, jsResp.GetFile()...)
	files = append(files, grpcResp.GetFile()...)
	files = append(files, grpcTypescriptResp.GetFile()...)

	glog.Infof("output files: %s", mapSlice(files, func(f *pluginpb.CodeGeneratorResponse_File) string {
		return f.GetName()
	}))

	return &pluginpb.CodeGeneratorResponse{
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

func ensureMJSExtension(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) error {
	// Rename the _pb.js to _pb.mjs because ES6 modules are in use.
	for _, f := range resp.GetFile() {
		if strings.HasSuffix(f.GetName(), "_pb.js") {
			*f.Name = strings.TrimSuffix(f.GetName(), "_pb.js") + "_pb.mjs"
		}
	}

	return nil
}

const dontGenerateJS = true

func processGRPCResponse(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) error {
	filenames := map[string]bool{}
	for _, f := range resp.GetFile() {
		filenames[f.GetName()] = true
	}
	for _, fileToGenerate := range req.GetFileToGenerate() {
		prefix := strings.TrimSuffix(fileToGenerate, ".proto")
		serviceJS := fmt.Sprintf("%s_grpc_web_pb.js", prefix)
		serviceTypings := fmt.Sprintf("%s_grpc_web_pb.d.ts", prefix)
		messageTypingsDTS := fmt.Sprintf("%s_pb.d.ts", prefix)
		messageTypingsDMTS := fmt.Sprintf("%s_pb.d.mts", prefix)

		if msg := findResponseFileByName(resp, messageTypingsDTS); msg != nil {
			msg.Name = proto.String(messageTypingsDMTS)
		} else {
			return fmt.Errorf("grpc-web plugin unexpectedly did not output %q; outputs: %s", messageTypingsDTS,
				strings.Join(
					mapSlice(resp.GetFile(), func(f *pluginpb.CodeGeneratorResponse_File) string { return fmt.Sprintf("%q", f.GetName()) }),
					", "))
		}

		if dontGenerateJS {
			resp.File = filter(resp.File, func(f *pluginpb.CodeGeneratorResponse_File) bool {
				switch f.GetName() {
				case serviceJS, serviceTypings:
					return false
				default:
					return true
				}
			})
			continue
		}

		emptyContents := fmt.Sprintf("// GENERATED DO NOT MODIFY\n// empty grpc-web file for %s\n", fileToGenerate)

		if !filenames[serviceJS] {
			resp.File = append(resp.File, &pluginpb.CodeGeneratorResponse_File{
				Name:    proto.String(serviceJS),
				Content: proto.String(emptyContents),
			})
		}
		if !filenames[serviceTypings] {
			resp.File = append(resp.File, &pluginpb.CodeGeneratorResponse_File{
				Name:    proto.String(serviceTypings),
				Content: proto.String(emptyContents),
			})
		}
	}

	return nil
}

func findResponseFileByName(resp *pluginpb.CodeGeneratorResponse, name string) *pluginpb.CodeGeneratorResponse_File {
	for _, f := range resp.File {
		if f.GetName() == name {
			return f
		}
	}
	return nil
}

func runPlugin(ctx context.Context, toolPath string, req *pluginpb.CodeGeneratorRequest) (*pluginpb.CodeGeneratorResponse, error) {
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
	resp := &pluginpb.CodeGeneratorResponse{}
	if err := proto.Unmarshal(respBytes, resp); err != nil {
		return nil, fmt.Errorf("tool %q ran successfully but gave non-protobuf response: %w", toolPath, err)
	}
	if resp.GetError() != "" {
		return nil, fmt.Errorf("error running plugin %q: %q", toolPath, resp.GetError())
	}
	glog.Infof("output files from tool %s:\n  %s", toolPath, mapSlice(resp.GetFile(), func(f *pluginpb.CodeGeneratorResponse_File) string {
		return f.GetName()
	}))
	return resp, nil
}

func cloneProto[T proto.Message](val T) T {
	return proto.Clone(val).(T)
}

type config struct {
	ActionDescription string         `json:"action_description"`
	MappingEntries    []mappingEntry `json:"mapping_entries"`
}

func (c *config) find(protoImport string) *mappingEntry {
	for _, me := range c.MappingEntries {
		if me.ProtoImport == protoImport {
			return &me
		}
	}
	return nil
}

func configFromRequest(req *pluginpb.CodeGeneratorRequest) (*config, error) {
	for _, param := range strings.Split(req.GetParameter(), ",") {
		parts := strings.SplitN(param, "=", 2)
		if parts[0] == "config" {
			if len(parts) != 2 {
				return nil, fmt.Errorf("config parameter must be of the form config=")
			}

			jsonBytes, err := base64.StdEncoding.DecodeString(parts[1])
			if err != nil {
				return nil, fmt.Errorf("invalid base64 encoding of config option: %w", err)
			}
			cfg, err := unmarshalJSON[config](jsonBytes)
			if err != nil {
				return nil, fmt.Errorf("invalid delegating plugin config; see the JSON definition in protoc_plugin.go: %w", err)
			}
			return cfg, nil
		}
	}
	if true {
		return nil, fmt.Errorf("failed to parse parameter %q", req.GetParameter())
	}
	return &config{}, nil
}

type mappingEntry struct {
	ProtoImport         string `json:"proto_import"`
	JSImport            string `json:"js_import"`
	TSProtoLibraryLabel string `json:"ts_proto_library_label"`
}

func unmarshalJSON[T any](data []byte) (*T, error) {
	var value T
	if err := json.Unmarshal(data, &value); err != nil {
		return nil, fmt.Errorf("error while unmarshaling %T: %w", value, err)
	}
	return &value, nil
}

var replaceRegex = regexp.MustCompile(`import (.*) from ["'](.*)["'];\s+// proto import: "(.*)"`)

func replaceProtoImports(cfg *config, es6Code string) (string, error) {
	var errors []error
	updatedCode := replaceRegex.ReplaceAllStringFunc(es6Code, func(importStatement string) string {
		groups := replaceRegex.FindStringSubmatch(importStatement)
		aliasesAndWhatnot := groups[1]
		// currentImport := groups[2]
		protoImport := groups[3]
		replacement := cfg.find(protoImport)
		if replacement == nil {
			errors = append(errors, fmt.Errorf("failed to replace import for proto %q; not in import map %+v", protoImport, cfg))
			return fmt.Sprintf("// ERROR: Failed to perform substitution of proto import %q: %s", protoImport, groups[0])
		}
		return fmt.Sprintf(`import %s from "%s"; // proto import: %q; ts_proto_library: %s - updated by protoc_plugin.go`,
			aliasesAndWhatnot, replacement.JSImport, protoImport, replacement.TSProtoLibraryLabel)
	})
	if len(errors) != 0 {
		return updatedCode, errors[0]
	}
	return updatedCode, nil
}

func protoImportsReplacer(cfg *config) func(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) error {
	return func(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) error {
		for _, f := range resp.GetFile() {
			newCode, err := replaceProtoImports(cfg, f.GetContent())
			if err != nil {
				return err
			}
			f.Content = proto.String(newCode)
		}
		return nil
	}
}

func grpcWebTypescriptModeProcessor(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) error {
	if len(req.GetFileToGenerate()) != 1 {
		return fmt.Errorf("not equipped to process more than 1 output file yet, got %v", req.GetFileToGenerate())
	}
	updatedName := strings.TrimSuffix(req.GetFileToGenerate()[0], ".proto") + "_grpc_web_pb.mts"
	var files []*pluginpb.CodeGeneratorResponse_File
	for _, f := range resp.GetFile() {
		if strings.HasSuffix(f.GetName(), ".d.ts") {
			continue
		}
		if strings.HasSuffix(f.GetName(), ".ts") || strings.HasSuffix(f.GetName(), ".mts") {
			f.Name = &updatedName
		}
		files = append(files, f)
	}
	resp.File = files

	filenames := map[string]bool{}
	for _, f := range resp.GetFile() {
		filenames[f.GetName()] = true
	}
	for _, fileToGenerate := range req.GetFileToGenerate() {
		serviceTS := fmt.Sprintf("%s_grpc_web_pb.mts", strings.TrimSuffix(fileToGenerate, ".proto"))
		emptyContents := fmt.Sprintf("// GENERATED DO NOT MODIFY\n// empty grpc-web file for %s\n", fileToGenerate)

		if !filenames[serviceTS] {
			resp.File = append(resp.File, &pluginpb.CodeGeneratorResponse_File{
				Name:    proto.String(serviceTS),
				Content: proto.String(emptyContents),
			})
		}
	}

	return nil
}

func filter[T any](values []T, allow func(T) bool) []T {
	var out []T
	for _, v := range values {
		if allow(v) {
			out = append(out, v)
		}
	}
	return out
}
