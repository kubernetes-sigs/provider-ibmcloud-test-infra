package exec

import (
	"fmt"
	"os"
	goexec "os/exec"
	"path/filepath"

	"github.com/hashicorp/terraform-exec/tfexec"
	"k8s.io/klog/v2"
	"sigs.k8s.io/kubetest2/pkg/artifacts"
)

// terraformLogFileName is the terraform log file under the artifacts directory.
const terraformLogFileName = "terraform.log"

const (
	// The IBM provider only dumps Power IaaS HTTP requests when TF_LOG is non-empty.
	defaultLogLevel         = "INFO"
	defaultProviderLogLevel = "INFO"
)

func GetTerraformExecutor(workingDir, platform string) (*tfexec.Terraform, error) {
	terraformPath, err := goexec.LookPath("terraform")
	if err != nil {
		return nil, fmt.Errorf("terraform not found in $PATH")
	}
	// TODO: The below call is invoked multiple times which maybe unnecessary.
	tf, err := tfexec.NewTerraform(workingDir, terraformPath)
	if err != nil {
		return nil, fmt.Errorf("could not create terraform executor: %w", err)
	}
	tf.SetStdout(os.Stdout)
	tf.SetStderr(os.Stderr)
	enableLogging(tf)
	return tf, nil
}

// enableLogging forwards TF_LOG, TF_LOG_PROVIDER and TF_LOG_PATH to terraform.
func enableLogging(tf *tfexec.Terraform) {
	logPath := os.Getenv("TF_LOG_PATH")
	if logPath == "" {
		dir := artifacts.BaseDir()
		if err := os.MkdirAll(dir, 0755); err != nil {
			klog.Warningf("could not create artifacts dir %s, terraform logs disabled: %v", dir, err)
			return
		}
		logPath = filepath.Join(dir, terraformLogFileName)
	}
	if err := tf.SetLog(envOrDefault("TF_LOG", defaultLogLevel)); err != nil {
		klog.Warningf("could not set terraform log level: %v", err)
		return
	}
	if err := tf.SetLogProvider(envOrDefault("TF_LOG_PROVIDER", defaultProviderLogLevel)); err != nil {
		klog.Warningf("could not set terraform provider log level: %v", err)
		return
	}
	if err := tf.SetLogPath(logPath); err != nil {
		klog.Warningf("could not set terraform log path: %v", err)
	}
}

func envOrDefault(envVar, defaultVal string) string {
	if envVal := os.Getenv(envVar); envVal != "" {
		return envVal
	}
	return defaultVal
}
