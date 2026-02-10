# Bitwarden HA Lab (Terraform + Ansible + Docker Compose)

Ce dépôt fournit des artefacts d'infrastructure pour un **lab local** de Bitwarden self-hosted multi-instance (primaire / secondaire / relay), avec front reverse proxy et base MSSQL externe répliquée (template AlwaysOn).

## 1) Terraform code – main.tf, variables, outputs

Dossier: `terraform/`

- `main.tf`: providers, locals et records DNS générés.
- `network.tf`: réseau libvirt + cloud-init commun.
- `vm_bitwarden_primary.tf`, `vm_bitwarden_secondary.tf`, `vm_bitwarden_relay.tf`: 3 VMs Bitwarden.
- `dns.tf`: génération d'overrides DNS (`hosts` et `dnsmasq`).
- `variables.tf`: variables configurables.
- `outputs.tf`: sorties clés (IPs, URL).

## 2) Ansible playbooks – YAML

Dossier: `ansible/`

- `setup_docker.yml`: Docker Engine/Compose sur Ubuntu/Debian.
- `deploy_bitwarden.yml`: déploiement compose, healthcheck/restart timer.
- `configure_proxy.yml`: NGINX + TLS self-signed (ou LE à adapter).
- `config_db_replication.yml`: MSSQL containers + template AG AlwaysOn + backup.

## 3) Docker Compose files – YAML

Dossier: `compose/`

- `bitwarden-primary-docker-compose.yml`
- `bitwarden-secondary-docker-compose.yml`
- `bitwarden-relay-docker-compose.yml`

> Important: ces fichiers sont des templates de lab. Valider les tags/images Bitwarden et options avec l’installateur officiel avant production.

## 4) Instructions de déploiement

1. Préparer une image cloud Ubuntu 22.04 (ou Debian 12) et la variable `base_image_path`.
2. Créer un `terraform.tfvars` (clé SSH, CIDR, FQDN).
3. Provisionner les VMs:
   - `cd terraform`
   - `terraform init`
   - `terraform plan`
   - `terraform apply`
4. Définir un inventaire Ansible avec groupes:
   - `bitwarden_nodes` (3 nœuds)
   - `reverse_proxy` (LB frontal)
   - `mssql_nodes` + `mssql_primary`
5. Exécuter les playbooks:
   - `ansible-playbook -i inventory.ini ansible/setup_docker.yml`
   - `ansible-playbook -i inventory.ini ansible/config_db_replication.yml`
   - `ansible-playbook -i inventory.ini ansible/deploy_bitwarden.yml`
   - `ansible-playbook -i inventory.ini ansible/configure_proxy.yml`

## 5) Tests de failover à effectuer

- Stopper le service Bitwarden du primaire (`docker compose stop`) et vérifier l'accès via le FQDN public derrière NGINX LB.
- Simuler panne DB primaire MSSQL et vérifier bascule vers listener AG.
- Vérifier connexion client Bitwarden, lecture/écriture coffre et synchronisation après bascule.
- Vérifier restauration d'une sauvegarde SQL + `/bwdata` sur un nœud vierge.

## 6) Notes sur sécurité & montée en prod

- Remplacer certificats self-signed par ACME/PKI interne.
- Stocker secrets via Ansible Vault ou gestionnaire de secrets (pas en clair).
- Durcir OS (pare-feu, fail2ban, MAJ auto maîtrisées, auditd).
- Activer monitoring centralisé (ELK, Prometheus/Grafana) et alerting.
- Établir PRA/PCA: RPO/RTO, tests réguliers de backup/restore, procédures documentées.
- Revalider strictement avec la documentation Bitwarden officielle avant passage prod.
