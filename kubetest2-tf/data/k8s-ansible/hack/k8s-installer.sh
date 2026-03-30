#!/bin/bash
#
# Hack script to install and set up Kubernetes cluster using ansible-playbook
# Validates the IPs, deploys k8s on nodes (Alpha/release) based on args.
# Deploys the cluster based on the playbook passed as argument (default: install-k8s.yml)

# Path to playbooks, extra-vars and host files.
project_dir=$(dirname $(pwd))
var_file=$project_dir/group_vars/all
hosts_file=$project_dir/examples/containerd-cluster/hosts.yml

# Regex for validating IPs.
binary_octet='([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))'

# Default values for variables used in script.
release="false"
alpha="false"
approve="n"
local_mode="false"

# help_function : Returns the usage guide for script.
help_function()
{
cat <<EOF

Usage: $0 -p <playbook> -c <IP> -w <IP>

   ./test.sh -w X.X.X.X -c X.X.X.X -p install-k8s-perf.yml -a -y
   ./test.sh -L -p install-k8s.yml -a -y

   -p: Playbook to use.
       Default - install-k8s.yml; use install-k8s-perf.yml to set up the perf-tests cluster.
   -c IP address(es) of the control-plane node(s).
   -w IP address(es) of the worker-node(s).
      Eg: X.X.X.X for a single node or "X.X.X.X Y.Y.Y.Y" for multinode in quotes.
   -L Local mode - Set up a single-node cluster on 127.0.0.1 (localhost).
   -r Use the latest stable-release for cluster deployment.
   -a Use the latest alpha-release for cluster deployment.
   -l Load-balancer endpoint to utilize in case of a HA setup.
   -y Proceed to run playbook to deploy k8s-cluster after generating fields.
EOF
exit 1
}

# check_reachability: Validates and pings the machine IPs.
check_reachability()
{
  ip_addresses=("$@")
  for ip_address in $ip_addresses; do
  if [[ "$ip_address" =~ ^($binary_octet\.){3}$binary_octet$ ]]; then
    ping -c1 $ip_address 1>/dev/null
    if [ $? -eq 0 ]; then
      echo "$ip_address is reachable"
      echo $ip_address >> $hosts_file
    else
      echo "$ip_address is not reachable"
      exit 1
    fi
  else
    echo "Invalid IP $ip_address"
    exit 1
  fi
  done < <(echo "$ip_address")
}

# write_to_extravars: Add changes to extra-vars-k8s.json for deploying k8s cluster
write_to_extravars()
{
  sed -i \
  -e "s/^directory: .*/directory: $directory/" \
  -e "s/build_version: .*/build_version: $version/" \
  -e "s/release_marker: .*/release_marker: $release_marker/" \
  -e "s/extra_cert: .*/extra_cert : $(cut -d ' ' -f 1 <<< $controllers)/" \
  $var_file
}

# Flush contents of hosts.yml file to hold control-plane and worker IPs
>$hosts_file

# Process arguments
while getopts "l:Lac:p:rw:y" opt; do
  case "$opt" in
    p)
      playbook="$OPTARG";;
    c)
      controllers=("$OPTARG")
      echo "[masters]" >> $hosts_file
      check_reachability "${controllers[@]}";;
    w)
      workers=("$OPTARG")
      echo "[workers]" >> $hosts_file
      check_reachability "${workers[@]}";;
    L)
      local_mode="true"
      echo "Local mode enabled - Setting up single-node cluster on 127.0.0.1"
      controllers="127.0.0.1"
      echo "[masters]" >> $hosts_file
      echo "127.0.0.1 ansible_connection=local" >> $hosts_file
      # Update extra_cert for localhost
      sed -i "s/extra_cert: .*/extra_cert: 127.0.0.1/" $var_file
      ;;
    l)
      count=$(echo "$controllers" | wc -w)
      if [ "$count" -lt 2 ]; then
        echo "The setup cannot proceed with a single master node that needs to be loadbalanced."
        exit 1
      else
        loadbalancer="$OPTARG"
        if  [ -z "$loadbalancer" ]; then
          echo "Error: loadbalancer is empty. Exiting."
          exit 1
        fi
        sed -i "s/^loadbalancer:.*/loadbalancer: ${loadbalancer}/" $var_file
      fi;;
    a)
      alpha="true"
      echo "Fetching latest k8s Alpha CI version."
      version=$(curl -Ls https://dl.k8s.io/ci/latest.txt)
      release_marker="ci\/latest"
      directory="ci"
      write_to_extravars
      echo "Alpha release version to be used for cluster deployment: $version";;
    r)
      release="true"
      echo "Fetching latest k8s stable release version."
      version=$(curl -Ls https://dl.k8s.io/release/stable.txt)
      release_marker="$version"
      directory="release"
      write_to_extravars
      echo "Stable release version to be used for cluster deployment: $version";;
    y)
      approve="y"
      echo "Approved to run playbooks after initialization";;
    *)
      # print the help message if unrecognized/no parameters are passed.
      help_function ;;
  esac
done

# Print help_function in case parameters are empty
if [ "$local_mode" == "false" ]; then
  if [ -z "$controllers" ]
  then
    echo "Control-plane node IP was not provided as input arguments."
    help_function
  fi
fi

if [ "$alpha" == "$release" ]; then
  echo "Either -a or -r needs to be used to deploy alpha or release version of k8s."; exit
fi

if [ -z "$playbook" ]; then
  echo "No playbook has been passed, defaulting to install-k8s.yml"
  playbook="install-k8s.yml"
else
    echo "Playbook \"$playbook\" to be used to set up cluster"
fi

echo "Ansible Playbook   : $playbook"
echo "Control Node IP    : $controllers"
if [ "$local_mode" == "false" ]; then
  echo "Worker Node IP(s)  : $workers"
fi

# A check to prevent execution of playbook unless approved through -y flag,
# To  modify the generated fields in extra-vars file and deploy through method 1 if needed
if [ "$approve" == "n" ]; then
    read -p "Approval flag was not set, proceed to run playbook? [y/n]: " approve  && [ $approve  == "y" ] || exit 1
fi

# install_ansible: Installs ansible if not present
install_ansible() {
    echo "Installing ansible..."

    local install_cmd=""
    if command -v apt-get >/dev/null 2>&1; then
        install_cmd="apt-get update && apt-get install -y"
    elif command -v yum >/dev/null 2>&1; then
        install_cmd="yum install -y"
    elif command -v dnf >/dev/null 2>&1; then
        install_cmd="dnf install -y"
    else
        echo "Error: No supported package manager found."
        exit 1
    fi

    # Check if python3 is installed, install if not
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Installing python3..."
        eval "$install_cmd python3 python3-pip"
    fi

    # Ensure pip is available
    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo "Installing pip..."
        eval "$install_cmd python3-pip" || {
            echo "Package manager failed. Attempting to install pip using get-pip.py..."
            curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
            python3 /tmp/get-pip.py --user
            rm -f /tmp/get-pip.py
        }
    fi

    # Install ansible using pip
    python3 -m pip install --user ansible

    # Add ~/.local/bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        echo "Added ~/.local/bin to PATH for this session."
    fi

    echo "Ansible installed successfully using pip."
    echo "Note: If ansible-playbook is not found, ensure ~/.local/bin is in your PATH."
}

# Check if ansible is installed, install if not present
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ansible-playbook not found. Installing ansible..."
    install_ansible
    ansible-galaxy collection install community.general
fi

# Define connection arguments based on mode
if [ "$local_mode" == "true" ]; then
    export ANSIBLE_CONNECTION=local
    export ANSIBLE_TRANSPORT=local
    export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

    connection_args="-e ansible_connection=local -e ssh_private_key=/dev/null -e ansible_ssh_private_key_file=/dev/null"
else
    export ANSIBLE_CONNECTION=ssh
    connection_args=""
fi

echo "Executing: ansible-playbook -i $hosts_file $project_dir/$playbook --extra-vars @$var_file"

# Run the playbook
ansible-playbook -i "$hosts_file" \
                 "$project_dir/$playbook" \
                 --extra-vars "@$var_file" \
                 $connection_args

