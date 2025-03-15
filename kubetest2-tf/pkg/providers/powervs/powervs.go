package powervs

import (
	"encoding/json"
	"fmt"
	"os"
	"path"

	pvsutils "github.com/ppc64le-cloud/powervs-utils"
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
}

func (p *Provider) Initialize() error {
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
		&p.Apikey, "powervs-api-key", "", "IBM Cloud API Key used for accessing the APIs",
	)
	// TODO: Deprecate the flag powervs-region at a later point in time.
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
	flags.Float64Var(
		&p.Memory, "powervs-memory", 8, "Memory in GBs",
	)
	flags.Float64Var(
		&p.Processors, "powervs-processors", 0.5, "Processor Units",
	)
	flags.StringVar(
		&p.SSHKey, "powervs-ssh-key", "", "PowerVS SSH Key to authenticate LPARs",
	)
	flags.MarkDeprecated("powervs-region", "Region will now be auto-identified from zone.")
	flags.Parse(os.Args)
	// If the value has not been set through the flag, determine through the util func using zone.
	if p.Region == "" {
		p.Region = pvsutils.RegionFromZone(p.Zone)
	}
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
