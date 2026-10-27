package tfvars

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

// secretValue is the real secret we use across all test cases.
const secretToken = "super-secret-bootstrap-token"
const secretSSHKey = "/home/user/.ssh/id_rsa_secret"

func populatedTFVars() TFVars {
	return TFVars{
		ReleaseMarker:  "ci/latest",
		BuildVersion:   "v1.30.0",
		Runtime:        "containerd",
		StorageServer:  "dl.k8s.io",
		StorageBucket:  "ppc64le-ci-builds",
		StorageDir:     "ci",
		ClusterName:    "k8s-cluster-abc123",
		ApiServerPort:  "6443",
		WorkersCount:   "2",
		BootstrapToken: secretToken,
		KubeconfigPath: "/tmp/kubeconfig",
		SSHPrivateKey:  secretSSHKey,
		ExtraCerts:     "k8s-cluster-abc123-master.k8s.test",
		IgnoreDestroy:  true,
	}
}

// --- Sanitized() ---

func TestTFVars_Sanitized_RedactsBootstrapToken(t *testing.T) {
	s := populatedTFVars().Sanitized()
	if s.BootstrapToken == secretToken {
		t.Errorf("Sanitized() left BootstrapToken unreacted; want %q, got %q", redacted, s.BootstrapToken)
	}
	if s.BootstrapToken != redacted {
		t.Errorf("Sanitized() BootstrapToken = %q, want %q", s.BootstrapToken, redacted)
	}
}

func TestTFVars_Sanitized_RedactsSSHPrivateKey(t *testing.T) {
	s := populatedTFVars().Sanitized()
	if s.SSHPrivateKey == secretSSHKey {
		t.Errorf("Sanitized() left SSHPrivateKey unredacted; want %q, got %q", redacted, s.SSHPrivateKey)
	}
	if s.SSHPrivateKey != redacted {
		t.Errorf("Sanitized() SSHPrivateKey = %q, want %q", s.SSHPrivateKey, redacted)
	}
}

func TestTFVars_Sanitized_PreservesNonSecretFields(t *testing.T) {
	v := populatedTFVars()
	s := v.Sanitized()
	checks := map[string][2]string{
		"ClusterName":   {s.ClusterName, v.ClusterName},
		"ReleaseMarker": {s.ReleaseMarker, v.ReleaseMarker},
		"BuildVersion":  {s.BuildVersion, v.BuildVersion},
		"Runtime":       {s.Runtime, v.Runtime},
		"WorkersCount":  {s.WorkersCount, v.WorkersCount},
		"ApiServerPort": {s.ApiServerPort, v.ApiServerPort},
	}
	for field, pair := range checks {
		if pair[0] != pair[1] {
			t.Errorf("Sanitized() modified non-secret field %s: got %q, want %q", field, pair[0], pair[1])
		}
	}
	if s.IgnoreDestroy != v.IgnoreDestroy {
		t.Errorf("Sanitized() modified IgnoreDestroy: got %v, want %v", s.IgnoreDestroy, v.IgnoreDestroy)
	}
}

func TestTFVars_Sanitized_EmptySecretsStayEmpty(t *testing.T) {
	v := TFVars{ClusterName: "test"} // BootstrapToken and SSHPrivateKey are zero
	s := v.Sanitized()
	if s.BootstrapToken != "" {
		t.Errorf("Sanitized() set BootstrapToken on empty input, got %q", s.BootstrapToken)
	}
	if s.SSHPrivateKey != "" {
		t.Errorf("Sanitized() set SSHPrivateKey on empty input, got %q", s.SSHPrivateKey)
	}
}

// --- String() / fmt verbs ---

func TestTFVars_String_DoesNotContainBootstrapToken(t *testing.T) {
	out := populatedTFVars().String()
	if strings.Contains(out, secretToken) {
		t.Errorf("String() leaked BootstrapToken in output: %s", out)
	}
}

func TestTFVars_String_DoesNotContainSSHPrivateKey(t *testing.T) {
	out := populatedTFVars().String()
	if strings.Contains(out, secretSSHKey) {
		t.Errorf("String() leaked SSHPrivateKey in output: %s", out)
	}
}

func TestTFVars_FmtVerb_v_DoesNotLeakSecrets(t *testing.T) {
	out := fmt.Sprintf("%v", populatedTFVars())
	if strings.Contains(out, secretToken) {
		t.Errorf("%%v leaked BootstrapToken: %s", out)
	}
	if strings.Contains(out, secretSSHKey) {
		t.Errorf("%%v leaked SSHPrivateKey: %s", out)
	}
}

func TestTFVars_FmtVerb_plusV_DoesNotLeakSecrets(t *testing.T) {
	out := fmt.Sprintf("%+v", populatedTFVars())
	if strings.Contains(out, secretToken) {
		t.Errorf("%%+v leaked BootstrapToken: %s", out)
	}
	if strings.Contains(out, secretSSHKey) {
		t.Errorf("%%+v leaked SSHPrivateKey: %s", out)
	}
}

func TestTFVars_FmtVerb_s_DoesNotLeakSecrets(t *testing.T) {
	out := fmt.Sprintf("%s", populatedTFVars())
	if strings.Contains(out, secretToken) {
		t.Errorf("%%s leaked BootstrapToken: %s", out)
	}
	if strings.Contains(out, secretSSHKey) {
		t.Errorf("%%s leaked SSHPrivateKey: %s", out)
	}
}

func TestTFVars_FmtVerb_sharpV_DoesNotLeakSecrets(t *testing.T) {
	out := fmt.Sprintf("%#v", populatedTFVars())
	if strings.Contains(out, secretToken) {
		t.Errorf("%%#v leaked BootstrapToken: %s", out)
	}
	if strings.Contains(out, secretSSHKey) {
		t.Errorf("%%#v leaked SSHPrivateKey: %s", out)
	}
}

func TestTFVars_String_ContainsRedactionMarker(t *testing.T) {
	out := populatedTFVars().String()
	if !strings.Contains(out, redacted) {
		t.Errorf("String() does not contain redaction marker %q: %s", redacted, out)
	}
}

func TestTFVars_String_ContainsClusterName(t *testing.T) {
	v := populatedTFVars()
	out := v.String()
	if !strings.Contains(out, v.ClusterName) {
		t.Errorf("String() dropped ClusterName %q from output: %s", v.ClusterName, out)
	}
}

// --- JSON marshalling must preserve real values (used by Terraform) ---

func TestTFVars_JSONMarshal_PreservesBootstrapToken(t *testing.T) {
	v := populatedTFVars()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}
	out := string(b)
	if !strings.Contains(out, secretToken) {
		t.Errorf("json.Marshal must preserve BootstrapToken for Terraform; not found in: %s", out)
	}
}

func TestTFVars_JSONMarshal_PreservesSSHPrivateKey(t *testing.T) {
	v := populatedTFVars()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}
	out := string(b)
	if !strings.Contains(out, secretSSHKey) {
		t.Errorf("json.Marshal must preserve SSHPrivateKey for Terraform; not found in: %s", out)
	}
}
