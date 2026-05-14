#!/bin/bash

# Copyright The Kubernetes Authors.
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

#Enable debug logging
set -o xtrace

# Build the kubetest2 tf deployer locally and source the other dependencies.
OUT_DIR=/go/bin WHAT='terraform' make build-deployer-tf download-from-cos
make download-tf-plugins-from-cos
make install-ansible

# Fetch latest Kubernetes version
K8S_BUILD_VERSION=$(curl -s https://storage.googleapis.com/k8s-release-dev/ci/latest.txt)

# Run kubetest2 tf
kubetest2 tf \
  --powervs-image-name CentOS-Stream-10 \
  --powervs-ssh-key k8s-prow-sshkey \
  --ssh-private-key /etc/secret-volume/ssh-privatekey \
  --build-version "${K8S_BUILD_VERSION}" \
  --release-marker "${K8S_BUILD_VERSION}" \
  --cluster-name "pull-$(date +%s)" \
  --workers-count 1 \
  --up --down \
  --auto-approve \
  --retry-on-tf-failure 3 \
  --ignore-destroy-errors \
  --break-kubetest-on-upfail true \
  --powervs-memory 8 --powervs-processors 0.25 \
  --test=ginkgo --  --parallel 30 --test-package-dir ci --test-package-version "${K8S_BUILD_VERSION}" --focus-regex='Pods should be submitted and removed'
