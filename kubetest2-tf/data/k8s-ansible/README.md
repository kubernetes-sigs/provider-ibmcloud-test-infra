# k8s-ansible: Ansible utility to deploy alpha/release version Kubernetes clusters

## Deploying the Kubernetes cluster

**Note:** *The playbooks are tested and known to run reliably on Centos Stream distributions*

### Prerequisites

**Required:**
- `git` - Install using package manager: `yum install git -y`
- SSH access to target nodes (for multi-node clusters)
- `root` or sudo privileges on all nodes

**System Requirements (per node):**
- **CPU:** Minimum 0.25 Processing Units (PU)
- **RAM:** Minimum 16GB
- **Disk:** Sufficient storage for OS, Kubernetes binaries, and container images

**Optional:**
- Ansible is not required to be pre-installed. The `k8s-installer.sh` script will automatically install Ansible (via pip) if it's not already available on the system.

**Getting Started:**

Clone the repository and access the `k8s-ansible` directory.
```shell
git clone https://github.com/kubernetes-sigs/provider-ibmcloud-test-infra.git
cd provider-ibmcloud-test-infra/kubetest2-tf/data/k8s-ansible
```

## Setting up a Single-Node Kubernetes Cluster on the local machine
The `k8s-installer.sh` script can be used to install Kubernetes on a single node using the following command from the `k8s-ansible` directory.
```shell
cd hack
./k8s-installer.sh -L -r -y
```
Where:
- `-L`: Local mode - Sets up a single-node cluster on 127.0.0.1 (localhost)
- `-r`: Use the latest stable release version of Kubernetes
- `-y`: Auto-approve and proceed with installation without prompting for confirmation.

## Setting up a Kubernetes cluster using a deployer VM

For a cluster that's set up from a deployer VM which has access to the nodes where the cluster needs to be set up:

Add the node Public IP + hostname entries under `/etc/hosts` file on the deployer.

Example:

```
[root@kubetest2-tf1 hack]#
[root@kubetest2-tf1 hack]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
1.2.3.4 <Nodename 1>
1.2.3.5 <Nodename 2>
```

## Installation Strategies

### Method 1: Update fields in both hosts.yml and extra-vars-k8s.json to deploy cluster

Modify the host entry in the examples/containerd-cluster/hosts.yml and modify extra_cert in examples/containerd-cluster/extra-vars-k8s.json
```shell script
ansible-playbook -i examples/containerd-cluster/hosts.yml install-k8s.yml --extra-vars "@examples/containerd-cluster/extra-vars-k8s.json"
```

### Method 2: Deploy using hack/k8s-installer.sh for alpha/release Kubernetes installation

The `k8s-installer.sh` utility under hack provides an option to choose between the latest release or the alpha version of Kubernetes to be deployed on VMs.

**Parameters:**
- `-c`: Control-plane node IP address(es) - single IP (e.g., `X.X.X.X`) or multiple IPs in quotes (e.g., `"X.X.X.X Y.Y.Y.Y"`
- `-w`: Worker node IP address(es) - single IP (e.g., `X.X.X.X`) or multiple IPs in quotes (e.g., `"X.X.X.X Y.Y.Y.Y"`)
- `-p`: Playbook to use (default: `install-k8s.yml`)
- `-a`: Use latest alpha release from https://dl.k8s.io/ci/latest.txt
- `-r`: Use latest stable release from https://dl.k8s.io/release/stable.txt
- `-y`: Auto-approve and proceed without prompting

**Example usages:**
```shell
./k8s-installer.sh -c X.X.X.X -w Y.Y.Y.Y -p <playbook to use> -a|-r -y
```
To deploy latest Alpha release:
```shell
./k8s-installer.sh -w X.X.X.X -c Y.Y.Y.Y -a -y
```
To deploy latest Stable release:
```shell
./k8s-installer.sh -w X.X.X.X -c Y.Y.Y.Y -r -y
```
To deploy latest Stable release of k8s with a custom installation playbook (eg. install-k8s-perf.yml):
```shell
./k8s-installer.sh -p install-k8s-perf.yml -w X.X.X.X -c Y.Y.Y.Y -r -y
```
