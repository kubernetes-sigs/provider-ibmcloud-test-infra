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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        echo "Error: Unable to detect OS"
        exit 1
    fi
}

install_ansible() {
    echo "Installing ansible..."
    detect_os

    case "$OS" in
        ubuntu|debian)
            ##Install ansible required to bring up k8s cluster on infra
            apt-get update && pip install --break-system-packages ansible
            ;;
        rhel|centos)
            echo "Detected RHEL/CentOS system"
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y python3-pip
            else
                yum install -y python3-pip
            fi
            pip3 install ansible
            ;;
        *)
            echo "Error: Unsupported OS: $OS"
            echo "This script supports Ubuntu/Debian and RHEL/CentOS only"
            exit 1
            ;;
    esac
}

# Call if ansible not found
if ! command -v ansible >/dev/null 2>&1; then
    install_ansible
fi
