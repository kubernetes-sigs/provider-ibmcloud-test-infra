package vpc

import "fmt"

type TFVars struct {
	VPCName       string `json:"vpc_name"`
	SubnetName    string `json:"vpc_subnet_name"`
	Apikey        string `json:"vpc_api_key,omitempty"`
	SSHKey        string `json:"vpc_ssh_key"`
	Region        string `json:"vpc_region"`
	Zone          string `json:"vpc_zone"`
	ResourceGroup string `json:"vpc_resource_group"`
	NodeImageName string `json:"node_image"`
	NodeProfile   string `json:"node_profile"`
}

// String implements fmt.Stringer. It always redacts the API key so that any
// direct use of TFVars in a log or fmt call cannot leak credentials.
func (t TFVars) String() string {
	return t.Sanitized().String()
}

// GoString implements fmt.GoStringer (%#v verb) with the same redaction.
func (t TFVars) GoString() string {
	return t.Sanitized().String()
}

type sanitizedTFVars struct {
	VPCName       string
	SubnetName    string
	Apikey        string
	SSHKey        string
	Region        string
	Zone          string
	ResourceGroup string
	NodeImageName string
	NodeProfile   string
}

const redacted = "<redacted>"

// Sanitized returns a copy of TFVars with the API key replaced by "<redacted>",
// safe for use in log statements.
func (t TFVars) Sanitized() sanitizedTFVars {
	s := sanitizedTFVars{
		VPCName:       t.VPCName,
		SubnetName:    t.SubnetName,
		SSHKey:        t.SSHKey,
		Region:        t.Region,
		Zone:          t.Zone,
		ResourceGroup: t.ResourceGroup,
		NodeImageName: t.NodeImageName,
		NodeProfile:   t.NodeProfile,
	}
	if t.Apikey != "" {
		s.Apikey = redacted
	}
	return s
}

func (s sanitizedTFVars) String() string {
	return fmt.Sprintf(
		"{vpc_api_key:%s vpc:%s subnet:%s region:%s zone:%s resource_group:%s image:%s profile:%s}",
		s.Apikey, s.VPCName, s.SubnetName, s.Region, s.Zone, s.ResourceGroup, s.NodeImageName, s.NodeProfile,
	)
}
