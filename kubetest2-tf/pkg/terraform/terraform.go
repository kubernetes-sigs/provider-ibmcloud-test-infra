package terraform

import (
	"context"
	"fmt"
	"github.com/hashicorp/terraform-exec/tfexec"
	"path/filepath"

	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/data"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/terraform/exec"
)

const (
	// StateFileName is the default name for Terraform state files.
	StateFileName string = "terraform.tfstate"
)

func Apply(dir string, platform string) (path string, err error) {
	err = unpackAndInit(dir, platform)
	if err != nil {
		return "", fmt.Errorf("Failed to unpack terraform dependencies and Init: %v", err)
	}
	tf, err := exec.GetTerraformExecutor(dir, platform)
	if err != nil {
		return "", err
	}
	if err = tf.Apply(context.Background()); err != nil {
		return "", fmt.Errorf("failed to apply Terraform: %v", err)
	}
	sf := filepath.Join(dir, StateFileName)
	return sf, nil
}

func Destroy(dir string, platform string) (err error) {
	err = unpackAndInit(dir, platform)
	if err != nil {
		return fmt.Errorf("Failed to unpack terraform dependencies and Init: %v", err)
	}
	tf, err := exec.GetTerraformExecutor(dir, platform)
	if err != nil {
		return err
	}
	return tf.Destroy(context.Background())
}

func Output(dir string, platform string) (output map[string]interface{}, err error) {
	err = unpackAndInit(dir, platform)
	if err != nil {
		return nil, fmt.Errorf("Failed to unpack terraform dependencies and Init: %v", err)
	}
	tf, err := exec.GetTerraformExecutor(dir, platform)
	if err != nil {
		return nil, err
	}
	var options []tfexec.OutputOption
	options = append(options, tfexec.State(StateFileName))
	outputMeta, err := tf.Output(context.Background(), options...)
	outputs := make(map[string]interface{}, len(outputMeta))
	for key, value := range outputMeta {
		outputs[key] = value.Value
	}
	return outputs, nil
}

// unpack unpacks the platform-specific Terraform modules into the
// given directory.
func unpack(dir string, platform string) (err error) {
	err = data.Unpack(dir, platform)
	if err != nil {
		return err
	}
	err = data.Unpack(filepath.Join(dir, "config.tf"), "config.tf")
	return err
}

// unpackAndInit unpacks the platform-specific Terraform modules into
// the given directory and then runs 'terraform init'.
func unpackAndInit(dir string, platform string) (err error) {
	err = unpack(dir, platform)
	if err != nil {
		return fmt.Errorf("failed to unpack Terraform modules. %v", err)
	}
	tf, err := exec.GetTerraformExecutor(dir, platform)
	if err != nil {
		return err
	}
	return tf.Init(context.Background())
}
