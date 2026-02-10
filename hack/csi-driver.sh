#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

info()  { echo -e "${BLUE}${BOLD}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}${BOLD}[WARN]${NC}  $*"; }
error() { echo -e "${RED}${BOLD}[ERROR]${NC} $*"; }

section() {
  echo
  echo -e "${GREEN}${BOLD}============================================================${NC}"
  echo -e "${GREEN}${BOLD} $*${NC}"
  echo -e "${GREEN}${BOLD}============================================================${NC}"
}

# ============================================================
# 0. BASIC CONFIG
# ============================================================
section "0. BASIC CONFIG"

# Default CSI version: latest unless overridden
if [[ -z "${CSI_VERSION:-}" ]]; then
  CSI_VERSION="$(
    curl -sf https://api.github.com/repos/kubernetes-sigs/ibm-powervs-block-csi-driver/releases/latest \
      | grep tag_name | cut -d '"' -f 4 || echo "v0.11.0"
  )"
fi
export CSI_VERSION

info "Using IBM PowerVS Block CSI Driver version: $CSI_VERSION"

# Required variables
required_vars=(
  KUBECONFIG
  INSTANCE_LIST_JSON
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    error "Required environment variable '$var' is not set"
    exit 1
  fi
done

info "Using KUBECONFIG = $KUBECONFIG"
kubectl get nodes

# ============================================================
# 2. PATCH PROVIDER ID FOR ALL NODES
# ============================================================
section "2. PATCH PROVIDERID FOR ALL NODES"


POWERVS_REGION=$(jq -r '.region' "$INSTANCE_LIST_JSON")
POWERVS_ZONE=$(jq -r '.zone' "$INSTANCE_LIST_JSON")
POWERVS_SERVICE_ID=$(jq -r '.serviceInstanceID' "$INSTANCE_LIST_JSON")

export POWERVS_REGION POWERVS_ZONE POWERVS_SERVICE_ID

for row in $(jq -c '.instances[]' "$INSTANCE_LIST_JSON"); do
  INSTANCE_ID=$(echo "$row" | jq -r '.id')
  NODE_NAME=$(echo "$row" | jq -r '.name')

  PROVIDER_ID="ibmpowervs://$POWERVS_REGION/$POWERVS_ZONE/$POWERVS_SERVICE_ID/$INSTANCE_ID"

  info "Patching providerID on node: $NODE_NAME"
  echo "       $PROVIDER_ID"

  kubectl patch node "$NODE_NAME" -p "{\"spec\":{\"providerID\":\"$PROVIDER_ID\"}}"
done

# ============================================================
# 3. CREATE & APPLY CSI SECRET
# ============================================================
section "3. CREATE CSI SECRET"

if [[ -z "${TF_VAR_powervs_api_key:-${IBMCLOUD_API_KEY:-}}" ]]; then
  error "No API key available in TF_VAR_powervs_api_key or IBMCLOUD_API_KEY"
  exit 1
fi

info "Creating ibm-secret"

kubectl create secret generic ibm-secret \
  -n kube-system \
  --from-literal=IBMCLOUD_API_KEY="${TF_VAR_powervs_api_key:-$IBMCLOUD_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ============================================================
# 4. INSTALL CSI DRIVER
# ============================================================
section "4. INSTALL IBM POWERVS BLOCK CSI DRIVER"

info "Installing IBM PowerVS Block CSI Driver version $CSI_VERSION"

kubectl apply -k \
  "https://github.com/kubernetes-sigs/ibm-powervs-block-csi-driver/deploy/kubernetes/overlays/stable/?ref=$CSI_VERSION"

# ============================================================
# 5. WAIT FOR CONTROLLER
# ============================================================
section "5. WAIT FOR POWERVS CSI CONTROLLER DEPLOYMENT"

info "[INFO] Waiting for powervs-csi-controller deployment to become available..."
if ! kubectl -n kube-system wait --for=condition=available deployment/powervs-csi-controller --timeout=300s; then
    error "[ERROR] CSI controller deployment not ready. Exiting."
    kubectl -n kube-system get deploy powervs-csi-controller
    exit 1
fi
# ============================================================
# 6. WAIT FOR NODE PODS
# ============================================================
section "6. WAIT FOR CSI DRIVER NODE PODS"

info "Waiting for all CSI driver node pods to be fully ready..."

info "Giving CSI node pods 2 minutes to stabilize..."
sleep 120

info "Checking CSI node pods readiness..."

end=$((SECONDS + 300)) # 5 min timeout
while [[ $SECONDS -lt $end ]]; do
    not_ready=$(kubectl -n kube-system get pods -l app.kubernetes.io/name=ibm-powervs-block-csi-driver \
        -o jsonpath='{range .items[*]}{.metadata.name}:{"ready="}{.status.containerStatuses[*].ready}{" "}{end}' | grep false || true)
    if [[ -z "$not_ready" ]]; then
        info "All CSI pods are fully ready."
        break
    fi

    info "Waiting for CSI pods to be ready..."
    sleep 10
done

# Final check
if [[ -n "$not_ready" ]]; then
    error "Some CSI driver node pods are not ready after waiting:"
    kubectl -n kube-system get pods -l app.kubernetes.io/name=ibm-powervs-block-csi-driver
    exit 1
fi


# info "[INFO] Waiting for CSI node pods to become ready..."
# if ! kubectl -n kube-system wait --for=condition=Ready pod -l app.kubernetes.io/name=ibm-powervs-block-csi-driver --timeout=300s; then
#     error "[ERROR] CSI node pods not ready. Exiting."
#     kubectl -n kube-system get pods -l app.kubernetes.io/name=ibm-powervs-block-csi-driver
#     exit 1
# fi

# ============================================================
# 7. VERIFY INSTALLATION
# ============================================================
section "7. VERIFY IBM POWERVS BLOCK CSI DRIVER INSTALLATION"

kubectl get deploy -n kube-system -l app.kubernetes.io/name=ibm-powervs-block-csi-driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=ibm-powervs-block-csi-driver

# ============================================================
# 8. LABEL NODES
# ============================================================
section "8. LABEL NODES"

for row in $(jq -c '.instances[]' "$INSTANCE_LIST_JSON"); do
  INSTANCE_ID=$(echo "$row" | jq -r '.id')
  NODE_NAME=$(echo "$row" | jq -r '.name')

  kubectl label node "$NODE_NAME" \
    powervs.kubernetes.io/cloud-instance-id="$POWERVS_SERVICE_ID" --overwrite

  kubectl label node "$NODE_NAME" \
    powervs.kubernetes.io/pvm-instance-id="$INSTANCE_ID" --overwrite

  info "Labeled $NODE_NAME"
done

# ============================================================
# 9. RUN CSI E2E TESTS
# ============================================================
section "9. RUN IBM PowerVS Block CSI Driver E2E TESTS"

info "Cloning IBM PowerVS Block CSI Driver repo"
rm -rf ibm-powervs-block-csi-driver
git clone https://github.com/kubernetes-sigs/ibm-powervs-block-csi-driver.git
cd ibm-powervs-block-csi-driver

info "Ensuring ginkgo exists"

export GOPATH="${GOPATH:-$(go env GOPATH || echo /root/go)}"
export PATH="$PATH:$GOPATH/bin"

if ! command -v ginkgo >/dev/null; then
  warn "ginkgo not found. Installing..."
  go install github.com/onsi/ginkgo/v2/ginkgo@latest
fi

command -v ginkgo >/dev/null || { error "ginkgo installation failed"; exit 1; }

info "Running CSI driver E2E tests"
ginkgo --junit-report="$ARTIFACTS/junit_report.xml" ./tests/e2e

section "CSI E2E TESTS COMPLETED SUCCESSFULLY"
