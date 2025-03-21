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

TF_VERSION="1.9.8"
TERRAFORM_PROVIDER_IBM_VERSION="1.73.0"
TERRAFORM_PROVIDER_NULL_VERSION="3.2.3"
TF_PLUGIN_PATH="$HOME/.terraform.d/plugins/registry.terraform.io"

install_terraform_power(){
    if [[ ! -z $(command -v terraform) ]]; then
        echo "terraform already present"
    else
        cd /tmp
        curl -fsSL https://github.com/hashicorp/terraform/archive/refs/tags/v${TF_VERSION}.zip -o ./terraform.zip
        unzip -o ./terraform.zip  >/dev/null 2>&1
        rm -f ./terraform.zip
        cd terraform-${TF_VERSION}
        go build .
        cp terraform /usr/local/bin/
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
        cp terraform /usr/local/bin/
    fi
}

build_ibm_provider(){
    if [[ ! -f "${TF_PLUGIN_PATH}/IBM-Cloud/ibm/v${TERRAFORM_PROVIDER_IBM_VERSION}/linux_ppc64le/terraform-provider-ibm" || ! -f "${TF_PLUGIN_PATH}/hashicorp/ibm/v${TERRAFORM_PROVIDER_IBM_VERSION}/linux_ppc64le/terraform-provider-ibm" ]]; then
        cd /tmp
        curl -fsSL https://github.com/IBM-Cloud/terraform-provider-ibm/archive/refs/tags/v${TERRAFORM_PROVIDER_IBM_VERSION}.zip -o ./terraform-provider-ibm.zip
        unzip -o ./terraform-provider-ibm.zip  >/dev/null 2>&1
        rm -f ./terraform-provider-ibm.zip
        cd terraform-provider-ibm-${TERRAFORM_PROVIDER_IBM_VERSION}
        go build .
        mkdir -p ${TF_PLUGIN_PATH}/hashicorp/ibm/v${TERRAFORM_PROVIDER_IBM_VERSION}/linux_`go env GOARCH`
        cp -f terraform-provider-ibm ${TF_PLUGIN_PATH}/hashicorp/ibm/v${TERRAFORM_PROVIDER_IBM_VERSION}/linux_`go env GOARCH`
        mkdir -p ${TF_PLUGIN_PATH}/IBM-Cloud/ibm/v${TERRAFORM_PROVIDER_IBM_VERSION}/linux_`go env GOARCH`
        cp -f terraform-provider-ibm ${TF_PLUGIN_PATH}/IBM-Cloud/ibm/v${TERRAFORM_PROVIDER_IBM_VERSION}/linux_`go env GOARCH`
    fi
}

build_null_provider(){
    if [ ! -f "${TF_PLUGIN_PATH}/hashicorp/null/v${TERRAFORM_PROVIDER_NULL_VERSION}/linux_ppc64le/terraform-provider-null" ]; then
        cd /tmp
        curl -fsSL https://github.com/hashicorp/terraform-provider-null/archive/refs/tags/v${TERRAFORM_PROVIDER_NULL_VERSION}.zip -o ./terraform-provider-null.zip
        unzip -o ./terraform-provider-null.zip  >/dev/null 2>&1
        rm -f ./terraform-provider-null.zip
        cd terraform-provider-null-${TERRAFORM_PROVIDER_NULL_VERSION}
        go build .
        mkdir -p ${TF_PLUGIN_PATH}/hashicorp/null/v${TERRAFORM_PROVIDER_NULL_VERSION}/linux_`go env GOARCH`
        cp terraform-provider-null ${TF_PLUGIN_PATH}/hashicorp/null/v${TERRAFORM_PROVIDER_NULL_VERSION}/linux_`go env GOARCH`
    fi
}

ARCH=$(uname -m)

if [[ "${ARCH}" == "ppc64le" ]]; then
    install_terraform_power
    build_ibm_provider
    build_null_provider
elif [[ "${ARCH}" == "x86_64" ]]; then
    install_terraform_x86
fi
