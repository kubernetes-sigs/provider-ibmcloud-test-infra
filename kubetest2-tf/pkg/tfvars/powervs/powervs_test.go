package powervs

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

const secretAPIKey = "super-secret-powervs-api-key"

func populatedTFVars() TFVars {
	return TFVars{
		Apikey:        secretAPIKey,
		DNSName:       "my-dns",
		DNSZone:       "k8s.test",
		ImageName:     "rhel-9-ppc64le",
		Memory:        16,
		NetworkName:   "my-network",
		Processors:    0.5,
		Region:        "us-south",
		ResourceGroup: "default",
		SSHKey:        "my-ssh-key",
		ServiceID:     "abc-123-service",
		Zone:          "us-south-1",
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
		"DNSName":       {s.DNSName, v.DNSName},
		"DNSZone":       {s.DNSZone, v.DNSZone},
		"ImageName":     {s.ImageName, v.ImageName},
		"NetworkName":   {s.NetworkName, v.NetworkName},
		"Region":        {s.Region, v.Region},
		"ResourceGroup": {s.ResourceGroup, v.ResourceGroup},
		"SSHKey":        {s.SSHKey, v.SSHKey},
		"ServiceID":     {s.ServiceID, v.ServiceID},
		"Zone":          {s.Zone, v.Zone},
	}
	for field, pair := range checks {
		if pair[0] != pair[1] {
			t.Errorf("Sanitized() modified non-secret field %s: got %q, want %q", field, pair[0], pair[1])
		}
	}
}

func TestTFVars_Sanitized_EmptyAPIKeyStaysEmpty(t *testing.T) {
	v := TFVars{Region: "us-south"} // Apikey is zero
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
