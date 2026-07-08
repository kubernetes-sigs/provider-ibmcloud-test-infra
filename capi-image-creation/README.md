# Kubernetes CAPI Image Builder

An Ansible-based automation tool for generating Kubernetes Cluster API (CAPI) images on IBM Cloud platforms.

## What This Does

This automation leverages the [kubernetes-sigs/image-builder](https://github.com/kubernetes-sigs/image-builder) project to create customized Kubernetes images tailored for IBM Cloud environments. Two deployment targets are supported:

- **VPC (Virtual Private Cloud)**: Generates QEMU-based qcow2 format images
- **PowerVS (Power Virtual Server)**: Produces OVA format images optimized for Power Systems architecture

## Directory Structure

- `image_creation.yml` - Primary Ansible playbook orchestrating the build workflow
- `vpc.yml` - VPC-specific build configuration parameters and settings
- `powervs.yml` - PowerVS-specific build configuration parameters and settings
- `variables.json` - IBM Cloud authentication credentials and Kubernetes version specifications
- `inventory.ini` - Ansible inventory defining target build servers

---

## VPC Image Creation

### VPC Infrastructure Requirements

Before running the automation for VPC, ensure the following IBM Cloud resources are provisioned:

* Active IBM Cloud account with appropriate permissions
* Cloud Object Storage (COS) bucket configured
* Virtual Private Cloud (VPC) environment
* VPC with at least one subnet
* Ubuntu virtual machine (build server) deployed in the VPC subnet

### VPC Setup Instructions

#### Step 1: Define Build Server

Modify `inventory.ini` with your build server information:

```ini
[servers]
<your-server-ip> ansible_user=<username>
```

#### Step 2: Customize Build Parameters

Adjust `vpc.yml` for VPC build:

```yaml
common_packages:
  - make
  - jq
  - python3-pip
  - python3-venv
  - build-essential
  - unzip
  - git
repo_url: "https://github.com/kubernetes-sigs/image-builder.git"
repo_dest: "/opt/image-builder"
build_type: "vpc"
image_name: "ubuntu-2404"  # Available: 'ubuntu-2404,ubuntu-2204,ubuntu-2604,
variables_json: "/opt/image-builder/images/capi/variables.json"
kubernetes_semver: "v1.33.0"  # Specify desired Kubernetes version
```

#### Step 3: Configure IBM Cloud Authentication

Populate `variables.json` with your IBM Cloud credentials:

```json
{
  "account_id": "ID of the IBM Cloud account where the COS bucket is located",
  "capture_cos_access_key": "HMAC access key credential for IBM Cloud Object Storage",
  "capture_cos_secret_key": "HMAC secret key credential for IBM Cloud Object Storage",
  "capture_cos_bucket": "Name identifier of the IBM Cloud Object Storage bucket",
  "capture_cos_region": "Geographic region of the IBM Cloud Object Storage instance"
}
```

### Running the VPC Build

Execute the playbook (VPC is the default build type):

```bash
ansible-playbook -i inventory.ini image_creation.yml
```

Or explicitly specify VPC:

```bash
ansible-playbook -i inventory.ini image_creation.yml -e "build_type=vpc"
```

The built image will be downloaded to `./output/<image-name>-kube-<version>.qcow2`

### VPC Build Workflow

The automation executes the following sequence for VPC:

1. **Environment Preparation**
   - Refreshes system package repositories
   - Deploys essential build tools (make, jq, git, python3-pip, and more)
   - Ensures Ansible is available on the build system

2. **Source Code Acquisition**
   - Retrieves the kubernetes-sigs/image-builder repository
   - Transfers configuration files to the remote build server

3. **VPC-Specific Build**
   - Installs QEMU/KVM packages
   - Builds qcow2 format images optimized for VPC

4. **Image Retrieval**
   - Downloads the built image to the local machine at `./output/<image-name>-kube-<version>.qcow2`

---

## PowerVS Image Creation

### PowerVS Infrastructure Requirements

Before running the automation for PowerVS, ensure the following IBM Cloud resources are provisioned:

* Active IBM Cloud account with appropriate permissions
* Cloud Object Storage (COS) bucket configured
* PowerVS workspace created and configured
* Virtual Private Cloud (VPC) environment
* Transit Gateway for network connectivity
* Transit Gateway configured with connections to both VPC and PowerVS workspace
* Ubuntu virtual machine (build server) deployed in VPC subnet
* SSH key pair generated and registered with PowerVS workspace
* Base OVA image stored in Cloud Object Storage bucket

### PowerVS Setup Instructions

#### Step 1: Define Build Server

Modify `inventory.ini` with your build server information:

```ini
[servers]
<your-server-ip> ansible_user=<username>
```

#### Step 2: Customize Build Parameters

Adjust `powervs.yml` for PowerVS build:

```yaml
common_packages:
  - make
  - jq
  - python3-pip
  - python3-venv
  - build-essential
  - unzip
  - git

repo_url: "https://github.com/kubernetes-sigs/image-builder.git"
repo_dest: "/opt/image-builder"
build_type: "powervs"
image_name: "centos-9"  # Available: 'centos-9', 'centos-10', etc.
packer_json_path: "/opt/image-builder/images/capi/packer/powervs/{{ image_name }}.json"
variables_json: "/opt/image-builder/images/capi/variables.json"
source_cos_object_name: "centos-9-stream-27052024.ova.gz"  # Base OVA image in COS
kubernetes_semver: "v1.33.0"  # Specify desired Kubernetes version
```

**Important:** Verify that `source_cos_object_name` references a valid base OVA image stored in your COS bucket.

#### Step 3: Configure IBM Cloud Authentication

Populate `variables.json` with your IBM Cloud credentials (includes PowerVS-specific fields):

```json
{
  "account_id": "ID of the IBM Cloud account where the COS bucket is located",
  "capture_cos_access_key": "HMAC access key credential for IBM Cloud Object Storage",
  "capture_cos_secret_key": "HMAC secret key credential for IBM Cloud Object Storage",
  "capture_cos_bucket": "Name identifier of the IBM Cloud Object Storage bucket",
  "capture_cos_region": "Geographic region of the IBM Cloud Object Storage instance",
  "key_pair_name": "SSH Key name registered in the PowerVS workspace which contains the key of the build server(Ubuntu VM)",
  "service_instance_id": "ID of the PowerVS workspace",
  "region": "Geographic region hosting the PowerVS workspace",
  "zone": "Availability zone within the PowerVS region",
  "dhcp_network": "Boolean flag (true/false) indicating DHCP configuration requirement"
}
```

### Running the PowerVS Build

Execute the playbook with PowerVS build type:

```bash
ansible-playbook -i inventory.ini image_creation.yml -e "build_type=powervs"
```

### PowerVS Build Workflow

The automation executes the following sequence for PowerVS:

1. **Environment Preparation**
   - Refreshes system package repositories
   - Deploys essential build tools (make, jq, git, python3-pip, and more)
   - Ensures Ansible is available on the build system

2. **Source Code Acquisition**
   - Retrieves the kubernetes-sigs/image-builder repository
   - Transfers configuration files to the remote build server

3. **PowerVS-Specific Build**
   - Configures PowerVS-specific settings
   - Retrieves base OVA image from Cloud Object Storage
   - Builds OVA format images optimized for Power Systems architecture
   - Uploads the final image to COS bucket.


---

## Supported Operating Systems

- Ubuntu 22.04 LTS (ubuntu-2204)
- Ubuntu 24.04 LTS (ubuntu-2404)
- Ubuntu 26.04 LTS (ubuntu-2604)
- CentOS 9 Stream (centos-9)
- Centos 10 Stream (centos-10)

## Reference Documentation

- [Kubernetes Image Builder Official Documentation](https://image-builder.sigs.k8s.io/)