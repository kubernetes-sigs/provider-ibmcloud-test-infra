package powervs

import (
	"encoding/json"
	"fmt"
	"os"
	"path"

	"github.com/spf13/pflag"

	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/providers"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/tfvars/powervs"
)

const (
	Name = "powervs"
)

var _ providers.Provider = &Provider{}

var PowerVSProvider = &Provider{}

type Provider struct {
	powervs.TFVars

	// APIKeyFile is a path to a file holding the IBM Cloud API key. It is not
	// part of TFVars so the path itself is never written to the tfvars file.
	APIKeyFile string
}

// Initialize loads the API key from APIKeyFile when set.
func (p *Provider) Initialize() error {
	key, err := providers.ResolveSecretFromFile(p.Apikey, p.APIKeyFile, "powervs-api-key", "powervs-api-key-file")
	if err != nil {
		return err
	}
	p.Apikey = key
	return nil
}

func (p *Provider) BindFlags(flags *pflag.FlagSet) {
	flags.StringVar(
		&p.ResourceGroup, "powervs-resource-group", "Default", "IBM Cloud resource group name(command: ibmcloud resource groups)",
	)
	flags.StringVar(
		&p.DNSName, "powervs-dns", "", "IBM Cloud DNS name(command: ibmcloud dns instances)",
	)
	flags.StringVar(
		&p.DNSZone, "powervs-dns-zone", "", "IBM Cloud DNS Zone name(commmand: ibmcloud dns zones)",
	)
	flags.StringVar(
		&p.Apikey, "powervs-api-key", "", "IBM Cloud API Key used for accessing the APIs. Alternatively use --powervs-api-key-file",
	)
	flags.StringVar(
		&p.APIKeyFile, "powervs-api-key-file", "", "Path to a file containing the IBM Cloud API Key (e.g. a mounted Kubernetes secret)",
	)
	flags.StringVar(
		&p.Region, "powervs-region", "", "IBM Cloud PowerVS region name",
	)
	flags.StringVar(
		&p.Zone, "powervs-zone", "", "IBM Cloud PowerVS zone name",
	)
	flags.StringVar(
		&p.ServiceID, "powervs-service-id", "", "IBM Cloud PowerVS service instance ID(get GUID from command: ibmcloud resource service-instances --long)",
	)
	flags.StringVar(
		&p.NetworkName, "powervs-network-name", "", "Network Name(command: ibmcloud pi subnet ls)",
	)
	flags.StringVar(
		&p.ImageName, "powervs-image-name", "", "Image ID(command: ibmcloud pi img ls)",
	)
	flags.Uint16Var(
		&p.Memory, "powervs-memory", 8, "Memory in GBs",
	)
	flags.Float32Var(
		&p.Processors, "powervs-processors", 0.5, "Processor Units",
	)
	flags.StringVar(
		&p.SSHKey, "powervs-ssh-key", "", "PowerVS SSH Key to authenticate LPARs",
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
