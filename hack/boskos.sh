#!/bin/bash

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

set -o errexit
set -o nounset
set -o pipefail

USER=${USER:-"k8s-prow-job"}
RESOURCE_TYPE=${RESOURCE_TYPE:-"powervs"}

error() {
    echo "$@" >&2
    exit 1
}

trap 'cleanup ${HEART_BEAT_PID:-}' EXIT

release_account(){
    url="http://${BOSKOS_HOST}/release?name=${BOSKOS_RESOURCE_NAME}&dest=dirty&owner=${USER}"
    status_code=$(curl -w '%{http_code}' -X POST ${url})

    if [[ ${status_code} != 200 ]]; then
        error "Failed to release resource ${BOSKOS_RESOURCE_NAME} of type ${RESOURCE_TYPE} used by ${USER}"
    fi

    echo "Successfully released resource ${BOSKOS_RESOURCE_NAME} of type ${RESOURCE_TYPE}, previously used by ${USER}"
}

checkout_account(){
    resource_type=$1
    set +o xtrace # Disable debug before checkout
    url="http://${BOSKOS_HOST}/acquire?type=${resource_type}&state=free&dest=busy&owner=${USER}"
    output=$(curl -X POST ${url})
    [ $? = 0 ] && status_code=200

    if [[ ${status_code} == 200 && ${output} =~ "failed" ]]; then
        error "Failed to acquire free resource of type ${RESOURCE_TYPE}"
    elif [[ ${status_code} == 200 ]]; then
        export BOSKOS_RESOURCE_NAME=$(echo ${output} | jq -r '.name')
        export BOSKOS_REGION=$(echo ${output} | jq -r '.userdata["region"]')
        export BOSKOS_ZONE=$(echo ${output} | jq -r '.userdata["zone"]')
        
        if [[ ${resource_type} == "powervs" ]]; then
            export BOSKOS_RESOURCE_ID=$(echo ${output} | jq -r '.userdata["service-instance-id"]')
        fi
        
        if [[ ${resource_type} == "vpc-service" ]]; then
            export BOSKOS_RESOURCE_GROUP=$(echo ${output} | jq -r '.userdata["resource-group-name"]')
            export BOSKOS_SUBNET_NAME=$(echo ${output} | jq -r '.userdata["subnet-name"]')
            export BOSKOS_SUBNET_ID=$(echo ${output} | jq -r '.userdata["subnet-id"]')
        fi
    else
        error "Failed to acquire free resource of type ${RESOURCE_TYPE} due to invalid response, status code : ${status_code}"
    fi
}

heartbeat_account(){
    count=0
    url="http://${BOSKOS_HOST}/update?name=${BOSKOS_RESOURCE_NAME}&state=busy&owner=${USER}"
    while [ ${count} -lt 300 ]
    do
        status_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST ${url})
        if [[ ${status_code} != 200 ]]; then
            error "Heart beat to resource '${BOSKOS_RESOURCE_NAME}' failed due to invalid response, status code: ${status_code}"
        fi
        count=$(( $count + 1 ))
        echo "Resource ${BOSKOS_RESOURCE_NAME} of type ${RESOURCE_TYPE} is currently being used by ${USER}"
        sleep 60
    done
}

cleanup() {
    HEART_BEAT_PID=${1:-}
    # stop the boskos heartbeat
    [[ -z ${HEART_BEAT_PID:-} ]] || kill -9 "${HEART_BEAT_PID}" || true
}

# If BOSKOS_HOST is not set, use direct VPC configuration for s390x
if [ -z "${BOSKOS_HOST:-}" ]; then
    echo "Boskos host is not set. Using direct VPC configuration for s390x."
    
    # Export required VPC configuration
    # Note: BOSKOS_RESOURCE_NAME will be set to CLUSTER_NAME by the job script
    export BOSKOS_REGION="${VPC_REGION:-eu-de}"
    export BOSKOS_ZONE="${VPC_ZONE:-eu-de-1}"
    export BOSKOS_RESOURCE_GROUP="${VPC_RESOURCE_GROUP:-rg-conformance-test}"
    export BOSKOS_SUBNET_NAME="${VPC_SUBNET_NAME:-k8s-s390x-test-subnet}"
    
    release_account() {
        echo "Skipping Boskos release (not using Boskos for s390x)"
    }
    
    # No heartbeat needed for s390x
    HEART_BEAT_PID=""
    
    echo "Using direct VPC configuration in ${BOSKOS_REGION}/${BOSKOS_ZONE}"
    return 0
fi

# Create a temporary file to store environment variables
account_env_var_file="$(mktemp)"

# Checkout account from Boskos and capture output
checkout_account "${RESOURCE_TYPE}" 1> "${account_env_var_file}"
checkout_account_status=$?

# If checkout is successful, source the environment variables
if [ "$checkout_account_status" -eq 0 ]; then
    source "${account_env_var_file}"
    echo "Successfully acquired free resource ${BOSKOS_RESOURCE_NAME} of type ${RESOURCE_TYPE} by user ${USER}"
else
    echo "Error getting account from Boskos" 1>&2
    rm -f "${account_env_var_file}"
    exit "$checkout_account_status"
fi

# Clean up the temporary file
rm -f "${account_env_var_file}"

# Start heartbeat process
heartbeat_account >> "$ARTIFACTS/boskos.log" 2>&1 &
HEART_BEAT_PID=$!
export HEART_BEAT_PID
