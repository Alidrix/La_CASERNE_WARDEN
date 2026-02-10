resource "libvirt_volume" "primary_disk" {
  name           = "${var.primary_vm_name}.qcow2"
  pool           = var.storage_pool
  source         = var.base_image_path
  size           = var.vm_disk_gb * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_domain" "primary" {
  name   = var.primary_vm_name
  memory = var.vm_memory_mb
  vcpu   = var.vm_vcpu

  cloudinit = libvirt_cloudinit_disk.common_init.id

  network_interface {
    network_id = libvirt_network.bw_lab.id
    addresses  = [var.primary_ip]
    hostname   = var.primary_vm_name
  }

  disk {
    volume_id = libvirt_volume.primary_disk.id
  }

  graphics {
    type        = "spice"
    listen_type = "none"
  }

  qemu_agent = true
}
