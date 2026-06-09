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
}

func (p *Provider) Initialize() error {
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
		&p.Apikey, "vpc-api-key", "", "IBM Cloud API Key used for accessing the APIs",
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

func (p *Provider) DumpConfig(dir string) error {
	filename := path.Join(dir, Name+".auto.tfvars.json")
	config, err := json.MarshalIndent(p.TFVars, "", "  ")
	if err != nil {
		return fmt.Errorf("errored file converting config to json: %v", err)
	}
	err = os.WriteFile(filename, config, 0644)
	if err != nil {
		return fmt.Errorf("failed to dump the json config to: %s, err: %v", filename, err)
	}
	return nil
}
