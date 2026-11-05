package vpc

import (
	"encoding/json"
	"fmt"
	"os"
	"path"

	"github.com/spf13/pflag"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/providers"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/tfvars/vpc"
)

const (
	Name = "vpc"
)

var _ providers.Provider = &Provider{}

var VPCProvider = &Provider{}

type Provider struct {
	vpc.TFVars

	// APIKeyFile is a path to a file holding the IBM Cloud API key. It is not
	// part of TFVars so the path itself is never written to the tfvars file.
	APIKeyFile string
}

// Initialize loads the API key from APIKeyFile when set.
func (p *Provider) Initialize() error {
	key, err := providers.ResolveSecretFromFile(p.Apikey, p.APIKeyFile, "vpc-api-key", "vpc-api-key-file")
	if err != nil {
		return err
	}
	p.Apikey = key
	return nil
}

func (p *Provider) BindFlags(flags *pflag.FlagSet) {
	flags.StringVar(
		&p.VPCName, "vpc-name", "", "IBM Cloud VPC name",
	)
	flags.StringVar(
		&p.SubnetName, "vpc-subnet", "", "IBM Cloud VPC subnet",
	)
	flags.StringVar(
		&p.Apikey, "vpc-api-key", "", "IBM Cloud API Key used for accessing the APIs. Alternatively use --vpc-api-key-file",
	)
	flags.StringVar(
		&p.APIKeyFile, "vpc-api-key-file", "", "Path to a file containing the IBM Cloud API Key (e.g. a mounted Kubernetes secret)",
	)
	flags.StringVar(
		&p.SSHKey, "vpc-ssh-key", "", "VPC SSH Key to authenticate VSIs",
	)
	flags.StringVar(
		&p.Region, "vpc-region", "", "IBM Cloud VPC region name",
	)
	flags.StringVar(
		&p.Zone, "vpc-zone", "", "IBM Cloud VPC zone name",
	)
	flags.StringVar(
		&p.ResourceGroup, "vpc-resource-group", "", "IBM Cloud resource group ID(command: ibmcloud resource groups --id)",
	)
	flags.StringVar(
		&p.NodeImageName, "vpc-node-image-name", "", "Image ID(command: ibmcloud is images)",
	)
	flags.StringVar(
		&p.NodeProfile, "vpc-node-profile", "", "Instance profiles to provision virtual servers(command: ibmcloud is instance-profiles)",
	)
}

// Sanitized implements providers.Provider, forwarding to the embedded TFVars.
func (p *Provider) Sanitized() fmt.Stringer {
	return p.TFVars.Sanitized()
}

func (p *Provider) DumpConfig(dir string) error {
	filename := path.Join(dir, Name+".auto.tfvars.json")
	config, err := json.MarshalIndent(p.TFVars, "", "  ")
	if err != nil {
		return fmt.Errorf("errored file converting config to json: %v", err)
	}
	err = os.WriteFile(filename, config, 0600)
	if err != nil {
		return fmt.Errorf("failed to dump the json config to: %s, err: %v", filename, err)
	}
	return nil
}
