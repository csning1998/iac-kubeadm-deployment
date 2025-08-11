/*
Generate a `~/.ssh/config` file in the user's home directory with/with an alias and a specified public key
such that it allows for passwordless SSH using the alias (e.g., ssh vm200).
*/
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/templates/ssh_config.tftpl", {
    nodes = local.all_nodes,
    ssh_user = var.vm_username,
    ssh_key_path = "~/.ssh/id_ed25519_k8s-cluster"
  })
  filename = pathexpand("~/.ssh/config")
  file_permission = "0600"

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.ssh
      if [ ! -f ~/.ssh/id_ed25519_k8s-cluster ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k8s-cluster -N "" -C "k8s-cluster-key"
      fi
    EOT
  }
}

/*
NOTE: Using `local-exec` to start VMs as a workaround due to the lack of a stable
VMware Workstation provider. This is a known technical debt.
*/
resource "null_resource" "start_all_vms" {
  depends_on = [null_resource.configure_nodes, local_file.ssh_config]

  provisioner "local-exec" {
    command = <<EOT
      echo ">>> STEP: Starting all VMs after configuration..."
      ${join("\n", [for node in local.all_nodes : "vmrun -T ws start ${node.path} || echo 'Warning: Failed to start ${node.key}'"])}
      sleep 30
      echo "All VMs started."
    EOT
  }
}