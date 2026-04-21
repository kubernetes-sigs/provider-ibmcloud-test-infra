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

# kubetest2-tf targets
install-deployer-tf:
	$(MAKE) -C kubetest2-tf/ install-deployer-tf

build-deployer-tf:
	$(MAKE) -C kubetest2-tf/ build-deployer-tf

install-prereq:
	$(MAKE) -C kubetest2-tf/ install-prereq

install-ansible:
	$(MAKE) -C kubetest2-tf/ install-ansible

setup-tf:
	$(MAKE) -C kubetest2-tf/ setup-tf

build-tf-and-plugins:
	$(MAKE) -C kubetest2-tf/ build-tf-and-plugins

download-tf-plugins-from-cos:
	$(MAKE) -C kubetest2-tf/ download-tf-plugins-from-cos

download-from-cos:
	$(MAKE) -C kubetest2-tf/ download-from-cos WHAT="$(WHAT)"

push-to-cos:
	$(MAKE) -C kubetest2-tf/ push-to-cos WHAT="$(WHAT)" COS_HMAC_ACCESS_KEY="$(COS_HMAC_ACCESS_KEY)" COS_HMAC_SECRET_KEY="$(COS_HMAC_SECRET_KEY)" COS_BUCKET_NAME="$(COS_BUCKET_NAME)" COS_REGION="$(COS_REGION)" COS_SERVICE_CREDENTIALS_PATH="$(COS_SERVICE_CREDENTIALS_PATH)"

# secret-manager targets
build-secret-manager:
	$(MAKE) -C secret-manager/ build
