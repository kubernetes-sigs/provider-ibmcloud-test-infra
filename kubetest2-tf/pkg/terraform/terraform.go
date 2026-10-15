package terraform

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/hashicorp/terraform-exec/tfexec"

	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/data"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/terraform/exec"
)

const (
	// StateFileName is the default name for Terraform state files.
	StateFileName string = "terraform.tfstate"
)

func Apply(workDir string, platform string) (statefilePath string, err error) {
	if err = unpackAndInit(workDir, platform); err != nil {
		return "", fmt.Errorf("failed to unpack terraform dependencies and Init: %v", err)
	}
	tf, err := exec.GetTerraformExecutor(workDir, platform)
	if err != nil {
		return "", err
	}
	applyErr := tf.Apply(context.Background())
	exec.RedactLog()
	if applyErr != nil {
		return "", fmt.Errorf("failed to apply Terraform: %v", applyErr)
	}
	statefilePath = filepath.Join(workDir, StateFileName)
	return statefilePath, nil
}

func Destroy(workDir string, platform string) (err error) {
	if err := unpackAndInit(workDir, platform); err != nil {
		return fmt.Errorf("failed to unpack terraform dependencies and Init: %v", err)
	}
	tf, err := exec.GetTerraformExecutor(workDir, platform)
	if err != nil {
		return err
	}
	destroyErr := tf.Destroy(context.Background())
	exec.RedactLog()
	return destroyErr
}

func Output(workDir string, platform string) (output map[string]interface{}, err error) {
	if err := unpackAndInit(workDir, platform); err != nil {
		return nil, fmt.Errorf("failed to unpack terraform dependencies and Init: %v", err)
	}
	tf, err := exec.GetTerraformExecutor(workDir, platform)
	if err != nil {
		return nil, err
	}
	var options []tfexec.OutputOption
	options = append(options, tfexec.State(StateFileName))
	outputMeta, err := tf.Output(context.Background(), options...)
	exec.RedactLog()
	outputs := make(map[string]interface{}, len(outputMeta))
	for key, value := range outputMeta {
		outputs[key] = value.Value
	}
	return outputs, nil
}

// unpack unpacks the platform-specific Terraform modules into the
// given directory.
func unpack(workDir string, platform string) (err error) {
	if err = data.Unpack(workDir, platform); err != nil {
		return err
	}
	return data.Unpack(filepath.Join(workDir, "config.tf"), "config.tf")
}

// unpackAndInit unpacks the platform-specific Terraform modules into
// the given directory and then runs 'terraform init'.
func unpackAndInit(workDir string, platform string) error {
	if err := unpack(workDir, platform); err != nil {
		return fmt.Errorf("failed to unpack Terraform modules. %v", err)
	}
	tf, err := exec.GetTerraformExecutor(workDir, platform)
	if err != nil {
		return err
	}
	return tf.Init(context.Background())
}
