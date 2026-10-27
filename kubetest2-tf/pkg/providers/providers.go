package providers

import (
	"fmt"

	"github.com/spf13/pflag"
)

type Provider interface {
	BindFlags(*pflag.FlagSet)
	DumpConfig(string) error
	Initialize() error
	// Sanitized returns a fmt.Stringer whose String() output has all secret
	// fields (API keys, tokens) replaced with "<redacted>", safe for logging.
	Sanitized() fmt.Stringer
}
