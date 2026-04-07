#!/bin/sh
set -e
set -o noglob

# ==============================================================================
# KUBERNETES INSTALLATION SCRIPT USING KUBEADM
# ==============================================================================
# This script automates the installation of Kubernetes clusters using kubeadm.
# It supports control-plane and worker node installation, air-gapped deployments,
# and various CNI plugins.
#
# ==============================================================================
# USAGE EXAMPLES
# ==============================================================================
#
# Basic usage:
#   curl ... | ENV_VAR=... sh -
#       or
#   ENV_VAR=... ./kubeadm-install.sh
#
# Control-plane node:
#   curl ... | INSTALL_K8S_EXEC="init --pod-network-cidr=10.244.0.0/16" sh -
#
# Worker node:
#   curl ... | K8S_TOKEN=xxx K8S_CONTROL_PLANE_ENDPOINT=https://server:6443 sh -
#
# Single-node cluster with Calico CNI:
#   INSTALL_K8S_SINGLE_NODE=true INSTALL_K8S_CNI=true ./kubeadm-install.sh
#
# Single-node with Calico manifest method:
#   INSTALL_K8S_SINGLE_NODE=true INSTALL_K8S_CNI=true \
#   INSTALL_K8S_CALICO_INSTALLATION_TYPE=manifest ./kubeadm-install.sh
#
# Create air-gapped bundle (defaults to ppc64le):
#   ./kubeadm-install.sh --airgap-bundle
#
# Create air-gapped bundle for specific architecture:
#   ARCH=amd64 ./kubeadm-install.sh --airgap-bundle
#
# Install from air-gapped bundle:
#   INSTALL_K8S_AIRGAP_BUNDLE_DIR=/path/to/bundle ./kubeadm-install.sh
#
# Uninstall Kubernetes cluster:
#   sudo /usr/bin/k8s-uninstall.sh
#
# ==============================================================================
# ENVIRONMENT VARIABLES
# ==============================================================================
#
# K8S_* Variables:
#   K8S_*                           - Variables beginning with K8S_ are preserved
#                                     for systemd service. Setting
#                                     K8S_CONTROL_PLANE_ENDPOINT without a command
#                                     defaults to "join" mode.
#
# Installation Control:
#   INSTALL_K8S_SKIP_DOWNLOAD       - Skip kubernetes package downloads (default: false)
#   INSTALL_K8S_SKIP_PREFLIGHT      - Skip kubeadm preflight checks (default: false)
#   INSTALL_K8S_SELINUX_WARN        - Continue if SELinux not configured (default: false)
#
# Version Configuration:
#   INSTALL_K8S_VERSION             - Kubernetes version (e.g., 1.28.0, 1.29.0)
#   INSTALL_K8S_CONTAINERD_VERSION  - Containerd version (default: 2.2.2)
#   INSTALL_K8S_RUNC_VERSION        - Runc version (default: 1.4.1)
#   INSTALL_K8S_CRICTL_VERSION      - Crictl version (default: 1.35.0)
#   INSTALL_K8S_CALICO_VERSION      - Calico version (default: v3.27.5)
#
# Cluster Configuration:
#   INSTALL_K8S_EXEC                - Command with flags for kubeadm (init or join)
#   INSTALL_K8S_SINGLE_NODE         - Configure for single-node operation (default: false)
#   INSTALL_K8S_POD_SUBNET          - Pod network CIDR for Calico (default: 172.20.0.0/16)
#
# CNI Configuration:
#   INSTALL_K8S_CNI                      - Install Calico CNI plugin (default: false)
#   INSTALL_K8S_CALICO_INSTALLATION_TYPE - Calico method: operator|manifest (default: manifest)
#
# Air-gapped Installation:
#   INSTALL_K8S_AIRGAP_BUNDLE_DIR    - Path to air-gapped bundle directory
#   INSTALL_K8S_AIRGAP_BUNDLE_OUTPUT - Output directory for bundle (default: ./k8s-airgap-bundle)
#   ARCH                             - Target architecture for bundle (default: ppc64le for airgap-bundle)
#
# ==============================================================================

info() { echo '[INFO] ' "$@"; }
warn() { echo '[WARN] ' "$@" >&2; }
fatal() { echo '[ERROR] ' "$@" >&2; exit 1; }

# --- fatal if no systemd ---
verify_system() {
    if [ -x /bin/systemctl ] || type systemctl > /dev/null 2>&1; then
        HAS_SYSTEMD=true
        return
    fi
    fatal 'Can not find systemd to use as a process supervisor for kubernetes'
}

quote() {
    for arg in "$@"; do
        printf '%s\n' "$arg" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"
    done
}

quote_indent() {
    printf ' \\\n'
    for arg in "$@"; do
        printf '\t%s \\\n' "$(quote "$arg")"
    done
}

escape() {
    printf '%s' "$@" | sed -e 's/\([][!#$%&()*;<=>?\_`{|}]\)/\\\1/g;'
}

escape_dq() {
    printf '%s' "$@" | sed -e 's/"/\\"/g'
}

# --- Verify and set architecture ---
setup_verify_arch() {
    if [ -z "${ARCH}" ]; then
        ARCH=$(uname -m)
    fi
    case ${ARCH} in
        amd64|x86_64)
            ARCH=amd64
            ;;
        arm64|aarch64)
            ARCH=arm64
            ;;
        ppc64le)
            ARCH=ppc64le
            ;;
        *)
            fatal "Unsupported architecture ${ARCH}"
    esac
    
    info "Architecture: ${ARCH}"
}

# --- Set architecture for airgap bundle (defaults to ppc64le) ---
setup_airgap_arch() {
    if [ -z "${ARCH}" ]; then
        ARCH=ppc64le
        info "Defaulting to ppc64le architecture for airgap bundle"
        info "To override, set ARCH environment variable (e.g., ARCH=amd64)"
    fi
    
    case ${ARCH} in
        amd64|x86_64)
            ARCH=amd64
            ;;
        arm64|aarch64)
            ARCH=arm64
            ;;
        ppc64le)
            ARCH=ppc64le
            ;;
        *)
            fatal "Unsupported architecture ${ARCH}"
    esac
    
    info "Creating airgap bundle for architecture: ${ARCH}"
}

# --- Verify download tool is available ---
verify_downloader() {
    # Return failure if it doesn't exist or is no executable
    [ -x "$(command -v $1)" ] || return 1

    # Set verified executable as our downloader program and return success
    DOWNLOADER=$1
    return 0
}

# --- Detect operating system ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS=rhel
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    else
        fatal "Unable to detect operating system"
    fi
    
    info "Detected OS: ${OS} ${OS_VERSION}"
}

# --- Check and configure SELinux ---
check_selinux() {
    if command -v getenforce >/dev/null 2>&1; then
        SELINUX_STATUS=$(getenforce)
        if [ "${SELINUX_STATUS}" != "Disabled" ] && [ "${SELINUX_STATUS}" != "Permissive" ]; then
            if [ "${INSTALL_K8S_SELINUX_WARN}" = true ]; then
                warn "SELinux is enabled (${SELINUX_STATUS}). This may cause issues with Kubernetes."
                warn "Consider disabling SELinux or setting it to permissive mode."
            else
                info "Setting SELinux to permissive mode"
                $SUDO setenforce 0 || true
                $SUDO sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config || true
            fi
        fi
    fi
}

# --- Verify K8S endpoint format ---
verify_k8s_endpoint() {
    case "${K8S_CONTROL_PLANE_ENDPOINT}" in
        "")
            ;;
        https://*)
            ;;
        *)
            fatal "Only https:// URLs are supported for K8S_CONTROL_PLANE_ENDPOINT (have ${K8S_CONTROL_PLANE_ENDPOINT})"
            ;;
    esac
}

# --- determine kubernetes version (fetch latest if not specified) ---
determine_k8s_version() {
    if [ -z "${K8S_VERSION}" ]; then
        info "K8S_VERSION not specified, fetching latest stable version..."
        VERSION_FILE=$(mktemp)
        download "${VERSION_FILE}" https://dl.k8s.io/release/stable.txt
        K8S_VERSION=$(cat "${VERSION_FILE}" | sed 's/^v//')
        rm -f "${VERSION_FILE}"
        info "Using Kubernetes version: ${K8S_VERSION}"
    fi
}

# --- define needed environment variables ---
setup_versions() {
    # --- set containerd version ---
    CONTAINERD_VERSION=${INSTALL_K8S_CONTAINERD_VERSION:-2.2.2}
    
    # --- set runc version ---
    RUNC_VERSION=${INSTALL_K8S_RUNC_VERSION:-1.4.1}
    
    # --- set crictl version ---
    CRICTL_VERSION=${INSTALL_K8S_CRICTL_VERSION:-1.35.0}
    
    # --- set kubernetes version ---
    K8S_VERSION=${INSTALL_K8S_VERSION:-}
    determine_k8s_version
    
    # --- set Calico version ---
    CALICO_VERSION=${INSTALL_K8S_CALICO_VERSION:-v3.27.5}
    
    # --- set air-gapped bundle output directory ---
    AIRGAP_BUNDLE_OUTPUT=${INSTALL_K8S_AIRGAP_BUNDLE_OUTPUT:-./k8s-airgap-bundle}
}

setup_env() {
    # --- use command args if passed or create default ---
    case "$1" in
        # --- if we only have flags discover if command should be init or join ---
        (-*|"")
            if [ -z "${K8S_CONTROL_PLANE_ENDPOINT}" ]; then
                CMD_K8S=init
            else
                if [ -z "${K8S_TOKEN}" ]; then
                    fatal "Defaulted kubeadm exec command to 'join' because K8S_CONTROL_PLANE_ENDPOINT is defined, but K8S_TOKEN is not defined."
                fi
                CMD_K8S=join
            fi
        ;;
        # --- command is provided ---
        (*)
            CMD_K8S=$1
            shift
        ;;
    esac

    verify_k8s_endpoint

    # Store additional arguments (without the command)
    CMD_K8S_ARGS="$@"

    # --- use sudo if we are not already root ---
    SUDO=sudo
    if [ $(id -u) -eq 0 ]; then
        SUDO=
    fi

    # --- set versions ---
    setup_versions

    # --- set CNI plugin flag ---
    INSTALL_CNI=${INSTALL_K8S_CNI:-false}
    
    # --- set Calico installation type ---
    CALICO_INSTALLATION_TYPE=${INSTALL_K8S_CALICO_INSTALLATION_TYPE:-manifest}
    
    # --- set pod subnet ---
    POD_SUBNET=${INSTALL_K8S_POD_SUBNET:-172.20.0.0/16}
    
    # --- set single node flag ---
    SINGLE_NODE=${INSTALL_K8S_SINGLE_NODE:-false}
    
    # --- set air-gapped bundle directory ---
    AIRGAP_BUNDLE_DIR=${INSTALL_K8S_AIRGAP_BUNDLE_DIR:-}
}

# --- create temporary directory and cleanup ---
setup_tmp() {
    TMP_DIR=$(mktemp -d -t k8s-install.XXXXXXXXXX)
    TMP_METADATA="${TMP_DIR}/metadata"
    cleanup() {
        code=$?
        set +e
        trap - EXIT
        rm -rf ${TMP_DIR}
        exit $code
    }
    trap cleanup INT EXIT
}

# --- use desired downloader ---
download() {
    [ $# -eq 2 ] || fatal 'download needs exactly 2 arguments'

    case $DOWNLOADER in
        curl)
            curl -o $1 -sfL $2
            ;;
        wget)
            wget -qO $1 $2
            ;;
        *)
            fatal "Incorrect executable '${DOWNLOADER}'"
            ;;
    esac

    # Abort if download command failed
    [ $? -eq 0 ] || fatal 'Download failed'
}

# --- get download URLs ---
get_containerd_url() { echo "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"; }
get_runc_url() { echo "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH}"; }
get_crictl_url() { echo "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${ARCH}.tar.gz"; }
get_calico_operator_url() { echo "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"; }
get_calico_custom_resources_url() { echo "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"; }
get_calico_manifest_url() { echo "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"; }


# --- get download URL for containerd service ---
# --- create containerd service file content ---
create_containerd_service_content() {
    cat << 'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
}

# --- download or use cached file from bundle ---
download_or_use_bundle() {
    local output_path=$1
    local url=$2
    local bundle_relative_path=$3
    
    # If air-gapped bundle directory is set, try to use cached file
    if [ -n "${AIRGAP_BUNDLE_DIR}" ]; then
        local bundle_file="${AIRGAP_BUNDLE_DIR}/${bundle_relative_path}"
        if [ -f "${bundle_file}" ]; then
            info "Using cached file from bundle: ${bundle_relative_path}"
            cp "${bundle_file}" "${output_path}"
            return 0
        else
            warn "File not found in bundle: ${bundle_relative_path}"
            if [ "${INSTALL_K8S_SKIP_DOWNLOAD}" = true ]; then
                fatal "Cannot proceed without file: ${bundle_relative_path}"
            fi
            warn "Attempting to download from internet..."
        fi
    fi
    
    # Download from internet
    download "${output_path}" "${url}"
}

# --- install kubeadm for bundle creation ---
install_kubeadm_for_bundle() {
    command -v kubeadm >/dev/null 2>&1 && { info "kubeadm is already installed: $(kubeadm version -o short 2>/dev/null || echo 'version unknown')"; return 0; }
    
    info "kubeadm not found, installing to temporary location for image list generation..."
    KUBE_RELEASE="v${K8S_VERSION}"
    info "Downloading kubeadm ${KUBE_RELEASE} for ${ARCH}..."
    
    TMP_KUBEADM="${TMP_DIR}/kubeadm"
    download "${TMP_KUBEADM}" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubeadm"
    chmod 755 "${TMP_KUBEADM}"
    
    # Add TMP_DIR to PATH so kubeadm can be found
    export PATH="${TMP_DIR}:${PATH}"
    
    command -v kubeadm >/dev/null 2>&1 && info "✓ kubeadm available in temporary location: $(kubeadm version -o short)" || fatal "kubeadm installation failed"
}

# --- create air-gapped bundle ---
create_airgap_bundle() {
    info "Creating air-gapped bundle in ${AIRGAP_BUNDLE_OUTPUT}"
    
    # Create bundle directory structure (separate commands for sh compatibility)
    mkdir -p "${AIRGAP_BUNDLE_OUTPUT}/binaries"
    mkdir -p "${AIRGAP_BUNDLE_OUTPUT}/manifests"
    mkdir -p "${AIRGAP_BUNDLE_OUTPUT}/scripts"
    
    # Download containerd
    info "Downloading containerd ${CONTAINERD_VERSION}..."
    download "${AIRGAP_BUNDLE_OUTPUT}/binaries/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz" "$(get_containerd_url)"
    
    # Download runc
    info "Downloading runc ${RUNC_VERSION}..."
    download "${AIRGAP_BUNDLE_OUTPUT}/binaries/runc.${ARCH}" "$(get_runc_url)"
    
    # Download crictl
    info "Downloading crictl ${CRICTL_VERSION}..."
    
    # Download Kubernetes binaries (kubelet, kubeadm, kubectl)
    info "Downloading Kubernetes binaries ${K8S_VERSION}..."
    
    KUBE_RELEASE="v${K8S_VERSION}"
    
    info "Downloading kubelet ${KUBE_RELEASE}..."
    download "${AIRGAP_BUNDLE_OUTPUT}/binaries/kubelet" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubelet"
    
    info "Downloading kubeadm ${KUBE_RELEASE}..."
    download "${AIRGAP_BUNDLE_OUTPUT}/binaries/kubeadm" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubeadm"
    
    info "Downloading kubectl ${KUBE_RELEASE}..."
    download "${AIRGAP_BUNDLE_OUTPUT}/binaries/kubectl" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubectl"

    download "${AIRGAP_BUNDLE_OUTPUT}/binaries/crictl-v${CRICTL_VERSION}-linux-${ARCH}.tar.gz" "$(get_crictl_url)"
    
    # Download Calico manifests
    info "Downloading Calico ${CALICO_VERSION} manifests..."
    download "${AIRGAP_BUNDLE_OUTPUT}/manifests/tigera-operator.yaml" "$(get_calico_operator_url)"
    download "${AIRGAP_BUNDLE_OUTPUT}/manifests/calico-custom-resources.yaml" "$(get_calico_custom_resources_url)"
    download "${AIRGAP_BUNDLE_OUTPUT}/manifests/calico.yaml" "$(get_calico_manifest_url)"
    
    # Patch Calico manifest to use quay.io instead of docker.io
    info "Patching Calico manifest images from docker.io to quay.io..."
    sed -E -i 's|docker\.io/calico/([^:"[:space:]]+):([^"[:space:]]+)|quay.io/calico/\1:\2|g' "${AIRGAP_BUNDLE_OUTPUT}/manifests/calico.yaml"
    
    # Check for podman (required for air-gapped bundle)
    if ! command -v podman >/dev/null 2>&1; then
        fatal "ERROR: podman is required for creating air-gapped bundles with container images.

Podman is needed to pull and save Kubernetes and Calico container images.

Please install podman:
  Debian/Ubuntu: sudo apt-get install -y podman
  RHEL/CentOS:   sudo yum install -y podman
  Fedora:        sudo dnf install -y podman

Then re-run: ./kubeadm-install.sh --airgap-bundle"
    fi
    
    info "Podman detected, preparing to save container images..."
    
    # Install kubeadm if not present (needed for image list)
    install_kubeadm_for_bundle
    
    info "Saving container images using kubeadm and podman..."
    mkdir -p "${AIRGAP_BUNDLE_OUTPUT}/images"
    
    # Get Kubernetes images using kubeadm
    info "Getting Kubernetes images list..."
    kubeadm config images list ${K8S_VERSION:+--kubernetes-version="${K8S_VERSION}"} > "${AIRGAP_BUNDLE_OUTPUT}/images/k8s-images.txt"
    
    # Extract Calico images from manifest files and normalize registry to quay.io
    find "${AIRGAP_BUNDLE_OUTPUT}/manifests" -maxdepth 1 -type f -name '*.yaml' -print0 | \
        xargs -0 grep -hE '^[[:space:]]*image:[[:space:]]*[[:graph:]]+' | \
        sed -E 's|^[[:space:]]*image:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$|\1|' | \
        sed -E '/^image:$/d' | \
        sed -E 's|^docker\.io/calico/|quay.io/calico/|g' | \
        sort -u > "${AIRGAP_BUNDLE_OUTPUT}/images/calico-images.txt"
    
    # Combine all images
    cat "${AIRGAP_BUNDLE_OUTPUT}/images/k8s-images.txt" \
        "${AIRGAP_BUNDLE_OUTPUT}/images/calico-images.txt" | \
        sort -u > "${AIRGAP_BUNDLE_OUTPUT}/images/all-images.txt"
    
    # Pull and save images
    info "Pulling and saving images..."
    mkdir -p "${AIRGAP_BUNDLE_OUTPUT}/images/tars"
    
    while IFS= read -r image; do
        [ -z "$image" ] && continue
        
        filename=$(echo "$image" | tr '/:' '_').tar
        tarfile="${AIRGAP_BUNDLE_OUTPUT}/images/tars/${filename}"
        
        # Skip if already exists
        if [ -f "${tarfile}" ]; then
            info "Skipping (already exists): $image"
            continue
        fi
        
        info "Processing: $image"
        if podman pull "$image"; then
            # Use docker-archive format and ensure clean save
            if podman save --format docker-archive "$image" -o "${tarfile}"; then
                info "  ✓ Saved: ${filename}"
            else
                warn "  ✗ Failed to save: $image"
                rm -f "${tarfile}"
            fi
        else
            warn "  ✗ Failed to pull: $image"
        fi
    done < "${AIRGAP_BUNDLE_OUTPUT}/images/all-images.txt"
    
    # Create load script
    cat > "${AIRGAP_BUNDLE_OUTPUT}/load-images.sh" <<'EOFLOAD'
#!/bin/bash
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to script directory to ensure relative paths work
cd "$SCRIPT_DIR" || exit 1

# Check if images/tars directory exists
if [ ! -d "images/tars" ]; then
    echo "ERROR: images/tars directory not found in $SCRIPT_DIR"
    exit 1
fi

# Check if there are any tar files
if ! ls images/tars/*.tar >/dev/null 2>&1; then
    echo "ERROR: No .tar files found in images/tars/"
    exit 1
fi

# Load each image
for tar in images/tars/*.tar; do
    echo "Loading image: $tar"
    if ! sudo /usr/local/bin/ctr -n k8s.io images import "$tar"; then
        echo "WARNING: Failed to load $tar"
    fi
done

echo "Image loading complete"
EOFLOAD
    chmod +x "${AIRGAP_BUNDLE_OUTPUT}/load-images.sh"
    
    # Create version info file
    cat > "${AIRGAP_BUNDLE_OUTPUT}/versions.env" <<EOF
# Kubernetes Air-gapped Bundle
# Created: $(date)
# Architecture: ${ARCH}

CONTAINERD_VERSION=${CONTAINERD_VERSION}
RUNC_VERSION=${RUNC_VERSION}
CRICTL_VERSION=${CRICTL_VERSION}
CALICO_VERSION=${CALICO_VERSION}
K8S_VERSION=${K8S_VERSION}
ARCH=${ARCH}
EOF
    
    # Create README
    cat > "${AIRGAP_BUNDLE_OUTPUT}/README.md" <<'EOFREADME'
# Kubernetes Air-gapped Installation Bundle

This bundle contains all necessary artifacts for installing Kubernetes in an air-gapped environment.

## Contents

- `binaries/` - Runtime and Kubernetes binaries (containerd, runc, CNI plugins, crictl, kubelet, kubeadm, kubectl)
- `manifests/` - Kubernetes manifests (Calico CNI)
- `images/` - Container images and image lists
- `images/tars/` - Saved container image tar files (Kubernetes and Calico images)
- `versions.env` - Version information for all components
- `load-images.sh` - Script to load container images into containerd

## Usage

### 1. Transfer Bundle

Transfer this directory to your air-gapped environment:

```bash
# On internet-connected machine (bundle already created)
tar czf k8s-airgap-bundle.tar.gz k8s-airgap-bundle/

# Copy to air-gapped environment
scp k8s-airgap-bundle.tar.gz user@airgapped-host:/path/
```

### 2. Extract Bundle

On air-gapped machine:

```bash
tar xzf k8s-airgap-bundle.tar.gz
cd k8s-airgap-bundle
```

### 3. Initialize Control Plane

On the control plane node:

```bash
# Initialize cluster
sudo kubeadm init --pod-network-cidr=172.20.0.0/16

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico CNI (default manifest mode using bundle manifest)
sed -i 's|docker.io/calico/|quay.io/calico/|g' manifests/calico.yaml
kubectl create -f manifests/calico.yaml
```

### 4. Join Worker Nodes

On control plane, get join command:
```bash
kubeadm token create --print-join-command
```

On each worker node:
```bash
# 1. Transfer and extract the bundle
cd k8s-airgap-bundle

# 2. Run the installation script (automatically installs binaries and loads images)
export INSTALL_K8S_AIRGAP_BUNDLE_DIR=$(pwd)
export INSTALL_K8S_EXEC="join"
./kubeadm-install.sh

# 3. Join the cluster using the command from control plane
sudo kubeadm join <control-plane-endpoint>:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

**Note:** The installation script automatically loads container images from the bundle when `INSTALL_K8S_AIRGAP_BUNDLE_DIR` is set.

## Important Notes

### Container Images

Container images for Kubernetes and Calico are included in `images/tars/` directory.

**Automatic Loading:** When using the installation script with `INSTALL_K8S_AIRGAP_BUNDLE_DIR` set, container images are automatically loaded into containerd during installation.

**Manual Loading (if needed):** You can also manually load images using the provided script:
```bash
./load-images.sh
```

The script uses containerd's `ctr` tool to import images into the `k8s.io` namespace and requires sudo privileges.

### Kubernetes Binaries

This bundle includes Kubernetes binaries (kubelet, kubeadm, kubectl) that can be installed directly.
These are architecture-specific binaries downloaded from the official Kubernetes release.

**Manual Installation:**
```bash
sudo install -o root -g root -m 0755 binaries/kubelet /usr/bin/kubelet
sudo install -o root -g root -m 0755 binaries/kubeadm /usr/bin/kubeadm
sudo install -o root -g root -m 0755 binaries/kubectl /usr/bin/kubectl
```

**Using Installation Script:**
```bash
export INSTALL_K8S_AIRGAP_BUNDLE_DIR=/path/to/k8s-airgap-bundle
./kubeadm-install.sh
```

The installation script will automatically use binaries from the bundle directory.

### Runtime Components

The bundle includes:
- **containerd**: Container runtime
- **runc**: OCI runtime
- **CNI plugins**: Network plugins
- **crictl**: Container runtime CLI tool

These will be installed automatically when using the `kubeadm-install.sh` script with the bundle.

## Troubleshooting

### Check Services
```bash
sudo systemctl status containerd
sudo systemctl status kubelet
```

### View Logs
```bash
sudo journalctl -xeu kubelet
sudo journalctl -xeu containerd
```

### Verify Bundle Contents
```bash
ls -lh binaries/
ls -lh manifests/
ls -lh images/tars/
cat versions.env
```

### Verify Images Loaded
```bash
sudo crictl images
# Or using ctr directly
sudo ctr -n k8s.io images ls
```

### Common Issues

1. **Images not loading automatically**: Ensure `INSTALL_K8S_AIRGAP_BUNDLE_DIR` is set correctly and containerd is running
2. **Permission denied**: The installation script requires sudo privileges to load images
3. **Binary not found**: Ensure binaries are installed to /usr/bin or in PATH
4. **Kubelet not starting**: Check that container images are loaded (run `sudo crictl images`) and containerd is running
EOFREADME
    
    info ""
    info "=========================================="
    info "✓ Air-gapped bundle created successfully!"
    info "=========================================="
    info ""
    info "Bundle location: ${AIRGAP_BUNDLE_OUTPUT}"
    info "Bundle size: $(du -sh ${AIRGAP_BUNDLE_OUTPUT} 2>/dev/null | cut -f1 || echo 'N/A')"
    info ""
    info "Next steps:"
    info "1. Create tarball:"
    info "   tar czf k8s-airgap-bundle.tar.gz ${AIRGAP_BUNDLE_OUTPUT}"
    info ""
    info "2. Transfer to air-gapped environment along with this script"
    info ""
    info "3. On air-gapped machine, extract and install:"
    info "   tar xzf k8s-airgap-bundle.tar.gz"
    info "   export INSTALL_K8S_AIRGAP_BUNDLE_DIR=\$(pwd)/${AIRGAP_BUNDLE_OUTPUT}"
    info "   ./kubeadm-install.sh"
    info ""
    info "See ${AIRGAP_BUNDLE_OUTPUT}/README.md for detailed instructions"
    info "=========================================="
    
    exit 0
}

# --- disable swap ---
disable_swap() {
    info "Disabling swap"
    $SUDO swapoff -a
    $SUDO sed -i '/ swap / s/^/#/' /etc/fstab || true
}

# --- load required kernel modules ---
load_kernel_modules() {
    info "Loading required kernel modules"
    
    cat <<EOF | $SUDO tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
nf_conntrack
EOF

    $SUDO modprobe overlay || warn "Failed to load overlay module"
    $SUDO modprobe br_netfilter || warn "Failed to load br_netfilter module"
    $SUDO modprobe nf_conntrack || warn "Failed to load nf_conntrack module"
}

# --- configure sysctl parameters ---
configure_sysctl() {
    info "Configuring sysctl parameters for Kubernetes"
    
    cat <<EOF | $SUDO tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    # Apply only the k8s.conf settings to avoid errors from other system configs
    $SUDO sysctl -p /etc/sysctl.d/k8s.conf >/dev/null 2>&1 || warn "Some sysctl parameters could not be set"
}

# --- install containerd from GitHub releases ---
install_containerd() {
    info "Installing containerd from GitHub releases"
    info "Using containerd version: ${CONTAINERD_VERSION}"
    
    # Install required dependencies
    case ${OS} in
        ubuntu|debian)
            $SUDO apt-get update
            $SUDO apt-get install -y libseccomp2
            ;;
        centos|rhel)
            $SUDO yum install -y libseccomp
            ;;
        *)
            warn "Unknown OS, skipping dependency installation"
            ;;
    esac
    
    # Download or use cached containerd
    info "Getting containerd ${CONTAINERD_VERSION}..."
    CONTAINERD_TAR="${TMP_DIR}/containerd.tar.gz"
    download_or_use_bundle "${CONTAINERD_TAR}" "$(get_containerd_url)" "binaries/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
    
    # Extract and install containerd binaries
    info "Installing containerd binaries to /usr/local/bin"
    $SUDO tar Cxzvf /usr/local ${CONTAINERD_TAR}
    
    # Download or use cached runc
    info "Getting runc ${RUNC_VERSION}..."
    download_or_use_bundle "${TMP_DIR}/runc" "$(get_runc_url)" "binaries/runc.${ARCH}"
    $SUDO install -m 755 ${TMP_DIR}/runc /usr/local/sbin/runc
    
    # Create containerd configuration directory
    $SUDO mkdir -p /etc/containerd
    
    # Generate default containerd config
    /usr/local/bin/containerd config default | $SUDO tee /etc/containerd/config.toml >/dev/null
    
    # Enable SystemdCgroup
    $SUDO sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Create containerd systemd service
    info "Creating containerd systemd service"
    create_containerd_service_content | $SUDO tee /etc/systemd/system/containerd.service >/dev/null
    
    # Start and enable containerd
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable containerd
    $SUDO systemctl start containerd
    
    info "Containerd installed and started successfully"
}

# --- install container runtime ---
install_container_runtime() {
    install_containerd
    
    # Auto-load container images in air-gapped mode
    if [ -n "${AIRGAP_BUNDLE_DIR}" ] && [ -f "${AIRGAP_BUNDLE_DIR}/load-images.sh" ]; then
        info "Air-gapped mode detected - loading container images automatically..."
        if $SUDO bash "${AIRGAP_BUNDLE_DIR}/load-images.sh"; then
            info "Container images loaded successfully"
        else
            warn "Failed to load some container images - you may need to run load-images.sh manually"
        fi
    fi
}

# --- install kubernetes packages ---
install_kubernetes_packages() {
    if [ "${INSTALL_K8S_SKIP_DOWNLOAD}" = true ]; then
        info 'Skipping kubernetes packages download'
        return
    fi

    info "Installing Kubernetes binaries from dl.k8s.io"
    
    KUBE_RELEASE="v${K8S_VERSION}"
    
    # Download or use cached kubelet
    info "Installing kubelet ${KUBE_RELEASE}..."
    download_or_use_bundle "${TMP_DIR}/kubelet" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubelet" "binaries/kubelet"
    $SUDO install -m 755 "${TMP_DIR}/kubelet" /usr/bin/kubelet
    
    # Download or use cached kubeadm
    info "Installing kubeadm ${KUBE_RELEASE}..."
    download_or_use_bundle "${TMP_DIR}/kubeadm" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubeadm" "binaries/kubeadm"
    $SUDO install -m 755 "${TMP_DIR}/kubeadm" /usr/bin/kubeadm
    
    # Download or use cached kubectl
    info "Installing kubectl ${KUBE_RELEASE}..."
    download_or_use_bundle "${TMP_DIR}/kubectl" "https://dl.k8s.io/release/${KUBE_RELEASE}/bin/linux/${ARCH}/kubectl" "binaries/kubectl"
    $SUDO install -m 755 "${TMP_DIR}/kubectl" /usr/bin/kubectl
    
    # Create kubelet systemd service
    info "Creating kubelet systemd service"
    $SUDO mkdir -p /etc/systemd/system/kubelet.service.d
    
    $SUDO tee /etc/systemd/system/kubelet.service >/dev/null <<'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    $SUDO tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf >/dev/null <<'EOF'
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF
    
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable kubelet
    
    info "Kubernetes binaries installed successfully"
}

# --- configure firewall ---
configure_firewall() {
    info "Configuring firewall rules"
    
    # Check if firewalld is running
    if systemctl is-active --quiet firewalld; then
        if [ "${CMD_K8S}" = "init" ]; then
            # Control plane ports
            $SUDO firewall-cmd --permanent --add-port=6443/tcp
            $SUDO firewall-cmd --permanent --add-port=2379-2380/tcp
            $SUDO firewall-cmd --permanent --add-port=10250/tcp
            $SUDO firewall-cmd --permanent --add-port=10251/tcp
            $SUDO firewall-cmd --permanent --add-port=10252/tcp
            $SUDO firewall-cmd --permanent --add-port=10255/tcp
        fi
        # Worker node ports (also needed on control plane)
        $SUDO firewall-cmd --permanent --add-port=10250/tcp
        $SUDO firewall-cmd --permanent --add-port=30000-32767/tcp
        $SUDO firewall-cmd --reload
    else
        info "Firewalld not running, skipping firewall configuration"
    fi
}

# --- check if kubernetes is already installed ---
check_existing_cluster() {
    if [ -f /etc/kubernetes/admin.conf ] || [ -f /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
        warn "Existing Kubernetes cluster detected!"
        warn "Found existing configuration files in /etc/kubernetes/"
        warn ""
        warn "To reinstall, you must first reset the existing cluster:"
        warn "  sudo kubeadm reset -f"
        warn "  sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet"
        warn "  sudo rm -rf ~/.kube"
        warn ""
        warn "Or run the uninstall script:"
        warn "  sudo /usr/bin/k8s-uninstall.sh"
        warn ""
        fatal "Cannot proceed with existing cluster. Please reset first."
    fi
}

# --- initialize kubernetes control plane ---
init_control_plane() {
    info "Initializing Kubernetes control plane"
    
    # Check for existing cluster
    check_existing_cluster
    
    PREFLIGHT_FLAG=""
    if [ "${INSTALL_K8S_SKIP_PREFLIGHT}" = true ]; then
        PREFLIGHT_FLAG="--ignore-preflight-errors=all"
    fi
    
    # Build kubeadm init command with pod network CIDR (use full path)
    INIT_CMD="/usr/bin/kubeadm init --pod-network-cidr=${POD_SUBNET}"
    
    # Add preflight flag if set
    if [ -n "${PREFLIGHT_FLAG}" ]; then
        INIT_CMD="${INIT_CMD} ${PREFLIGHT_FLAG}"
    fi
    
    # Add any additional arguments
    if [ -n "${CMD_K8S_ARGS}" ]; then
        INIT_CMD="${INIT_CMD} ${CMD_K8S_ARGS}"
    fi
    
    # Execute kubeadm init
    $SUDO ${INIT_CMD}
    
    # Setup kubeconfig for root user
    $SUDO mkdir -p /root/.kube
    $SUDO cp -f /etc/kubernetes/admin.conf /root/.kube/config
    $SUDO chown root:root /root/.kube/config
    
    # Setup kubeconfig for regular user if not root
    if [ $(id -u) -ne 0 ]; then
        # Use the current user's home
        USER_KUBE_DIR="$HOME/.kube"
        # Create dir and copy using sudo
        mkdir -p "${USER_KUBE_DIR}"
        $SUDO cp -f /etc/kubernetes/admin.conf "${USER_KUBE_DIR}/config"
        # Fix ownership so you can use it without sudo
        $SUDO chown $(id -u):$(id -g) "${USER_KUBE_DIR}/config"
        info "Kubeconfig copied to ${USER_KUBE_DIR}/config"
    fi
    
    # Configure for single-node if requested
    if [ "${SINGLE_NODE}" = true ]; then
        info "Configuring cluster for single-node operation"
        # Remove taints from control-plane to allow pod scheduling
        KUBECONFIG=/etc/kubernetes/admin.conf $SUDO /usr/bin/kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
        KUBECONFIG=/etc/kubernetes/admin.conf $SUDO /usr/bin/kubectl taint nodes --all node-role.kubernetes.io/master- || true
        info "Control-plane node is now schedulable for workload pods"
    fi
    
    info "Control plane initialized successfully"
}

# --- join kubernetes cluster ---
join_cluster() {
    info "Joining Kubernetes cluster"
    
    PREFLIGHT_FLAG=""
    if [ "${INSTALL_K8S_SKIP_PREFLIGHT}" = true ]; then
        PREFLIGHT_FLAG="--ignore-preflight-errors=all"
    fi
    
    # Execute kubeadm join with endpoint, token, flags and additional arguments (use full path)
    $SUDO /usr/bin/kubeadm join ${K8S_CONTROL_PLANE_ENDPOINT} \
        --token ${K8S_TOKEN} \
        ${PREFLIGHT_FLAG} \
        ${CMD_K8S_ARGS}
    
    info "Successfully joined the cluster"
}

# --- install crictl ---
install_crictl() {
    info "Installing crictl (CRI tools)"
    
    CRICTL_TAR="${TMP_DIR}/crictl.tar.gz"
    download_or_use_bundle "${CRICTL_TAR}" "$(get_crictl_url)" "binaries/crictl-v${CRICTL_VERSION}-linux-${ARCH}.tar.gz"
    
    $SUDO tar -C /usr/local/bin -xzf ${CRICTL_TAR}
    
    # Create crictl config
    $SUDO mkdir -p /etc
    cat <<EOF | $SUDO tee /etc/crictl.yaml >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
    
    info "crictl installed successfully"
}

# --- install Calico CNI plugin using operator ---
install_calico_operator() {
    info "Installing Calico ${CALICO_VERSION} using Tigera operator"
    
    KUBECONFIG=/etc/kubernetes/admin.conf
    export KUBECONFIG
    
    # Install Tigera Calico operator
    info "Installing Tigera operator..."
    if [ -n "${AIRGAP_BUNDLE_DIR}" ] && [ -f "${AIRGAP_BUNDLE_DIR}/manifests/tigera-operator.yaml" ]; then
        info "Using Tigera operator manifest from bundle"
        $SUDO /usr/bin/kubectl create -f "${AIRGAP_BUNDLE_DIR}/manifests/tigera-operator.yaml"
    else
        $SUDO /usr/bin/kubectl create -f "$(get_calico_operator_url)"
    fi
    
    # Wait for operator to be ready and CRDs to be installed
    info "Waiting for Tigera operator to be ready..."
    sleep 10
    
    # Wait for the operator deployment to be available
    for i in $(seq 1 30); do
        $SUDO /usr/bin/kubectl get deployment tigera-operator -n tigera-operator 2>/dev/null | grep -q "1/1" && { info "Tigera operator is ready"; break; }
        [ $i -eq 30 ] && warn "Tigera operator may not be fully ready yet"
        sleep 2
    done
    
    # Wait for CRDs to be installed
    info "Waiting for Calico CRDs to be installed..."
    for i in $(seq 1 30); do
        $SUDO /usr/bin/kubectl get crd installations.operator.tigera.io 2>/dev/null && { info "Calico CRDs are installed"; break; }
        [ $i -eq 30 ] && warn "Calico CRDs may not be fully installed yet"
        sleep 2
    done
    
    # Download or use cached custom resources manifest
    CALICO_CR="${TMP_DIR}/calico-custom-resources.yaml"
    download_or_use_bundle "${CALICO_CR}" "$(get_calico_custom_resources_url)" "manifests/calico-custom-resources.yaml"
    
    # Update pod subnet in custom resources
    $SUDO sed -i "s|cidr:.*|cidr: ${POD_SUBNET}|g" ${CALICO_CR}
    
    # Apply custom resources
    info "Applying Calico custom resources..."
    $SUDO /usr/bin/kubectl create -f ${CALICO_CR}
    
    info "Waiting for calico-apiserver namespace to be created..."
    for i in $(seq 1 18); do
        $SUDO /usr/bin/kubectl get namespace calico-apiserver 2>/dev/null | grep -q Active && break
        sleep 5
    done
    
    info "Waiting for Calico API server deployment..."
    $SUDO /usr/bin/kubectl rollout status deployment calico-apiserver -n calico-apiserver --timeout=60s 2>/dev/null || warn "Calico API server may still be starting"
    
    info "Calico CNI plugin installed successfully using operator"
}

# --- install Calico CNI plugin using manifest ---
install_calico_manifest() {
    info "Installing Calico ${CALICO_VERSION} using manifest"
    
    KUBECONFIG=/etc/kubernetes/admin.conf
    export KUBECONFIG
    
    # Download or use cached Calico manifest
    CALICO_MANIFEST="${TMP_DIR}/calico.yaml"
    download_or_use_bundle "${CALICO_MANIFEST}" "$(get_calico_manifest_url)" "manifests/calico.yaml"
    
    # Update pod subnet in manifest
    $SUDO sed -i "s|# - name: CALICO_IPV4POOL_CIDR|- name: CALICO_IPV4POOL_CIDR|g" ${CALICO_MANIFEST}
    $SUDO sed -i "s|#   value: \"192.168.0.0/16\"|  value: \"${POD_SUBNET}\"|g" ${CALICO_MANIFEST}

    # Patch Calico images from docker.io to quay.io in manifest
    $SUDO sed -E -i 's|docker\.io/calico/([^:"[:space:]]+):([^"[:space:]]+)|quay.io/calico/\1:\2|g' ${CALICO_MANIFEST}
    
    # Apply manifest
    $SUDO /usr/bin/kubectl create -f ${CALICO_MANIFEST}
    
    info "Calico CNI plugin installed successfully using manifest"
}

# --- install Calico CNI plugin ---
install_cni_plugin() {
    if [ "${CMD_K8S}" != "init" ]; then
        return
    fi
    
    if [ "${INSTALL_CNI}" != "true" ]; then
        info "CNI installation not requested, skipping Calico installation"
        info "You need to install a CNI plugin manually for the cluster to be functional"
        return
    fi
    
    info "Installing Calico CNI plugin (${CALICO_INSTALLATION_TYPE} method)"
    
    case ${CALICO_INSTALLATION_TYPE} in
        operator)
            install_calico_operator
            ;;
        manifest)
            install_calico_manifest
            ;;
        *)
            warn "Unknown Calico installation type: ${CALICO_INSTALLATION_TYPE}. Using manifest method."
            install_calico_manifest
            ;;
    esac
    
    info "Waiting for Calico pods to be ready..."
    $SUDO /usr/bin/kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n calico-system --timeout=300s 2>/dev/null || \
    $SUDO /usr/bin/kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s 2>/dev/null || \
    warn "Calico pods may still be starting"
}

# --- create uninstall script ---
create_uninstall() {
    info "Creating uninstall script /usr/bin/k8s-uninstall.sh"
    $SUDO tee /usr/bin/k8s-uninstall.sh >/dev/null << 'EOF'
#!/bin/sh
[ $(id -u) -eq 0 ] || exec sudo "$0" "$@"

# Reset kubeadm
if [ -f /usr/bin/kubeadm ]; then
    /usr/bin/kubeadm reset -f
elif command -v kubeadm >/dev/null 2>&1; then
    kubeadm reset -f
fi

# Stop and disable kubelet service
if systemctl is-active --quiet kubelet; then
    systemctl stop kubelet
fi
if systemctl is-enabled --quiet kubelet 2>/dev/null; then
    systemctl disable kubelet
fi

# Remove Kubernetes binaries from /usr/bin
rm -f /usr/bin/kubelet
rm -f /usr/bin/kubeadm
rm -f /usr/bin/kubectl

# Remove kubelet systemd service files
rm -f /etc/systemd/system/kubelet.service
rm -rf /etc/systemd/system/kubelet.service.d

# Remove Kubernetes directories
rm -rf /etc/kubernetes
rm -rf /var/lib/etcd
rm -rf /var/lib/kubelet
rm -rf /var/lib/cni
rm -rf /etc/cni
rm -rf $HOME/.kube
rm -rf /root/.kube

# Remove iptables rules if iptables is available
if command -v iptables >/dev/null 2>&1; then
    iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
else
    echo "iptables not found, skipping iptables cleanup"
fi

# Remove containerd if installed from binary
if [ -f /etc/systemd/system/containerd.service ]; then
    systemctl stop containerd 2>/dev/null || true
    systemctl disable containerd 2>/dev/null || true
    rm -f /etc/systemd/system/containerd.service
    rm -f /usr/local/bin/containerd*
    rm -f /usr/local/bin/ctr
    rm -rf /etc/containerd
fi

# Remove runc
rm -f /usr/local/sbin/runc

# Remove crictl
rm -f /usr/local/bin/crictl
rm -f /etc/crictl.yaml

# Remove CNI plugins
rm -rf /opt/cni

# Remove kernel modules config
rm -f /etc/modules-load.d/k8s.conf

# Remove sysctl config
rm -f /etc/sysctl.d/k8s.conf

# Reload systemd
systemctl daemon-reload

echo "Kubernetes uninstalled successfully"
EOF
    $SUDO chmod 755 /usr/bin/k8s-uninstall.sh
}

# --- print cluster info ---
print_cluster_info() {
    if [ "${CMD_K8S}" = "init" ]; then
        info ""
        info "=========================================="
        if [ "${SINGLE_NODE}" = true ]; then
            info "🎉 Single-Node Kubernetes Cluster Ready!"
        else
            info "Kubernetes Control Plane Setup Complete!"
        fi
        info "=========================================="
        info ""
        
        if [ "${SINGLE_NODE}" = true ]; then
            info "✅ Single-node configuration applied"
            info "✅ Control-plane is schedulable for workloads"
            info ""
            info "Quick start commands:"
            info "  kubectl get nodes"
            info "  kubectl get pods -A"
            info "  kubectl run nginx --image=nginx --port=80"
            info "  kubectl get pods"
            info ""
        else
            info "To get the join command for worker nodes, run:"
            info "  kubeadm token create --print-join-command"
            info ""
            info "To check cluster status:"
            info "  kubectl get nodes"
            info "  kubectl get pods -A"
            info ""
        fi
        
        if [ "${INSTALL_CNI}" != "true" ]; then
            warn "Remember to install a CNI plugin for the cluster to be functional!"
            if [ "${CALICO_INSTALLATION_TYPE}" = "manifest" ]; then
                info "To install Calico CNI manually using manifest mode:"
                if [ -n "${AIRGAP_BUNDLE_DIR}" ]; then
                    info "  For air-gapped environment, use local manifest:"
                    info "  kubectl create -f ${AIRGAP_BUNDLE_DIR}/manifests/calico.yaml"
                else
                    info "  For online environment, run:"
                    info "  curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml -o calico.yaml"
                    info "  sed -i 's|docker.io/calico/|quay.io/calico/|g' calico.yaml"
                    info "  kubectl create -f calico.yaml"
                fi
            else
                info "To install Calico CNI manually using operator mode:"
                if [ -n "${AIRGAP_BUNDLE_DIR}" ]; then
                    info "  For air-gapped environment, use local manifests:"
                    info "  kubectl create -f ${AIRGAP_BUNDLE_DIR}/manifests/tigera-operator.yaml"
                    info "  kubectl create -f ${AIRGAP_BUNDLE_DIR}/manifests/calico-custom-resources.yaml"
                else
                    info "  For online environment, run:"
                    info "  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
                    info "  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"
                fi
            fi
        elif [ "${CALICO_INSTALLATION_TYPE}" = "manifest" ]; then
            info "✅ Calico CNI installed using manifest mode (default)"
            info "✅ Image registry patched from docker.io/calico to quay.io/calico"
        else
            info "✅ Calico CNI installed using ${CALICO_INSTALLATION_TYPE} method"
        fi
        
        if [ "${SINGLE_NODE}" = true ]; then
            info ""
            info "💡 Single-Node Tips:"
            info "  - All pods will run on this node"
            info "  - Suitable for development and testing"
            info "  - For production, consider multi-node setup"
        fi
        
        info ""
        info "🗑️  Uninstallation:"
        info "  To completely remove Kubernetes from this node, run:"
        info "  sudo /usr/bin/k8s-uninstall.sh"
        info ""
        info "  This will:"
        info "  - Reset kubeadm configuration"
        info "  - Remove all Kubernetes binaries (kubelet, kubeadm, kubectl)"
        info "  - Remove containerd and container runtime components"
        info "  - Clean up all Kubernetes directories and configurations"
        info "  - Remove systemd service files"
        info "  - Reset iptables rules"
    else
        info ""
        info "=========================================="
        info "Successfully Joined Kubernetes Cluster!"
        info "=========================================="
        info ""
        info "To remove this node from the cluster, run:"
        info "  sudo /usr/bin/k8s-uninstall.sh"
        info ""
    fi
}

# --- Verify downloader is available globally ---
verify_downloader curl || verify_downloader wget || fatal 'Can not find curl or wget for downloading files'

# --- Check for --airgap-bundle flag ---
for arg in "$@"; do
    case "$arg" in
        --airgap-bundle)
            # Set up minimal environment for bundle creation
            setup_airgap_arch
            setup_tmp
            
            # Set default versions if not specified
            setup_versions
            
            # Create the bundle
            create_airgap_bundle
            ;;
    esac
done

# --- re-evaluate args to include env command ---
eval set -- $(escape "${INSTALL_K8S_EXEC}") $(quote "$@")

# --- run the install process --
{
    verify_system
    setup_env "$@"
    setup_verify_arch
    setup_tmp
    detect_os
    
    # Create uninstall script early so it's available even if installation fails
    create_uninstall
    
    # Load versions from bundle if using air-gapped mode
    if [ -n "${AIRGAP_BUNDLE_DIR}" ]; then
        if [ -f "${AIRGAP_BUNDLE_DIR}/versions.env" ]; then
            info "Loading versions from air-gapped bundle"
            . "${AIRGAP_BUNDLE_DIR}/versions.env"
        else
            warn "Air-gapped bundle directory specified but versions.env not found"
        fi
    fi
    
    check_selinux
    
    # Check for existing cluster before proceeding
    check_existing_cluster
    
    disable_swap
    load_kernel_modules
    configure_sysctl
    install_container_runtime
    install_crictl
    install_kubernetes_packages
    configure_firewall
    
    if [ "${CMD_K8S}" = "init" ]; then
        init_control_plane
        install_cni_plugin
    elif [ "${CMD_K8S}" = "join" ]; then
        join_cluster
    else
        fatal "Unknown command: ${CMD_K8S}. Use 'init' or 'join'"
    fi
    
    print_cluster_info
}

# Made with Bob
