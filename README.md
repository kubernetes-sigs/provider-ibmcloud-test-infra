# provider-ibmcloud-test-infra

This project contains the [kubetest2](https://github.com/kubernetes-sigs/kubetest2) deployer-plugin for IBM Cloud to set up and run Kubernetes end-to-end tests on ppc64le or s390x hosts.
This plugin predominantly uses Terraform for provisioning infrastructure on IBM Cloud and Ansible for setting up Kubernetes on the deployed infrastructure.

## kubetest2-tf

kubetest2-tf is the deployer for creating required resources on [IBM Cloud Power Virtual Server](https://www.ibm.com/in-en/cloud/power-virtual-server) or [IBM Z](https://www.ibm.com/products/z/hybrid-cloud) infrastructure.

## Installation

### Using make
The plugin can be installed by executing the following command from repository root:
```shell
make install-deployer-tf
```

## Plugin usage
```shell
kubetest2 tf --powervs-dns k8s-tests --powervs-image-name CentOS-Stream-10 \
--powervs-zone syd05 --powervs-region=syd \
--powervs-service-id <Service ID of the workspace> --powervs-api-key <IBMCLOUD API KEY> \
--powervs-ssh-key ssh-key --ssh-private-key ~/.ssh/id_rsa \
--build-version v1.35.0-alpha.XXXXXXX \
--workers-count 1 --auto-approve --cluster-name <cluster-name>\
--playbook install-k8s-perf.yml --up --down \
--extra-vars=feature_gates:AllAlpha=true,EventedPLEG=false --retry-on-tf-failure 3 \
--break-kubetest-on-upfail true --ignore-destroy-errors --powervs-memory 16 \
--test=<kubetest2 tester> -- <tester args>
```

### Code of conduct

Participation in the Kubernetes community is governed by the [Kubernetes Code of Conduct](code-of-conduct.md).

[owners]: https://git.k8s.io/community/contributors/guide/owners.md
[Creative Commons 4.0]: https://git.k8s.io/website/LICENSE
