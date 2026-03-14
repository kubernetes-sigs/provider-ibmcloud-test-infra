data "ibm_resource_group" "default_group" {
  name = var.vpc_resource_group
}

data "ibm_is_image" "node_image" {
  name = var.node_image
}

data "ibm_is_ssh_key" "ssh_key" {
  name = var.vpc_ssh_key
}

module "vpc" {
  source         = "./vpc-instance"
  vpc_name       = var.vpc_name
  cluster_name   = var.cluster_name
  zone           = var.vpc_zone
  resource_group = data.ibm_resource_group.default_group.id
}

locals {
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.subnet_id
  security_group_id = module.vpc.security_group_id
}

resource "ibm_is_instance_template" "node_template" {
  name           = "${var.cluster_name}-node-template"
  image          = data.ibm_is_image.node_image.id
  profile        = var.node_profile
  vpc            = local.vpc_id
  zone           = var.vpc_zone
  resource_group = data.ibm_resource_group.default_group.id
  keys           = [data.ibm_is_ssh_key.ssh_key.id]

  primary_network_interface {
    subnet          = local.subnet_id
    security_groups = [local.security_group_id]
  }

  user_data = <<-EOT
#!/bin/bash
# Create k8s-admin user for Kubernetes cluster management
useradd -m -s /bin/bash k8s-admin
# Add to sudo group (Ubuntu/Debian) or wheel group (RHEL/CentOS)
usermod -aG sudo k8s-admin 2>/dev/null || usermod -aG wheel k8s-admin
# Allow passwordless sudo
echo "k8s-admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/k8s-admin
chmod 0440 /etc/sudoers.d/k8s-admin
# Setup SSH directory and copy authorized keys from root
mkdir -p /home/k8s-admin/.ssh
cp /root/.ssh/authorized_keys /home/k8s-admin/.ssh/authorized_keys
chown -R k8s-admin:k8s-admin /home/k8s-admin/.ssh
chmod 700 /home/k8s-admin/.ssh
chmod 600 /home/k8s-admin/.ssh/authorized_keys
EOT
}

module "master" {
  source                    = "./node"
  node_name                 = "${var.cluster_name}-master"
  node_instance_template_id = ibm_is_instance_template.node_template.id
  resource_group            = data.ibm_resource_group.default_group.id
  subnet_id                 = local.subnet_id
  security_group_id         = local.security_group_id
}

module "workers" {
  source                    = "./node"
  count                     = var.workers_count
  node_name                 = "${var.cluster_name}-worker-${count.index}"
  node_instance_template_id = ibm_is_instance_template.node_template.id
  resource_group            = data.ibm_resource_group.default_group.id
  subnet_id                 = local.subnet_id
  security_group_id         = local.security_group_id
}

resource "null_resource" "wait-for-master-completes" {
  connection {
    type        = "ssh"
    user        = "k8s-admin"
    host        = module.master.public_ip
    private_key = file(var.ssh_private_key)
    timeout     = "20m"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status -w"
    ]
  }
}

resource "null_resource" "wait-for-workers-completes" {
  count = var.workers_count
  connection {
    type        = "ssh"
    user        = "k8s-admin"
    host        = module.workers[count.index].public_ip
    private_key = file(var.ssh_private_key)
    timeout     = "15m"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status -w"
    ]
  }
}
