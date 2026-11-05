package vpc

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeKeyFile(t *testing.T, content string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "apikey")
	if err := os.WriteFile(p, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestInitialize_NoKeyFileIsNoop(t *testing.T) {
	p := &Provider{}
	p.Apikey = "from-flag"
	if err := p.Initialize(); err != nil {
		t.Fatalf("Initialize() error = %v", err)
	}
	if p.Apikey != "from-flag" {
		t.Errorf("Apikey = %q, want unchanged", p.Apikey)
	}
}

func TestInitialize_LoadsAndTrimsKeyFile(t *testing.T) {
	p := &Provider{APIKeyFile: writeKeyFile(t, "  file-key\n")}
	if err := p.Initialize(); err != nil {
		t.Fatalf("Initialize() error = %v", err)
	}
	if p.Apikey != "file-key" {
		t.Errorf("Apikey = %q, want %q", p.Apikey, "file-key")
	}
}

func TestInitialize_KeyFileAndFlagAreMutuallyExclusive(t *testing.T) {
	p := &Provider{APIKeyFile: writeKeyFile(t, "file-key")}
	p.Apikey = "from-flag"
	err := p.Initialize()
	if err == nil || !strings.Contains(err.Error(), "vpc-api-key") {
		t.Fatalf("Initialize() = %v, want mutual exclusion error naming the vpc flags", err)
	}
}

func TestInitialize_MissingKeyFile(t *testing.T) {
	p := &Provider{APIKeyFile: filepath.Join(t.TempDir(), "absent")}
	if err := p.Initialize(); err == nil {
		t.Fatal("Initialize() = nil, want error for missing file")
	}
}

func TestInitialize_EmptyKeyFile(t *testing.T) {
	p := &Provider{APIKeyFile: writeKeyFile(t, " \n")}
	if err := p.Initialize(); err == nil {
		t.Fatal("Initialize() = nil, want error for empty file")
	}
}

func TestDumpConfig_OmitsKeyFilePath(t *testing.T) {
	p := &Provider{APIKeyFile: "/etc/some/path/apikey"}
	dir := t.TempDir()
	if err := p.DumpConfig(dir); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(dir, Name+".auto.tfvars.json"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(b), "/etc/some/path") {
		t.Errorf("tfvars file contains key file path: %s", b)
	}
}
