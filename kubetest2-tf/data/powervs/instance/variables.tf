
variable "ibmcloud_api_key" {
  description = "Denotes the IBM Cloud API key to use"
  sensitive   = true
}

variable "ibmcloud_region" {
  description = "Denotes which IBM Cloud region to connect to"
}

variable "ibmcloud_zone" {
  description = "Denotes which IBM Cloud zone to connect to - .i.e: eu-de-1 eu-de-2  us-south etc."
}

variable "vm_name" {
  description = "Name of the VM"
}

variable "powervs_service_instance_id" {
  description = "Power Virtual Server service instance ID"
}

variable "memory" {
  description = "Amount of memory (GB) to be allocated to the VM"
}

variable "processors" {
  description = "Number of virtual processors to allocate to the VM"
}

variable "proc_type" {
  description = "Processor type for the LPAR - shared/dedicated"
  default     = "shared"
}

variable "ssh_key_name" {
  description = "SSH key name in IBM Cloud to be used for SSH logins"
}

variable "shareable" {
  description = "Should the data volume be shared or not - true/false"
  default     = "false"
}

variable "network" {
  description = "Network that should be attached to the VM - Create this network before running terraform"
}

variable "system_type" {
  description = "PowerVS Type of system on which the VM should be created. Options: e1050,e1080,e1180,e980,s1022,s1122,s922"
}

variable "storage_tier" {
  description = "I/O operation per second (IOPS) based storage on requirement - tier0, tier1, tier3 or tier5k"
}

variable "image_name" {
  description = "Name of the image from which the VM should be deployed - IBM i image name"
}

variable "replication_policy" {
  description = "Replication policy of the VM"
  default     = "none"
}

variable "replication_scheme" {
  description = "Replication scheme for the VM"
  default     = "suffix"
}

variable "replicants" {
  description = "Number of VM instances to deploy"
  default     = "1"
}

variable "user_data" {
  description = "User data in base64 encoded format"
  default     = ""
}

variable "instance_count" {
  description = "Number of instances"
  default     = 1
}
