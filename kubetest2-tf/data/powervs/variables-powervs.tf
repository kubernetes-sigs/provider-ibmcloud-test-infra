variable "powervs_resource_group" {
  description = "IBM Cloud Resource Group"
}

variable "powervs_api_key" {
  description = "Denotes the IBM Cloud API key to use"
  sensitive   = true
}

variable "powervs_dns" {
  description = "IBM Cloud VPC Private DNS name"
}

variable "powervs_dns_zone" {
  description = "IBM Cloud VPC Private DNS Zone Name"
  default     = "k8s.test"
}

variable "powervs_image_name" {
  description = "PowerVS image name to be used for the deployment"
}

# By design, only the worker node's CPU/Memory can be sized through the flags passed as arguments.
variable "powervs_memory" {
  description = "Worker node's PowerVS memory in GB"
}

variable "powervs_processors" {
  description = "Worker node's PowerVS processor units"
}

# The control-plane node holds up well with 0.5C/8GB for most tests.
# The default can be overridden by exporting TF variables - export TF_VAR_controlplane_powervs_memory=X
variable "controlplane_powervs_memory" {
  description = "Control plane's PowerVS memory in GB"
  default     = "8"
}

# The default can be overridden by exporting TF variables - export TF_VAR_controlplane_powervs_processors=X
variable "controlplane_powervs_processors" {
  description = "Control plane's PowerVS processor units"
  default     = "0.5"
}

variable "powervs_network_name" {
  description = "PowerVS Network name to be used for the deployment"
}

variable "powervs_storage_tier" {
  description = "PowerVS backing storage tier for boot volumes"
  default     = "tier1"
}

variable "powervs_service_id" {
  description = "PowerVS service ID"
}

variable "powervs_ssh_key" {
  description = "PowerVS SSH Key ID"
}

variable "powervs_system_type" {
  description = "PowerVS Type of system on which the VM should be created. Options: e1050,e1080,e1180,e980,s1022,s1122,s922"
  default     = "s1022"
}

variable "powervs_region" {
  description = "PowerVS Region"
}

variable "powervs_zone" {
  description = "PowerVS Zone"
}

variable "apiserver_port" {
  description = "Kubernetes API Server Port"
}

