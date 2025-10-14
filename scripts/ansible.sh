#!/bin/bash

# [Dev] This function is for faster reset and re-execute the Ansible Playbook
run_ansible_playbook() {
  local playbook_file="$1"  # (e.g., "10-provision-cluster.yaml").
  local inventory_file="$2" # (e.g., "inventory-kubeadm-cluster.yaml").

  if [ -z "$playbook_file" ] || [ -z "$inventory_file" ]; then
    echo "FATAL: Playbook or inventory file not specified for run_ansible_playbook function." >&2
    return 1
  fi

  local private_key_path="${SSH_PRIVATE_KEY}"
  local relative_inventory_path="ansible/${inventory_file}"
  local relative_playbook_path="ansible/playbooks/${playbook_file}"

  if [ ! -f "${SCRIPT_DIR}/${relative_playbook_path}" ]; then
      echo "FATAL: Playbook not found at '${relative_playbook_path}'" >&2
      return 1
  fi
  if [ ! -f "${SCRIPT_DIR}/${relative_inventory_path}" ]; then
      echo "FATAL: Inventory not found at '${relative_inventory_path}'" >&2
      return 1
  fi

  echo ">>> STEP: Running Ansible Playbook [${playbook_file}] with inventory [${inventory_file}]"

  local cmd="ansible-playbook \
    -i ${relative_inventory_path} \
    --private-key ${private_key_path} \
    -vv \
    ${relative_playbook_path}"

  run_command "${cmd}" "${SCRIPT_DIR}"
  echo "#### Playbook execution finished."
}

# Function: Display a sub-menu to select and run a Layer 10 playbook.
selector_playbook() {
  local playbook_options=()

  # find all playbooks starting with "10-"
  for f in "${ANSIBLE_DIR}/playbooks/10-"*.yaml; do
    if [ -e "$f" ]; then
      playbook_options+=("$(basename "$f")")
    fi
  done
  playbook_options+=("Back to Main Menu")

  local PS3_SUB=">>> Select a Playbook to run: "
  echo
  select playbook in "${playbook_options[@]}"; do
    local inventory_file=""
    case $playbook in
      "10-provision-cluster.yaml")
        inventory_file="inventory-kubeadm-cluster.yaml"
        ;;
      "10-provision-harbor.yaml")
        inventory_file="inventory-harbor-cluster.yaml"
        ;;
      "10-provision-postgres.yaml")
        inventory_file="inventory-postgres-cluster.yaml"
        ;;
      "Back to Main Menu")
        echo "# Returning to main menu..."
        break
        ;;
      *)
        echo "Invalid option $REPLY"
        continue
        ;;
    esac

    if [ -n "$inventory_file" ]; then
        run_ansible_playbook "$playbook" "$inventory_file"
    fi
    break
  done
}
