package tfvars

import "fmt"

type TFVars struct {
	ReleaseMarker  string `json:"release_marker"`
	BuildVersion   string `json:"build_version"`
	Runtime        string `json:"runtime,omitempty"`
	StorageServer  string `json:"s3_server,omitempty"`
	StorageBucket  string `json:"bucket,omitempty"`
	StorageDir     string `json:"directory,omitempty"`
	ClusterName    string `json:"cluster_name"`
	ApiServerPort  string `json:"apiserver_port"`
	WorkersCount   string `json:"workers_count"`
	BootstrapToken string `json:"bootstrap_token"`
	KubeconfigPath string `json:"kubeconfig_path"`
	SSHPrivateKey  string `json:"ssh_private_key"`
	ExtraCerts     string `json:"extra_cert,omitempty"`
	IgnoreDestroy  bool   `json:"-"`
}

// String implements fmt.Stringer. It always redacts secret fields so that any
// direct use of TFVars in a log or fmt call cannot leak credentials.
// Use Sanitized() only when you need structured access to the non-secret fields.
func (t TFVars) String() string {
	return t.Sanitized().String()
}

// GoString implements fmt.GoStringer (%#v verb) with the same redaction.
func (t TFVars) GoString() string {
	return t.Sanitized().String()
}

// sanitizedTFVars mirrors TFVars but replaces secret fields with a redaction
// marker so it can be safely passed to log calls.
type sanitizedTFVars struct {
	ReleaseMarker  string
	BuildVersion   string
	Runtime        string
	StorageServer  string
	StorageBucket  string
	StorageDir     string
	ClusterName    string
	ApiServerPort  string
	WorkersCount   string
	BootstrapToken string
	KubeconfigPath string
	SSHPrivateKey  string
	ExtraCerts     string
	IgnoreDestroy  bool
}

const redacted = "<redacted>"

// Sanitized returns a copy of TFVars with secret fields replaced by
// "<redacted>", safe for use in log statements.
func (t TFVars) Sanitized() sanitizedTFVars {
	s := sanitizedTFVars{
		ReleaseMarker:  t.ReleaseMarker,
		BuildVersion:   t.BuildVersion,
		Runtime:        t.Runtime,
		StorageServer:  t.StorageServer,
		StorageBucket:  t.StorageBucket,
		StorageDir:     t.StorageDir,
		ClusterName:    t.ClusterName,
		ApiServerPort:  t.ApiServerPort,
		WorkersCount:   t.WorkersCount,
		KubeconfigPath: t.KubeconfigPath,
		ExtraCerts:     t.ExtraCerts,
		IgnoreDestroy:  t.IgnoreDestroy,
	}
	if t.BootstrapToken != "" {
		s.BootstrapToken = redacted
	}
	if t.SSHPrivateKey != "" {
		s.SSHPrivateKey = redacted
	}
	return s
}

func (s sanitizedTFVars) String() string {
	return fmt.Sprintf(
		"{cluster:%s release:%s build:%s runtime:%s workers:%s apiserver_port:%s bootstrap_token:%s ssh_private_key:%s ignore_destroy:%v}",
		s.ClusterName, s.ReleaseMarker, s.BuildVersion, s.Runtime,
		s.WorkersCount, s.ApiServerPort, s.BootstrapToken, s.SSHPrivateKey,
		s.IgnoreDestroy,
	)
}
