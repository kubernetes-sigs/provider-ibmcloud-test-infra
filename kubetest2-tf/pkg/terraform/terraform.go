package terraform

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/hashicorp/terraform-exec/tfexec"

	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/data"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/terraform/exec"
)

func Apply(workDir string, platform string) (map[string]interface{}, error) {
	tf, err := unpackAndInit(workDir, platform)
	if err != nil {
		return nil, fmt.Errorf("failed to unpack terraform dependencies and Init: %v", err)
	}
	if err = tf.Apply(context.Background()); err != nil {
		return nil, fmt.Errorf("failed to apply Terraform: %v", err)
	}
	outputMeta, err := tf.Output(context.Background())
	if err != nil {
		return nil, err
	}
	outputs := make(map[string]interface{}, len(outputMeta))
	for key, value := range outputMeta {
		outputs[key] = value.Value
	}
	return outputs, nil
}

func Destroy(workDir string, platform string) error {
	tf, err := unpackAndInit(workDir, platform)
	if err != nil {
		return fmt.Errorf("failed to unpack terraform dependencies and Init: %v", err)
	}
	return tf.Destroy(context.Background())
}

// unpack unpacks the platform-specific Terraform modules into the
// given directory.
func unpack(workDir string, platform string) error {
	if err := data.Unpack(workDir, platform); err != nil {
		return err
	}
	return data.Unpack(filepath.Join(workDir, "config.tf"), "config.tf")
}

// unpackAndInit unpacks the platform-specific Terraform modules into
// the given directory and then runs 'terraform init'.
func unpackAndInit(workDir string, platform string) (*tfexec.Terraform, error) {
	if err := unpack(workDir, platform); err != nil {
		return nil, fmt.Errorf("failed to unpack Terraform modules. %v", err)
	}
	tf, err := exec.GetTerraformExecutor(workDir)
	if err != nil {
		return nil, err
	}
	return tf, tf.Init(context.Background())
}
