output "masters" {
  value       = module.master.addresses[*][0].external_ip
  description = "k8s master node IP addresses"
}

output "workers" {
  value       = module.workers.addresses[*][0].external_ip
  description = "k8s worker node IP addresses"
}

output "masters_private" {
  value       = module.master.addresses[*][0].ip_address
  description = "k8s master nodes private IP addresses"
}

output "workers_private" {
  value       = module.workers.addresses[*][0].ip_address
  description = "k8s worker nodes private IP addresses"
}

output "network" {
  value       = ibm_pi_network.public_network
  description = "Network used for the deployment"
}

output "master_instance_list" {
  value       = module.master.instance_list
  description = "List of master instance IDs and names"
}

output "worker_instance_list" {
  value       = module.workers.instance_list
  description = "List of worker instance IDs and names"
}
