package vpc

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

const secretAPIKey = "super-secret-vpc-api-key"

func populatedTFVars() TFVars {
	return TFVars{
		VPCName:       "my-vpc",
		SubnetName:    "my-subnet",
		Apikey:        secretAPIKey,
		SSHKey:        "my-ssh-key",
		Region:        "eu-de",
		Zone:          "eu-de-1",
		ResourceGroup: "default",
		NodeImageName: "ibm-ubuntu-22-04-minimal-amd64-1",
		NodeProfile:   "bx2-4x16",
	}
}

// --- Sanitized() ---

func TestTFVars_Sanitized_RedactsAPIKey(t *testing.T) {
	s := populatedTFVars().Sanitized()
	if s.Apikey == secretAPIKey {
		t.Errorf("Sanitized() left Apikey unredacted; want %q, got %q", redacted, s.Apikey)
	}
	if s.Apikey != redacted {
		t.Errorf("Sanitized() Apikey = %q, want %q", s.Apikey, redacted)
	}
}

func TestTFVars_Sanitized_PreservesNonSecretFields(t *testing.T) {
	v := populatedTFVars()
	s := v.Sanitized()
	checks := map[string][2]string{
		"VPCName":       {s.VPCName, v.VPCName},
		"SubnetName":    {s.SubnetName, v.SubnetName},
		"SSHKey":        {s.SSHKey, v.SSHKey},
		"Region":        {s.Region, v.Region},
		"Zone":          {s.Zone, v.Zone},
		"ResourceGroup": {s.ResourceGroup, v.ResourceGroup},
		"NodeImageName": {s.NodeImageName, v.NodeImageName},
		"NodeProfile":   {s.NodeProfile, v.NodeProfile},
	}
	for field, pair := range checks {
		if pair[0] != pair[1] {
			t.Errorf("Sanitized() modified non-secret field %s: got %q, want %q", field, pair[0], pair[1])
		}
	}
}

func TestTFVars_Sanitized_EmptyAPIKeyStaysEmpty(t *testing.T) {
	v := TFVars{Region: "eu-de"} // Apikey is zero
	s := v.Sanitized()
	if s.Apikey != "" {
		t.Errorf("Sanitized() set Apikey on empty input, got %q", s.Apikey)
	}
}

// --- String() / fmt verbs ---

func TestTFVars_String_DoesNotContainAPIKey(t *testing.T) {
	out := populatedTFVars().String()
	if strings.Contains(out, secretAPIKey) {
		t.Errorf("String() leaked Apikey in output: %s", out)
	}
}

func TestTFVars_FmtVerb_v_DoesNotLeakAPIKey(t *testing.T) {
	out := fmt.Sprintf("%v", populatedTFVars())
	if strings.Contains(out, secretAPIKey) {
		t.Errorf("%%v leaked Apikey: %s", out)
	}
}

func TestTFVars_FmtVerb_plusV_DoesNotLeakAPIKey(t *testing.T) {
	out := fmt.Sprintf("%+v", populatedTFVars())
	if strings.Contains(out, secretAPIKey) {
		t.Errorf("%%+v leaked Apikey: %s", out)
	}
}

func TestTFVars_FmtVerb_s_DoesNotLeakAPIKey(t *testing.T) {
	out := fmt.Sprintf("%s", populatedTFVars())
	if strings.Contains(out, secretAPIKey) {
		t.Errorf("%%s leaked Apikey: %s", out)
	}
}

func TestTFVars_FmtVerb_sharpV_DoesNotLeakAPIKey(t *testing.T) {
	out := fmt.Sprintf("%#v", populatedTFVars())
	if strings.Contains(out, secretAPIKey) {
		t.Errorf("%%#v leaked Apikey: %s", out)
	}
}

func TestTFVars_String_ContainsRedactionMarker(t *testing.T) {
	out := populatedTFVars().String()
	if !strings.Contains(out, redacted) {
		t.Errorf("String() does not contain redaction marker %q: %s", redacted, out)
	}
}

func TestTFVars_String_ContainsRegion(t *testing.T) {
	v := populatedTFVars()
	out := v.String()
	if !strings.Contains(out, v.Region) {
		t.Errorf("String() dropped Region %q from output: %s", v.Region, out)
	}
}

// --- JSON marshalling must preserve real value (used by Terraform) ---

func TestTFVars_JSONMarshal_PreservesAPIKey(t *testing.T) {
	v := populatedTFVars()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}
	out := string(b)
	if !strings.Contains(out, secretAPIKey) {
		t.Errorf("json.Marshal must preserve Apikey for Terraform; not found in: %s", out)
	}
}
