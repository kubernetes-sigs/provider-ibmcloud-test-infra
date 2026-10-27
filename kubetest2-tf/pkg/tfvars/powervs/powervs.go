package powervs

import "fmt"

type TFVars struct {
	Apikey        string  `json:"powervs_api_key,omitempty"`
	DNSName       string  `json:"powervs_dns"`
	DNSZone       string  `json:"powervs_dns_zone"`
	ImageName     string  `json:"powervs_image_name"`
	Memory        uint16  `json:"powervs_memory"`
	NetworkName   string  `json:"powervs_network_name"`
	Processors    float32 `json:"powervs_processors"`
	Region        string  `json:"powervs_region"`
	ResourceGroup string  `json:"powervs_resource_group"`
	SSHKey        string  `json:"powervs_ssh_key"`
	ServiceID     string  `json:"powervs_service_id"`
	Zone          string  `json:"powervs_zone"`
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
	Apikey        string
	DNSName       string
	DNSZone       string
	ImageName     string
	Memory        uint16
	NetworkName   string
	Processors    float32
	Region        string
	ResourceGroup string
	SSHKey        string
	ServiceID     string
	Zone          string
}

const redacted = "<redacted>"

// Sanitized returns a copy of TFVars with the API key replaced by "<redacted>",
// safe for use in log statements.
func (t TFVars) Sanitized() sanitizedTFVars {
	s := sanitizedTFVars{
		DNSName:       t.DNSName,
		DNSZone:       t.DNSZone,
		ImageName:     t.ImageName,
		Memory:        t.Memory,
		NetworkName:   t.NetworkName,
		Processors:    t.Processors,
		Region:        t.Region,
		ResourceGroup: t.ResourceGroup,
		SSHKey:        t.SSHKey,
		ServiceID:     t.ServiceID,
		Zone:          t.Zone,
	}
	if t.Apikey != "" {
		s.Apikey = redacted
	}
	return s
}

func (s sanitizedTFVars) String() string {
	return fmt.Sprintf(
		"{powervs_api_key:%s dns:%s zone:%s region:%s service_id:%s image:%s network:%s memory:%d processors:%g}",
		s.Apikey, s.DNSName, s.Zone, s.Region, s.ServiceID, s.ImageName, s.NetworkName, s.Memory, s.Processors,
	)
}
