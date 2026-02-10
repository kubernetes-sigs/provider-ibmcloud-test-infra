## Update build cluster's nodes with latest Kernel/patches.

This guide covers the steps to update the build cluster's OS/Kernel/packages to the latest available versions based
on their availability through package managers. It is necessary to keep the nodes to have the latest security patches
installed and have the kernel up-to-date.

This update guide is applicable for HA clusters, and is extensively used to automate and perform the rolling updates of
the nodes.

The strategy used in updating the nodes is by performing rolling-updates to the nodes, post confirming that there are no
pods in the `test-pods` namespace that generally contains the prow-job workloads. The playbook has the mechanism to wait
until the namespace is free from running pods, however, there may be a necessity to terminate the boskos-related pods
as these are generally long-running in nature.

#### Prerequisites
```
   ansible
   private key of the bastion node.
```

#### Steps to follow:
1. From the k8s-ansible directory, generate the hosts.yml file on which the OS updates are to be performed.
   In this case, one can use the hosts.yml file under `examples/containerd-cluster/hosts.yml` to contain the IP(s)
   of the following nodes - Bastion, Workers and Masters. 
   In case if a bastion is involved in the setup, it is necessary to have a [bastion] section and the associated IP in the `hosts.yml` file
```
[masters]
10.20.177.51
10.20.177.26
10.20.177.227
[workers]
10.20.177.39

## The following section is needed if a bastion is involved.
##[workers:vars]
##ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path-to-private-key> -q root@X" -i <path-to-private-key>'
##
##[masters:vars]
##ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path-to-private-key> -q root@X" -i <path-to-private-key>'
```
2. Set the path to the `kubeconfig` of the cluster under group_vars/all - under the `kubeconfig_path` variable.
3. Once the above are set use the following command to update the nodes - 
   `ansible-playbook -i examples/containerd-cluster/hosts.yml update-os-packages.yml --extra-vars group_vars/all`
4. This will proceed to update the nodes, and reboot them serially if necessary.
