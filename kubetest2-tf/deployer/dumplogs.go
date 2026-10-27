package deployer

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"k8s.io/klog/v2"

	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/providers/common"
)

var commandFilename = map[string]string{
	"dmesg":    "sudo dmesg",
	"kernel":   "sudo journalctl --no-pager --output=short-precise -k",
	"services": "sudo systemctl list-units -t service --no-pager --no-legend --all"}

func (d *deployer) DumpClusterLogs() error {
	var errors []error
	var stdErr, stdOut bytes.Buffer

	// Set exclusively as maps are declared during compile-time and may be set with defaults.
	commandFilename[common.CommonProvider.Runtime] = fmt.Sprintf("sudo journalctl -xeu %s --no-pager", common.CommonProvider.Runtime)

	klog.V(1).Infof("collecting cluster logs under %s", d.logsDir)
	if _, err := os.Stat(d.logsDir); os.IsNotExist(err) {
		if err := os.Mkdir(d.logsDir, os.ModePerm); err != nil {
			return fmt.Errorf("cannot create log dir %q: %v", d.logsDir, err)
		}
	} else if err == nil {
		return fmt.Errorf("log dir %q already exists; clean it up before collecting logs", d.logsDir)
	} else {
		return fmt.Errorf("error checking log dir %q: %v", d.logsDir, err)
	}
	command := []string{
		"kubectl",
		"cluster-info",
		"dump",
	}
	klog.V(2).Infof("running: %s", command)
	cmd := exec.Command(command[0], command[1:]...)
	cmd.Stdout = &stdOut
	cmd.Stderr = &stdErr
	err := cmd.Run()
	if err != nil {
		errors = append(errors, fmt.Errorf("couldn't use kubectl to dump cluster info: %v. StdErr: %s", err, stdErr.String()))
	} else {
		outfile, err := os.Create(filepath.Join(d.logsDir, "cluster-info.log"))
		if err != nil {
			errors = append(errors, fmt.Errorf("couldn't create file to capture dump cluster info: %v. StdErr: %s", err, stdErr.String()))
		} else {
			outfile.WriteString(string(stdOut.Bytes()))
			outfile.Close()
		}
	}

	// Todo: Include provider specific logic in this section. (Includes node level information/CRI/Services, etc.)
	sshUser := "root"
	if d.TargetProvider == "vpc" {
		sshUser = "k8s-admin"
	}
	for _, machineIP := range d.machineIPs {
		klog.V(1).Infof("collecting node logs from %s", machineIP)
		for logFile, command := range commandFilename {
			stdOut.Reset()
			stdErr.Reset()
			target := fmt.Sprintf("%s@%s", sshUser, machineIP)
			commandArgs := []string{
				"ssh",
				"-i",
				common.CommonProvider.SSHPrivateKey,
				target,
				command,
			}
			// Log only the non-sensitive parts: user@host and the command being run.
			// The SSH key path (commandArgs[2]) is intentionally omitted from logs.
			klog.V(1).Infof("Remotely executing command on %s: %s", target, command)
			cmd := exec.Command(commandArgs[0], commandArgs[1:]...)
			cmd.Stdout = &stdOut
			cmd.Stderr = &stdErr
			err = cmd.Run()
			if err != nil {
				errors = append(errors, fmt.Errorf("failed to collect logs from node %s (command: %s), err: %v, stderr: %s", target, command, err, stdErr.String()))
				continue
			}

			outfile, err := os.Create(filepath.Join(d.logsDir, fmt.Sprintf("%s-%s.log", machineIP, logFile)))
			if err != nil {
				errors = append(errors, fmt.Errorf("failed to create a log-file: %v", err))
				continue
			} else {
				outfile.WriteString(string(stdOut.Bytes()))
				outfile.Close()
			}
		}
	}
	if len(errors) > 0 {
		return fmt.Errorf("errors while collecting logs: %v", errors)
	}
	klog.V(1).Infof("cluster logs collected under %s", d.logsDir)
	return nil
}
