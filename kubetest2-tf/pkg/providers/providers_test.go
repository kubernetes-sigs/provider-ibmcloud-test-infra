package providers

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeSecretFile(t *testing.T, content string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "secret")
	if err := os.WriteFile(p, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestResolveSecretFromFile(t *testing.T) {
	tests := []struct {
		name    string
		inline  string
		file    func(t *testing.T) string
		want    string
		wantErr string
	}{
		{
			name:   "no file returns inline unchanged",
			inline: "inline-secret",
			file:   func(*testing.T) string { return "" },
			want:   "inline-secret",
		},
		{
			name: "no file and no inline returns empty",
			file: func(*testing.T) string { return "" },
			want: "",
		},
		{
			name: "file content is trimmed",
			file: func(t *testing.T) string { return writeSecretFile(t, "  file-secret\n") },
			want: "file-secret",
		},
		{
			name:    "inline and file are mutually exclusive",
			inline:  "inline-secret",
			file:    func(t *testing.T) string { return writeSecretFile(t, "file-secret") },
			wantErr: "mutually exclusive",
		},
		{
			name:    "missing file",
			file:    func(t *testing.T) string { return filepath.Join(t.TempDir(), "absent") },
			wantErr: "failed to read",
		},
		{
			name:    "empty file",
			file:    func(t *testing.T) string { return writeSecretFile(t, " \n\t") },
			wantErr: "is empty",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ResolveSecretFromFile(tt.inline, tt.file(t), "api-key", "api-key-file")
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("error = %v, want containing %q", err, tt.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

func TestResolveSecretFromFile_ErrorsDoNotIncludeValues(t *testing.T) {
	const inline, fileSecret = "inline-secret-value", "file-secret-value"
	cases := map[string]struct{ inline, file string }{
		"conflict": {inline, writeSecretFile(t, fileSecret)},
		"missing":  {"", filepath.Join(t.TempDir(), "absent")},
		"empty":    {"", writeSecretFile(t, "\n")},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := ResolveSecretFromFile(c.inline, c.file, "api-key", "api-key-file")
			if err == nil {
				t.Fatal("expected error")
			}
			if strings.Contains(err.Error(), inline) || strings.Contains(err.Error(), fileSecret) {
				t.Errorf("error included a credential value: %v", err)
			}
		})
	}
}
