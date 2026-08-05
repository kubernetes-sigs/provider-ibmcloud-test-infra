output "addresses" {
  value = ibm_pi_instance.pvminstance.*.pi_network
}

# Output: List of instances with ID and Name
output "instance_list" {
  value = [
    for vm in ibm_pi_instance.pvminstance :
    {
      id   = vm.instance_id
      name = vm.pi_instance_name
    }
  ]
  description = "List of PowerVS instance IDs and VM names"
}
