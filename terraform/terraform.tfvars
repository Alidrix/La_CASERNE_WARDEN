# Configuration complète d'exemple pour un lab local libvirt.
# Usage:
#   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
#   # puis adaptez au minimum: base_image_path et ssh_public_key

# --- Variables requises ---
# Chemin local vers l'image cloud Ubuntu/Debian utilisée par libvirt.
base_image_path = "/var/lib/libvirt/images/ubuntu-22.04-server-cloudimg-amd64.img"

# Clé publique SSH injectée dans les VMs cloud-init.
# Générer si besoin: ssh-keygen -t ed25519 -C "lab-bitwarden" -f ~/.ssh/id_ed25519
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwbw7flATYP9whquQzKA9oHA7OerC2fLtJiWMOyFdOh lab-bitwarden"

# --- Paramètres infra (surcharges explicites pour un lab local) ---
libvirt_uri   = "qemu:///system"
storage_pool  = "default"
network_name  = "bw-lab-net"
network_cidr  = "10.30.0.0/24"
gateway_ip    = "10.30.0.1"
dns_server_ip = "10.30.0.53"
domain_suffix = "lab.local"

primary_vm_name   = "bw-primary"
secondary_vm_name = "bw-secondary"
relay_vm_name     = "bw-relay"

load_balancer_ip = "10.30.0.10"
primary_ip       = "10.30.0.11"
secondary_ip     = "10.30.0.12"
relay_ip         = "10.30.0.13"

primary_fqdn          = "bw-primary.lab.local"
secondary_fqdn        = "bw-secondary.lab.local"
relay_fqdn            = "bw-relay.lab.local"
bitwarden_public_fqdn = "vault.lab.local"

vm_vcpu      = 4
vm_memory_mb = 8192
vm_disk_gb   = 80
admin_user   = "ops"
