#!/bin/bash

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

set -o errexit
set -o nounset
set -o pipefail

# Source version configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/terraform_versions.env"

GO_LDFLAGS="-s -w"
# Allow override of installation paths via environment variables
TF_INSTALL_DIR="${TF_INSTALL_DIR:-/usr/local/bin}"
TF_PLUGIN_PATH="${TF_PLUGIN_PATH:-$HOME/.terraform.d/plugins/registry.terraform.io}"

install_terraform(){
    if [[ ! -z $(command -v terraform) ]]; then
        echo "terraform already present"
    else
        cd /tmp
        curl -fsSL https://github.com/hashicorp/terraform/archive/refs/tags/v${TF_VERSION}.zip -o ./terraform.zip
        unzip -o ./terraform.zip  >/dev/null 2>&1
        rm -f ./terraform.zip
        cd terraform-${TF_VERSION}
        go build -ldflags="${GO_LDFLAGS}" .
        mkdir -p "${TF_INSTALL_DIR}"
        cp terraform "${TF_INSTALL_DIR}/"
    fi
}

install_terraform_x86(){
    if [[ ! -z $(command -v terraform) ]]; then
        echo "terraform already present"
    else
        cd /tmp
        curl -fsSL https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip -o ./terraform.zip
        unzip -o ./terraform.zip  >/dev/null 2>&1
        rm -f ./terraform.zip
        mkdir -p "${TF_INSTALL_DIR}"
        cp terraform "${TF_INSTALL_DIR}/"
    fi
}

build_ibm_provider(){
    if [[ ! -f "${TF_PLUGIN_PATH}/IBM-Cloud/ibm/${TERRAFORM_PROVIDER_IBM_VERSION}/linux_${ARCH}/terraform-provider-ibm" ]]; then
        cd /tmp
        curl -fsSL https://github.com/IBM-Cloud/terraform-provider-ibm/archive/refs/tags/v${TERRAFORM_PROVIDER_IBM_VERSION}.zip -o ./terraform-provider-ibm.zip
        unzip -o ./terraform-provider-ibm.zip  >/dev/null 2>&1
        rm -f ./terraform-provider-ibm.zip
        cd terraform-provider-ibm-${TERRAFORM_PROVIDER_IBM_VERSION}
        go build -ldflags="${GO_LDFLAGS}" .
        mkdir -p ${TF_PLUGIN_PATH}/IBM-Cloud/ibm/${TERRAFORM_PROVIDER_IBM_VERSION}/linux_`go env GOARCH`
        cp -f terraform-provider-ibm ${TF_PLUGIN_PATH}/IBM-Cloud/ibm/${TERRAFORM_PROVIDER_IBM_VERSION}/linux_`go env GOARCH`
    fi
}

build_null_provider(){
    if [[ ! -f "${TF_PLUGIN_PATH}/hashicorp/null/${TERRAFORM_PROVIDER_NULL_VERSION}/linux_${ARCH}/terraform-provider-null" ]]; then
        echo "building null provider"
        cd /tmp
        curl -fsSL https://github.com/hashicorp/terraform-provider-null/archive/refs/tags/v${TERRAFORM_PROVIDER_NULL_VERSION}.zip -o ./terraform-provider-null.zip
        unzip -o ./terraform-provider-null.zip  >/dev/null 2>&1
        rm -f ./terraform-provider-null.zip
        cd terraform-provider-null-${TERRAFORM_PROVIDER_NULL_VERSION}
        go build -ldflags="${GO_LDFLAGS}" .
        mkdir -p ${TF_PLUGIN_PATH}/hashicorp/null/${TERRAFORM_PROVIDER_NULL_VERSION}/linux_`go env GOARCH`
        cp terraform-provider-null ${TF_PLUGIN_PATH}/hashicorp/null/${TERRAFORM_PROVIDER_NULL_VERSION}/linux_`go env GOARCH`
    fi
}

ARCH=$(uname -m)

if [[ "${ARCH}" == "ppc64le" || "${ARCH}" == "s390x" ]]; then
    install_terraform
    build_ibm_provider
    build_null_provider
elif [[ "${ARCH}" == "x86_64" ]]; then
    install_terraform_x86
fi
