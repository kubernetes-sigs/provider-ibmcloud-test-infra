# Install-Monitoring Role (kube-prometheus-stack) 

This Ansible role deploys the **kube-prometheus-stack** using Helm.  
It is intended to be run from a **deployer node** with access to the target Kubernetes cluster.

The role installs required tooling and then deploys the monitoring stack with custom Helm values.

---

## Overview

This role performs the following steps:

1. Installs required Ansible collections (`kubernetes.core`)
2. Downloads and installs **Helm**
3. Deploys **kube-prometheus-stack** using Helm
4. Applies custom Helm values to override default chart configuration

All pre-task steps are executed **locally on the deployer node**, not on cluster worker nodes.

---

## Prerequisite

> This role assumes `KUBECONFIG` is already configured and pointing to the valid target K8s cluster. The role will not generate or manage kubeconfig files.


## Usage 

```
ansible-playbook -v install-k8s-monitoring.yml --extra-vars "@grafana-secrets.yml"
```

> Ensure grafana-secrets.yaml contains

```
grafana_admin_user: your-user
grafana_admin_password: your-pass
```