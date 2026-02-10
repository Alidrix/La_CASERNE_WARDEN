output "bitwarden_nodes" {
  description = "IPs des nœuds Bitwarden"
  value = {
    primary   = var.primary_ip
    secondary = var.secondary_ip
    relay     = var.relay_ip
  }
}

output "bitwarden_public_url" {
  description = "URL frontale de test"
  value       = "https://${var.bitwarden_public_fqdn}"
}

output "dns_hosts_file" {
  description = "Chemin du fichier hosts généré"
  value       = local_file.hosts_override.filename
}
