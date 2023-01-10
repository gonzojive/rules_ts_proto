package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"

	"github.com/golang/glog"
)

type config struct {
	MappingEntries []mappingEntry `json:"mapping_entries"`
}

type mappingEntry struct {
	ProtoImport string `json:"proto_import"`
	JSImport    string `json:"js_import"`
}

func unmarshalJSON[T any](data []byte) (*T, error) {
	var value T
	if err := json.Unmarshal(data, &value); err != nil {
		return nil, fmt.Errorf("error while unmarshaling %T: %w", value, err)
	}
	return &value, nil
}

var (
	inputPath   = flag.String("input_path", "", "Path to input file.")
	outputPath  = flag.String("output_path", "", "Output path with updated file.")
	mappingJSON = flag.String("config_json", "", "JSON with import map from proto_imort -> js_import.")
)

func main() {
	flag.Set("alsologtostderr", "true")
	flag.Parse()
	if err := run(context.Background()); err != nil {
		glog.Exitf("error running application:\n  %v", err)
	}
}

func run(ctx context.Context) error {
	cfg, err := unmarshalJSON[config]([]byte(*mappingJSON))
	if err != nil {
		return fmt.Errorf("bad --config_json flag: %w", err)
	}
	glog.Infof("got config: %v", cfg)
	return nil
}
