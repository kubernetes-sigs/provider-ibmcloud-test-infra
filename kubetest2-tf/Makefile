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

#Common uses:
# installing a kubetest2-tf deployer: `make install-deployer-tf INSTALL_DIR=$HOME/go/bin`

# get the repo root and output path
REPO_ROOT:=$(shell pwd)
export REPO_ROOT
OUT_DIR=$(REPO_ROOT)/bin
# record the source commit in the binary, overridable
INSTALL?=install
# make install will place binaries here
# the default path attempts to mimic go install
INSTALL_DIR?=$(shell $(REPO_ROOT)/hack/goinstalldir.sh)
# the output binary name, overridden when cross compiling
BINARY_NAME=kubetest2-tf
BUILD_FLAGS=-trimpath -ldflags="-buildid= -X=sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/deployer/deployer.GitTag=$(COMMIT)"
# ==============================================================================

install-prereq: install-ansible setup-tf
.PHONY: install-prereq

install-ansible:
	./hack/ansible_install.sh
.PHONY: install-ansible

setup-tf:
	./hack/terraform_install.sh
.PHONY: setup-tf

install-deployer-tf: install-prereq
	go build $(BUILD_FLAGS) -o $(OUT_DIR)/$(BINARY_NAME) .
	$(INSTALL) -d $(INSTALL_DIR)
	$(INSTALL) $(OUT_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
.PHONY: install-deployer-tf

build:
	go build .
.PHONY: build
