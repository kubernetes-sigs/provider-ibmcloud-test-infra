package exec

import (
	"fmt"
	"os"
	goexec "os/exec"

	"github.com/hashicorp/terraform-exec/tfexec"
)

func GetTerraformExecutor(dir, platform string) (*tfexec.Terraform, error) {
	terraformPath, err := goexec.LookPath("terraform")
	if err != nil {
		return nil, fmt.Errorf("terraform not found in $PATH")
	}
	tf, err := tfexec.NewTerraform(dir, terraformPath)
	if err != nil {
		return nil, fmt.Errorf("could not create terraform executor: %w", err)
	}
	tf.SetStdout(os.Stdout)
	tf.SetStderr(os.Stderr)
	return tf, nil
}
