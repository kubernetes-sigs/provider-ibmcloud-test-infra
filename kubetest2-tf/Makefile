# Copyright 2025 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.PHONY: help

help: ## This help message
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"

#Common uses:
# installing a kubetest2-tf deployer from source: `make install-deployer-tf INSTALL_DIR=$HOME/go/bin`
# downloading binaries from IBM Cloud COS: `make download-from-cos WHAT=terraform`
# pushing binaries to IBM Cloud COS: `make push-to-cos WHAT=terraform COS_SERVICE_CREDENTIALS_PATH=/path/to/credentials.json COS_BUCKET_NAME=...`
# or with direct keys: `make push-to-cos WHAT=terraform COS_HMAC_ACCESS_KEY=... COS_HMAC_SECRET_KEY=... COS_BUCKET_NAME=...`

# get the repo root and output path
REPO_ROOT:=$(shell pwd)
export REPO_ROOT
OUT_DIR?=$(REPO_ROOT)/bin
# record the source commit in the binary, overridable
INSTALL?=install
# make install will place binaries here
# the default path attempts to mimic go install
INSTALL_DIR?=$(shell $(REPO_ROOT)/hack/goinstalldir.sh)
# the output binary name, overridden when cross compiling
BINARY_NAME=kubetest2-tf
BUILD_FLAGS=-trimpath -ldflags="-s -w -buildid= -X=sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/deployer/deployer.GitTag=$(COMMIT)"
# IBM Cloud COS bucket configuration for binary downloads/uploads
COS_REGION?=us
COS_BUCKET_NAME?=provider-ibm-cloud-test-infra
# Derived values (constructed from region and bucket)
# Using virtual-hosted-style URL: bucket-name.s3.region.cloud-object-storage.appdomain.cloud
COS_ENDPOINT=$(COS_BUCKET_NAME).s3.$(COS_REGION).cloud-object-storage.appdomain.cloud
COS_BUCKET_URL=https://$(COS_ENDPOINT)
# IBM Cloud COS HMAC credentials for uploading (required for push-to-cos)
# Option 1: Provide HMAC keys directly
COS_HMAC_ACCESS_KEY?=
COS_HMAC_SECRET_KEY?=
# Option 2: Provide a JSON service credentials file (keys will be extracted and set to COS_HMAC_ACCESS_KEY/COS_HMAC_SECRET_KEY)
COS_SERVICE_CREDENTIALS_PATH?=
# ==============================================================================

install-prereq: ## Install prerequisites (Ansible and Terraform)
install-prereq: install-ansible setup-tf
.PHONY: install-prereq

install-ansible: ## Install Ansible
	./hack/ansible_install.sh
.PHONY: install-ansible

setup-tf: ## Install Terraform
	./hack/terraform_install.sh
.PHONY: setup-tf

build-deployer-tf: ## Build the kubetest2-tf deployer binary
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(OUT_DIR)
	go build $(BUILD_FLAGS) -o $(OUT_DIR)/$(BINARY_NAME) .
.PHONY: build-deployer-tf

build-tf-and-plugins: ## Build Terraform binary and plugins for ppc64le
	@echo "Building terraform binary and plugins..."
	@mkdir -p $(OUT_DIR)
	@mkdir -p $(OUT_DIR)/plugins
	TF_INSTALL_DIR=$(OUT_DIR) TF_PLUGIN_PATH=$(OUT_DIR)/plugins ./hack/terraform_install.sh
	@echo "Terraform and plugins successfully built and moved to $(OUT_DIR)"
.PHONY: build-tf-and-plugins

download-tf-plugins-from-cos: ## Download Terraform plugins from IBM Cloud COS
	@echo "Downloading terraform plugins from IBM Cloud COS..."
	@ARCH=$$(uname -m); \
	. $(REPO_ROOT)/hack/terraform_versions.env; \
	TF_PLUGIN_PATH="$$HOME/.terraform.d/plugins/registry.terraform.io"; \
	DOWNLOAD_URL=$(COS_BUCKET_URL)/plugins/IBM-Cloud/ibm/$$TERRAFORM_PROVIDER_IBM_VERSION/linux_$$ARCH/terraform-provider-ibm; \
	echo "Downloading terraform-provider-ibm for $$ARCH from $$DOWNLOAD_URL"; \
	mkdir -p "$$TF_PLUGIN_PATH/IBM-Cloud/ibm/$$TERRAFORM_PROVIDER_IBM_VERSION/linux_$$ARCH"; \
	if ! curl -fsSL -o "$$TF_PLUGIN_PATH/IBM-Cloud/ibm/$$TERRAFORM_PROVIDER_IBM_VERSION/linux_$$ARCH/terraform-provider-ibm" \
		"$$DOWNLOAD_URL"; then \
		echo "Error: Failed to download from $$DOWNLOAD_URL"; \
		exit 1; \
	fi; \
	chmod +x "$$TF_PLUGIN_PATH/IBM-Cloud/ibm/$$TERRAFORM_PROVIDER_IBM_VERSION/linux_$$ARCH/terraform-provider-ibm"; \
	DOWNLOAD_URL=$(COS_BUCKET_URL)/plugins/hashicorp/null/$$TERRAFORM_PROVIDER_NULL_VERSION/linux_$$ARCH/terraform-provider-null; \
	echo "Downloading terraform-provider-null for $$ARCH from $$DOWNLOAD_URL"; \
	mkdir -p "$$TF_PLUGIN_PATH/hashicorp/null/$$TERRAFORM_PROVIDER_NULL_VERSION/linux_$$ARCH"; \
	if ! curl -fsSL -o "$$TF_PLUGIN_PATH/hashicorp/null/$$TERRAFORM_PROVIDER_NULL_VERSION/linux_$$ARCH/terraform-provider-null" \
		"$$DOWNLOAD_URL"; then \
		echo "Error: Failed to download from $$DOWNLOAD_URL"; \
		exit 1; \
	fi; \
	chmod +x "$$TF_PLUGIN_PATH/hashicorp/null/$$TERRAFORM_PROVIDER_NULL_VERSION/linux_$$ARCH/terraform-provider-null"; \
	echo "Successfully downloaded and installed terraform plugins to $$TF_PLUGIN_PATH"
.PHONY: download-tf-plugins-from-cos


install-deployer-tf: ## Install kubetest2-tf deployer from source or downloads prebuilt binaries from COS
	@if [ "$$(uname -m)" = "ppc64le" ]; then \
		$(MAKE) install-ansible; \
		$(MAKE) download-from-cos WHAT='kubetest2-tf terraform'; \
		$(MAKE) download-tf-plugins-from-cos; \
	else \
		$(MAKE) install-prereq build-deployer-tf; \
		$(INSTALL) -d $(INSTALL_DIR); \
		$(INSTALL) $(OUT_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME); \
	fi
.PHONY: install-deployer-tf

download-from-cos: ## Download binaries from IBM Cloud COS (requires WHAT='binary1 binary2 ...')
	@if [ -z "$(WHAT)" ]; then \
		echo "Error: WHAT is required."; \
		echo "Usage: make download-from-cos WHAT=terraform (or WHAT='terraform $(BINARY_NAME)')"; \
		exit 1; \
	fi
	@mkdir -p $(OUT_DIR)
	$(INSTALL) -d $(INSTALL_DIR)
	@for file in $(WHAT); do \
		echo "Downloading $$file from IBM Cloud COS..."; \
		if ! curl -fsSL -o $(OUT_DIR)/$$file $(COS_BUCKET_URL)/$$file; then \
			echo "Error: Failed to download $$file from $(COS_BUCKET_URL)/$$file"; \
			exit 1; \
		fi; \
		if [ ! -f "$(OUT_DIR)/$$file" ]; then \
			echo "Error: Downloaded file $(OUT_DIR)/$$file does not exist"; \
			exit 1; \
		fi; \
		chmod +x $(OUT_DIR)/$$file; \
		echo "Installing $$file to $(INSTALL_DIR)..."; \
		$(INSTALL) $(OUT_DIR)/$$file $(INSTALL_DIR)/$$file; \
		echo "Successfully installed $$file to $(INSTALL_DIR)/$$file"; \
	done
.PHONY: download-from-cos

push-to-cos: ## Upload binaries to IBM Cloud COS (requires WHAT, COS_SERVICE_CREDENTIALS_PATH or COS_HMAC_ACCESS_KEY and COS_HMAC_SECRET_KEY, COS_BUCKET_NAME)
	@if [ -z "$(WHAT)" ]; then \
		echo "Error: WHAT is required."; \
		echo "Usage: make push-to-cos WHAT='bin1 bin2' COS_SERVICE_CREDENTIALS_PATH=/path/to/credentials.json COS_BUCKET_NAME=your-bucket"; \
		echo "   or: make push-to-cos WHAT='bin1 bin2' COS_HMAC_ACCESS_KEY=xxx COS_HMAC_SECRET_KEY=xxx COS_BUCKET_NAME=your-bucket"; \
		exit 1; \
	fi
	@if [ -z "$(COS_BUCKET_NAME)" ]; then \
		echo "Error: COS_BUCKET_NAME is required."; \
		exit 1; \
	fi
	@for file in $(WHAT); do \
		if [ ! -f "$(OUT_DIR)/$$file" ]; then \
			echo "Error: Local file $(OUT_DIR)/$$file does not exist. Please build or download it first."; \
			exit 1; \
		fi; \
	done
	@if [ -n "$(COS_SERVICE_CREDENTIALS_PATH)" ]; then \
		if [ ! -f "$(COS_SERVICE_CREDENTIALS_PATH)" ]; then \
			echo "Error: Credentials file $(COS_SERVICE_CREDENTIALS_PATH) does not exist."; \
			exit 1; \
		fi; \
		if ! command -v jq >/dev/null 2>&1; then \
			echo "Error: jq is required to parse JSON credentials file but is not installed."; \
			echo "Please install jq or use COS_HMAC_ACCESS_KEY and COS_HMAC_SECRET_KEY directly."; \
			exit 1; \
		fi; \
		echo "Loading credentials from $(COS_SERVICE_CREDENTIALS_PATH)..."; \
		export COS_HMAC_ACCESS_KEY=$$(jq -r '.cos_hmac_keys.access_key_id // empty' "$(COS_SERVICE_CREDENTIALS_PATH)"); \
		export COS_HMAC_SECRET_KEY=$$(jq -r '.cos_hmac_keys.secret_access_key // empty' "$(COS_SERVICE_CREDENTIALS_PATH)"); \
		if [ -z "$$COS_HMAC_ACCESS_KEY" ] || [ -z "$$COS_HMAC_SECRET_KEY" ]; then \
			echo "Error: Failed to extract HMAC keys from $(COS_SERVICE_CREDENTIALS_PATH)."; \
			echo "Expected JSON format: {\"cos_hmac_keys\": {\"access_key_id\": \"...\", \"secret_access_key\": \"...\"}}"; \
			exit 1; \
		fi; \
	fi; \
	: $${COS_HMAC_ACCESS_KEY:=$(COS_HMAC_ACCESS_KEY)}; \
	: $${COS_HMAC_SECRET_KEY:=$(COS_HMAC_SECRET_KEY)}; \
	if [ -z "$$COS_HMAC_ACCESS_KEY" ] || [ -z "$$COS_HMAC_SECRET_KEY" ]; then \
		echo "Error: Missing required COS credentials."; \
		echo "Provide either:"; \
		echo "  - COS_SERVICE_CREDENTIALS_PATH=/path/to/credentials.json"; \
		echo "  - COS_HMAC_ACCESS_KEY=xxx and COS_HMAC_SECRET_KEY=xxx"; \
		exit 1; \
	fi; \
	for file in $(WHAT); do \
		echo "Uploading $$file to IBM Cloud COS bucket $(COS_BUCKET_NAME)..."; \
		DATE=$$(date -u +"%a, %d %b %Y %H:%M:%S GMT"); \
		CONTENT_TYPE="application/octet-stream"; \
		STRING_TO_SIGN="PUT\n\n$$CONTENT_TYPE\n$$DATE\nx-amz-acl:public-read\n/$(COS_BUCKET_NAME)/$$file"; \
		SIGNATURE=$$(printf "%b" "$$STRING_TO_SIGN" | openssl sha1 -hmac "$$COS_HMAC_SECRET_KEY" -binary | base64); \
		curl -X PUT \
			-H "Host: $(COS_ENDPOINT)" \
			-H "Date: $$DATE" \
			-H "Content-Type: $$CONTENT_TYPE" \
			-H "Authorization: AWS $$COS_HMAC_ACCESS_KEY:$$SIGNATURE" \
			-H "x-amz-acl: public-read" \
			-T $(OUT_DIR)/$$file \
			https://$(COS_ENDPOINT)/$$file; \
		echo "Successfully uploaded $$file to $(COS_BUCKET_NAME)/$$file"; \
	done
.PHONY: push-to-cos
