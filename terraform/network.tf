resource "libvirt_network" "bw_lab" {
  name      = var.network_name
  mode      = "nat"
  domain    = var.domain_suffix
  addresses = [var.network_cidr]

  dns {
    enabled    = true
    local_only = false
  }

  dhcp {
    enabled = false
  }
}

resource "libvirt_cloudinit_disk" "common_init" {
  name      = "bw-common-init.iso"
  pool      = var.storage_pool
  user_data = <<-EOT
    #cloud-config
    users:
      - name: ${var.admin_user}
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: [sudo, docker]
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.ssh_public_key}

    package_update: true
    packages:
      - qemu-guest-agent
      - curl
      - ca-certificates
      - gnupg
      - lsb-release
      - python3
      - python3-pip

    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
  EOT
}
