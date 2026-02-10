# Fichier hosts généré pour tests DNS locaux (importable dans dnsmasq/BIND).
resource "local_file" "hosts_override" {
  filename = "${path.module}/generated/hosts.bitwarden.lab"
  content  = join("\n", local.dns_records)
}

# Exemple de config dnsmasq générée pour pointer le FQDN public vers le load balancer.
resource "local_file" "dnsmasq_override" {
  filename = "${path.module}/generated/10-bitwarden.conf"
  content  = <<-EOT
    address=/${var.bitwarden_public_fqdn}/${var.load_balancer_ip}
    address=/${var.primary_fqdn}/${var.primary_ip}
    address=/${var.secondary_fqdn}/${var.secondary_ip}
    address=/${var.relay_fqdn}/${var.relay_ip}
  EOT
}
