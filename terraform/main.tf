terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

locals {
  instances = {
    primary = {
      name = var.primary_vm_name
      ip   = var.primary_ip
    }
    secondary = {
      name = var.secondary_vm_name
      ip   = var.secondary_ip
    }
    relay = {
      name = var.relay_vm_name
      ip   = var.relay_ip
    }
  }

  # DNS de lab (overrides /etc/hosts ou import dans dnsmasq/BIND)
  dns_records = [
    "${var.primary_ip} ${var.primary_fqdn}",
    "${var.secondary_ip} ${var.secondary_fqdn}",
    "${var.relay_ip} ${var.relay_fqdn}",
    "${var.load_balancer_ip} ${var.bitwarden_public_fqdn}",
  ]
}
