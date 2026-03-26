# k8s-ansible : Ansible utility to deploy alpha/release version Kubernetes clusters.

#### Deploying a stable Kubernetes cluster
Prerequisite:
Add in the node Public IP + hostname entries under /etc/hosts file on the deployer.
For eg.

```
[root@kubetest2-tf1 hack]#
[root@kubetest2-tf1 hack]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
1.2.3.4 <Nodename 1>
1.2.3.5 <Nodename 2>
```

The playbooks are tested and known to run reliably on Centos Stream distributions, please reach out to the maintainers if the support needs to be extended to other availalbe distributions.

##### Method 1: Update fields in both hosts.yml and extra-vars-k8s.json to deploy cluster

Modify the host entry in the examples/containerd-cluster/hosts.yml and modify extra_cert in examples/containerd-cluster/extra-vars-k8s.json
```shell script
ansible-playbook -i examples/containerd-cluster/hosts.yml install-k8s.yml --extra-vars "@examples/containerd-cluster/extra-vars-k8s.json"
```

##### Method 2: Deploy using hack/k8s-installer.sh for alpha/release Kubernetes installation
The k8s-installer.sh utility under hack, provides an option to choose between the latest release or the alpha version of Kubernetes to be deployed on VMs from the hack directory.
###### Example usages:
```shell
./k8s-installer.sh -c X.X.X.X -w Y.Y.Y.Y -p <playbook to use> -a|-r -y
```
To deploy latest Alpha release of k8s:
```shell
./k8s-installer.sh -w X.X.X.X -c Y.Y.Y.Y -a -y
```
To deploy latest Stable release of k8s:
```shell
./k8s-installer.sh -w X.X.X.X -c Y.Y.Y.Y -r -y
```
To deploy latest Stable release of k8s for perf-tests:
```shell
./k8s-installer.sh -p install-k8s-perf.yml -w X.X.X.X -c Y.Y.Y.Y -r -y
```

##### Setting up a Single-Node Kubernetes Cluster on the local machine.
The ./hack/k8s-installer.sh script can be used to install Kubernetes on a single node using the following command:
```shell
cd hack
./k8s-installer.sh -L -r -y
```
