variable "libvirt_uri" {
  description = "URI du démon libvirt local"
  type        = string
  default     = "qemu:///system"
}

variable "base_image_path" {
  description = "Chemin vers l'image cloud Ubuntu 22.04 ou Debian 12"
  type        = string
}

variable "storage_pool" {
  description = "Pool libvirt où stocker les volumes"
  type        = string
  default     = "default"
}

variable "network_name" {
  description = "Nom du réseau libvirt"
  type        = string
  default     = "bw-lab-net"
}

variable "network_cidr" {
  description = "CIDR du réseau de lab"
  type        = string
  default     = "10.30.0.0/24"
}

variable "gateway_ip" {
  description = "Gateway du réseau de lab"
  type        = string
  default     = "10.30.0.1"
}

variable "dns_server_ip" {
  description = "IP du DNS local du lab"
  type        = string
  default     = "10.30.0.53"
}

variable "domain_suffix" {
  description = "Suffixe DNS interne"
  type        = string
  default     = "lab.local"
}

variable "primary_vm_name" {
  type    = string
  default = "bw-primary"
}

variable "secondary_vm_name" {
  type    = string
  default = "bw-secondary"
}

variable "relay_vm_name" {
  type    = string
  default = "bw-relay"
}

variable "primary_ip" {
  type    = string
  default = "10.30.0.11"
}

variable "secondary_ip" {
  type    = string
  default = "10.30.0.12"
}

variable "relay_ip" {
  type    = string
  default = "10.30.0.13"
}

variable "load_balancer_ip" {
  type    = string
  default = "10.30.0.10"
}

variable "primary_fqdn" {
  type    = string
  default = "bw-primary.lab.local"
}

variable "secondary_fqdn" {
  type    = string
  default = "bw-secondary.lab.local"
}

variable "relay_fqdn" {
  type    = string
  default = "bw-relay.lab.local"
}

variable "bitwarden_public_fqdn" {
  type    = string
  default = "vault.lab.local"
}

variable "vm_vcpu" {
  description = "Nombre de vCPU par VM"
  type        = number
  default     = 4
}

variable "vm_memory_mb" {
  description = "RAM en MB par VM"
  type        = number
  default     = 8192
}

variable "vm_disk_gb" {
  description = "Disque système en GB"
  type        = number
  default     = 80
}

variable "ssh_public_key" {
  description = "Clé publique SSH injectée dans cloud-init"
  type        = string
}

variable "admin_user" {
  description = "Utilisateur d'administration"
  type        = string
  default     = "ops"
}
