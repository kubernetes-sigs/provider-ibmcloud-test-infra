package exec

import (
	"bufio"
	"fmt"
	"os"
	goexec "os/exec"
	"path/filepath"
	"strings"

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
	logPath := logFilePath()
	logDir := filepath.Dir(logPath)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		klog.Warningf("could not create log dir %s, terraform logs disabled: %v", logDir, err)
		return
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

// logFilePath returns the terraform log path: TF_LOG_PATH if set, otherwise
// the default file under the artifacts directory.
func logFilePath() string {
	if tfLogPath := os.Getenv("TF_LOG_PATH"); tfLogPath != "" {
		return tfLogPath
	}
	return filepath.Join(artifacts.BaseDir(), terraformLogFileName)
}

// RedactLog removes lines containing Set-Cookie headers from the terraform log
// file.
func RedactLog() {
	if err := redactFile(logFilePath()); err != nil {
		klog.Warningf("could not redact terraform log: %v", err)
	}
}

// redactFile rewrites path, dropping any line that contains a Set-Cookie header.
func redactFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	defer f.Close()

	tmp, err := os.CreateTemp(filepath.Dir(path), "terraform.log.tmp.*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	ok := false
	defer func() {
		tmp.Close()
		if !ok {
			os.Remove(tmpName)
		}
	}()

	w := bufio.NewWriter(tmp)
	scanner := bufio.NewScanner(f)
	// Increase the buffer for long response-body lines.
	scanner.Buffer(make([]byte, 256*1024), 256*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, "Set-Cookie:") {
			continue
		}
		if _, err := fmt.Fprintln(w, line); err != nil {
			return err
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if err := w.Flush(); err != nil {
		return err
	}
	ok = true
	tmp.Close()
	return os.Rename(tmpName, path)
}
