package powervs

type TFVars struct {
	Apikey        string  `json:"powervs_api_key,omitempty"`
	DNSName       string  `json:"powervs_dns"`
	DNSZone       string  `json:"powervs_dns_zone"`
	ImageName     string  `json:"powervs_image_name"`
	Memory        float64 `json:"powervs_memory"`
	NetworkName   string  `json:"powervs_network_name"`
	Processors    float64 `json:"powervs_processors"`
	Region        string  `json:"powervs_region"`
	ResourceGroup string  `json:"powervs_resource_group"`
	SSHKey        string  `json:"powervs_ssh_key"`
	ServiceID     string  `json:"powervs_service_id"`
	Zone          string  `json:"powervs_zone"`
}
