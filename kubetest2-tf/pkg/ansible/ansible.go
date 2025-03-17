package ansible

import (
	"context"
	"fmt"
	"path/filepath"

	"k8s.io/klog/v2"

	"github.com/apenella/go-ansible/v2/pkg/execute"
	ansibleplaybook "github.com/apenella/go-ansible/v2/pkg/playbook"

	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/data"
)

const (
	ansibleDataDir = "k8s-ansible"
)

func Playbook(dir, inventory, playbook string, extraVars map[string]string) error {
	if err := unpackAnsible(dir); err != nil {
		return fmt.Errorf("failed to unpack the ansible code: %v", err)
	}
	extraVarsMap := make(map[string]interface{}, len(extraVars))
	for key, val := range extraVars {
		extraVarsMap[key] = val
	}
	klog.Infof("Running ansible playbook: %s", playbook)
	playbookCmd := ansibleplaybook.NewAnsiblePlaybookCmd(
		ansibleplaybook.WithPlaybooks(filepath.Join(dir, playbook)),
		ansibleplaybook.WithPlaybookOptions(
			&ansibleplaybook.AnsiblePlaybookOptions{
				ExtraVars: extraVarsMap,
				Inventory: inventory,
			}),
	)
	return execute.NewDefaultExecute(
		execute.WithCmd(playbookCmd),
		execute.WithErrorEnrich(ansibleplaybook.NewAnsiblePlaybookErrorEnrich()),
	).Execute(context.Background())
}

func unpackAnsible(dir string) error {
	return data.Unpack(dir, ansibleDataDir)
}
