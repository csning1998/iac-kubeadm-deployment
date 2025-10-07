terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

/*
* Generate the Ansible inventory file from template
*/
resource "local_file" "inventory" {
  content = templatefile("${path.root}/../../templates/inventory-registry.yaml.tftpl", {
    registry_nodes   = [for node in var.inventory.nodes : node if startswith(node.key, "registry-server")],
    ansible_ssh_user = var.vm_credentials.username,
  })
  filename        = "${var.ansible_config.root_path}/inventory-registry.yaml"
  file_permission = "0644"
}

resource "null_resource" "provision_cluster" {

  depends_on = [local_file.inventory]

  provisioner "local-exec" {

    working_dir = abspath("${path.root}/../../../")

    /*
     * To avoid "(output suppressed due to sensitive value in config)" shown in terminal
     * Use `nonsensitive()` function to decrypt the playbook log.
     * `rm-rf` is to ensure the destination directory for fetched files exists and is clean
    */
    command = <<-EOT
      set -e
      ansible-playbook \
        -i ${var.ansible_config.root_path}/inventory-registry.yaml \
        --private-key ${nonsensitive(var.vm_credentials.ssh_private_key_path)} \
        --extra-vars "ansible_ssh_user=${nonsensitive(var.vm_credentials.username)}" \
        -v \
        ${var.ansible_config.root_path}/playbooks/30-provision-registry.yaml
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}
