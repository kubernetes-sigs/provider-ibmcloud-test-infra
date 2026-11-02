package providers

import (
	"fmt"
	"os"
	"strings"

	"github.com/spf13/pflag"
)

// ResolveSecretFromFile returns the value to use for a provider credential that
// can be supplied either inline (flag) or from a file such as a mounted
// Kubernetes secret.
//
// If file is empty, inline is returned unchanged. Setting both is an error. The
// file content is whitespace-trimmed and must be non-empty.
func ResolveSecretFromFile(inline, file, inlineFlag, fileFlag string) (string, error) {
	if file == "" {
		return inline, nil
	}
	if inline != "" {
		return "", fmt.Errorf("--%s and --%s are mutually exclusive", inlineFlag, fileFlag)
	}
	b, err := os.ReadFile(file)
	if err != nil {
		return "", fmt.Errorf("failed to read --%s %q: %w", fileFlag, file, err)
	}
	secret := strings.TrimSpace(string(b))
	if secret == "" {
		return "", fmt.Errorf("--%s %q is empty", fileFlag, file)
	}
	return secret, nil
}

type Provider interface {
	BindFlags(*pflag.FlagSet)
	DumpConfig(string) error
	Initialize() error
	// Sanitized returns a fmt.Stringer whose String() output has all secret
	// fields (API keys, tokens) replaced with "<redacted>", safe for logging.
	Sanitized() fmt.Stringer
}
