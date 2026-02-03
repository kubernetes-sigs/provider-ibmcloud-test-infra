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

	klog.Infof("Collecting cluster logs under %s", d.logsDir)
	// create a directory based on the generated path: _rundir/dump-cluster-logs
	if _, err := os.Stat(d.logsDir); os.IsNotExist(err) {
		if err := os.Mkdir(d.logsDir, os.ModePerm); err != nil {
			klog.Errorf("cannot create a directory in path %q. Err: %v", d.logsDir, err)
			return err
		}
	} else if err == nil {
		klog.Errorf("%q already exists. Please clean up directory", d.logsDir)
		return err
	} else {
		return fmt.Errorf("an error occured while obtaining directory stats. Err: %v", err)
	}
	command := []string{
		"kubectl",
		"cluster-info",
		"dump",
	}
	klog.Infof("About to run: %s", command)
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
		klog.Infof("Collecting node level information from instance %s", machineIP)
		for logFile, command := range commandFilename {
			stdOut.Reset()
			stdErr.Reset()
			commandArgs := []string{
				"ssh",
				"-i",
				common.CommonProvider.SSHPrivateKey,
				fmt.Sprintf("%s@%s", sshUser, machineIP),
				command,
			}
			klog.V(1).Infof("Remotely executing command: %s", commandArgs)
			cmd := exec.Command(commandArgs[0], commandArgs[1:]...)
			cmd.Stdout = &stdOut
			cmd.Stderr = &stdErr
			err = cmd.Run()
			if err != nil {
				errors = append(errors, fmt.Errorf("Failed to collect logs from node - %v - %v, err: %v", commandArgs, stdErr.String(), err))
				continue
			}

			outfile, err := os.Create(filepath.Join(d.logsDir, fmt.Sprintf("%s-%s.log", machineIP, logFile)))
			if err != nil {
				errors = append(errors, fmt.Errorf("Failed to create a log-file: %v", err))
				continue
			} else {
				outfile.WriteString(string(stdOut.Bytes()))
				outfile.Close()
			}
		}
	}
	if len(errors) > 0 {
		return fmt.Errorf("Observed one or more errors while collecting logs: %v", errors)
	}
	klog.Infof("Successfully collected cluster logs under %s", d.logsDir)
	return nil
}
