/*
Copyright 2025 The Kubernetes Authors.

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

package cmd

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/IBM/secrets-manager-go-sdk/v2/secretsmanagerv2"
	"github.com/jedib0t/go-pretty/v6/table"
	"github.com/spf13/cobra"

	"sigs.k8s.io/provider-ibmcloud-test-infra/secret-manager/internal/pkg/iam"
	"sigs.k8s.io/provider-ibmcloud-test-infra/secret-manager/internal/pkg/secretmanager"
)

var (
	labels  []string
	confirm bool
)

func init() {
	rootCmd.AddCommand(startCmd)
	startCmd.Flags().StringArrayVar(&labels, "labels", []string{}, "Labels to filter secrets by")
	startCmd.Flags().BoolVar(&confirm, "confirm", false, "Confirm the secret rotation")
}

var startCmd = &cobra.Command{
	Use:   "rotate",
	Short: "Rotates the secrets from the secret manager",
	Long:  "This tool iterates through all eligible secrets, rotating them.",
	RunE: func(cmd *cobra.Command, args []string) error {
		auth, err := iam.GetAuthenticator()
		if err != nil {
			return fmt.Errorf("failed to GetAuthenticator: %w", err)
		}

		sm, err := secretmanager.New(auth, instanceID, region)
		if err != nil {
			return fmt.Errorf("failed to create secretmanager client: %w", err)
		}
		return rotate(sm)
	},
}

func rotate(sm secretmanager.Interface) error {
	secrets, err := sm.GetIamSecrets(labels)
	if err != nil {
		return fmt.Errorf("failed to GetIamSecrets: %w", err)
	}

	if len(secrets) == 0 {
		return fmt.Errorf("no eligible secrets are available for rotation")
	}

	t := table.NewWriter()
	t.SetTitle("Secrets for rotation")
	t.SetOutputMirror(os.Stdout)
	t.AppendHeader(table.Row{"ID", "Name", "TTL", "Version"})
	for _, secret := range secrets {
		s := secret.(*secretsmanagerv2.IAMCredentialsSecretMetadata)
		t.AppendRow(table.Row{*s.ID, *s.Name, *s.TTL, *s.VersionsTotal})
	}
	t.Render()

	if !confirm && !askForConfirmation("Please confirm to rotate above secrets?") {
		fmt.Println("Not rotating the secrets...")
		return nil
	}

	fmt.Println("Rotating the secrets...")
	for _, secret := range secrets {
		s := secret.(*secretsmanagerv2.IAMCredentialsSecretMetadata)
		if err := sm.RotateSecret(s.ID); err != nil {
			return fmt.Errorf("failed to rotate secret \"%s\" (ID: %s): %w", *s.Name, *s.ID, err)
		}
		fmt.Printf("Secret \"%s\" (ID: %s) has been rotated.\n", *s.Name, *s.ID)
	}
	return nil
}

func askForConfirmation(s string) bool {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Printf("%s [y/n]: ", s)

		response, err := reader.ReadString('\n')
		if err != nil {
			log.Fatal(err)
		}

		response = strings.ToLower(strings.TrimSpace(response))

		if response == "y" || response == "yes" {
			return true
		} else if response == "n" || response == "no" {
			return false
		}
	}
}
