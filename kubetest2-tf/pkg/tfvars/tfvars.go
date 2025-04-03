package tfvars

type TFVars struct {
	ReleaseMarker  string `json:"release_marker"`
	BuildVersion   string `json:"build_version"`
	Runtime        string `json:"runtime,omitempty"`
	StorageServer  string `json:"s3_server,omitempty"`
	StorageBucket  string `json:"bucket,omitempty"`
	StorageDir     string `json:"directory,omitempty"`
	ClusterName    string `json:"cluster_name"`
	ApiServerPort  int    `json:"apiserver_port,string"`
	WorkersCount   int    `json:"workers_count,string"`
	BootstrapToken string `json:"bootstrap_token"`
	KubeconfigPath string `json:"kubeconfig_path"`
	SSHPrivateKey  string `json:"ssh_private_key"`
	ExtraCerts     string `json:"extra_cert,omitempty"`
	IgnoreDestroy  bool   `json:"-"`
}
