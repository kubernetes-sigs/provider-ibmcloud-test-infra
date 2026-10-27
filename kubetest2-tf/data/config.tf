variable "cluster_name" {
  description = "K8s cluster name"
}

variable "release_marker" {
  description = "Kubernetes release marker"
  default     = "ci/latest"
}

variable "build_version" {
  description = "Kubernetes Build Number"
}

variable "ssh_private_key" {
  description = "SSH Private Key file's complete path"
  default     = "~/.ssh/id_rsa"
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "File path to write the kubeconfig content for the deployed cluster"
}

variable "workers_count" {
  description = "Number of workers in the cluster"
  default = "1"
}

variable "bootstrap_token" {
  description = "Kubeadm bootstrap token used for installing and joining the cluster"
  sensitive   = true
}
