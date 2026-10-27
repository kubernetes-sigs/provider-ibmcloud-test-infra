/*
Copyright 2024 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package build

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/user"
	"path/filepath"
	"runtime"

	"github.com/IBM/ibm-cos-sdk-go/aws/awserr"
	"github.com/IBM/ibm-cos-sdk-go/aws/credentials"
)

// CosHmacCredentialsProviderName provides a name of CosHmacCreds provider
const CosHmacCredentialsProviderName = "CosHmacCredentialsProvider"

var (
	// ErrCosHmacCredentialsHomeNotFound is emitted when the user directory cannot be found.
	ErrCosHmacCredentialsHomeNotFound = awserr.New("UserHomeNotFound", "user home directory not found.", nil)
)

type CosHmacCredentialsProvider struct {
	// Path to the COS HMAC credentials file.
	//
	// If empty will look for "COS_HMAC_CREDENTIALS_FILE" env variable. If the
	// env value is empty will default to current user's home directory.
	// Linux/OSX: "$HOME/.ibmcloud/hmac_credentials"
	// Windows:   "%USERPROFILE%\.ibmcloud\hmac_credentials"
	Filename string

	// retrieved states if the credentials have been successfully retrieved.
	retrieved bool
}

type HMACKeys struct {
	AccessKeyID     string `json:"access_key_id"`
	SecretAccessKey string `json:"secret_access_key"`
}

type COSConfig struct {
	APIKey             string   `json:"apikey"`
	COSHMACKeys        HMACKeys `json:"cos_hmac_keys"`
	Endpoints          string   `json:"endpoints"`
	IAMAPIKeyDesc      string   `json:"iam_apikey_description"`
	IAMAPIKeyID        string   `json:"iam_apikey_id"`
	IAMAPIKeyName      string   `json:"iam_apikey_name"`
	IAMRoleCRN         string   `json:"iam_role_crn"`
	IAMServiceIDCRN    string   `json:"iam_serviceid_crn"`
	ResourceInstanceID string   `json:"resource_instance_id"`
}

// NewCosHmacCredentials returns a pointer to a new Credentials object
func NewCosHmacCredentials(filename string) *credentials.Credentials {
	return credentials.NewCredentials(&CosHmacCredentialsProvider{
		Filename: filename,
	})
}

// Retrieve reads and extracts the cos hmac credentials from the current
// users home directory.
func (p *CosHmacCredentialsProvider) Retrieve() (credentials.Value, error) {
	p.retrieved = false

	filename, err := p.filename()
	if err != nil {
		return credentials.Value{ProviderName: CosHmacCredentialsProviderName}, err
	}

	creds, err := loadCredential(filename)
	if err != nil {
		return credentials.Value{ProviderName: CosHmacCredentialsProviderName}, err
	}

	p.retrieved = true
	return creds, nil
}

// IsExpired returns if the cos hmac credentials have expired.
func (p *CosHmacCredentialsProvider) IsExpired() bool {
	return !p.retrieved
}

func OpenFile(filename string) (*COSConfig, error) {
	// Open the JSON file
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("error opening file: %v", err)
	}
	defer file.Close()

	// Decode the JSON file into a struct
	bytes, err := io.ReadAll(file)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %v", err)
	}
	var config COSConfig
	if err := json.Unmarshal(bytes, &config); err != nil {
		return nil, fmt.Errorf("error decoding JSON: %v", err)
	}
	return &config, nil
}

// loadCredential loads from the file pointed to by cos hmac credentials filename.
// The credentials retrieved will be returned or error. Error will be
// returned if it fails to read from the file, or the data is invalid.
func loadCredential(filename string) (credentials.Value, error) {
	credential, err := OpenFile(filename)
	if err != nil {
		return credentials.Value{ProviderName: CosHmacCredentialsProviderName}, awserr.New("CosHmacCredsLoad", "failed to load cos hmac credentials file", err)
	}

	id := credential.COSHMACKeys.AccessKeyID
	if len(id) == 0 {
		return credentials.Value{ProviderName: CosHmacCredentialsProviderName}, awserr.New("CosHmacCredsAccessKey",
			fmt.Sprintf("cos hmac credentials in %s did not contain access_key_id", filename),
			nil)
	}

	secret := credential.COSHMACKeys.SecretAccessKey
	if len(secret) == 0 {
		return credentials.Value{ProviderName: CosHmacCredentialsProviderName}, awserr.New("CosHmacCredsSecret",
			fmt.Sprintf("cos hmac credentials in %s did not contain secret_access_key", filename),
			nil)
	}

	return credentials.Value{
		AccessKeyID:     id,
		SecretAccessKey: secret,
		ProviderName:    CosHmacCredentialsProviderName,
	}, nil
}

// userHomeDir returns the home directory for the user the process is
// running under.
func userHomeDir() string {
	var home string

	if runtime.GOOS == "windows" { // Windows
		home = os.Getenv("USERPROFILE")
	} else {
		// *nix
		home = os.Getenv("HOME")
	}

	if len(home) > 0 {
		return home
	}

	currUser, _ := user.Current()
	if currUser != nil {
		home = currUser.HomeDir
	}

	return home
}

func cosHmacCredentialsFilename() string {
	return filepath.Join(userHomeDir(), ".ibmcloud", "hmac_credentials")
}

// filename returns the filename to use to read AWS shared credentials.
//
// Will return an error if the user's home directory path cannot be found.
func (p *CosHmacCredentialsProvider) filename() (string, error) {
	if len(p.Filename) != 0 {
		return p.Filename, nil
	}

	if p.Filename = os.Getenv("COS_HMAC_CREDENTIALS_FILE"); len(p.Filename) != 0 {
		return p.Filename, nil
	}

	if home := userHomeDir(); len(home) == 0 {
		// Backwards compatibility of home directly not found error being returned.
		// This error is too verbose, failure when opening the file would of been
		// a better error to return.
		return "", ErrCosHmacCredentialsHomeNotFound
	}

	p.Filename = cosHmacCredentialsFilename()

	return p.Filename, nil
}
