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

### Lancement automatisé via script Bash

- Script principal: `scripts/run_lab.sh`
- Exemples:
  - `./scripts/run_lab.sh validate`
  - `./scripts/run_lab.sh all`
  - `TERRAFORM_IMAGE=hashicorp/terraform:1.9.8 ANSIBLE_IMAGE=cytopia/ansible:latest-tools ./scripts/run_lab.sh all`

Le script applique une politique obligatoire sur les identifiants BDD:
- interdiction des valeurs par défaut (ex: `sa`, `admin`, `password`, `changeme`),
- mot de passe **>= 12 caractères**,
- au moins 1 majuscule, 1 minuscule, 1 chiffre, 1 caractère spécial.

Variables à exporter avant exécution:
- `BW_DB_USER`
- `BW_DB_PASSWORD`

Exemple validé:
```bash
export BW_DB_USER="SDIS28"
export BW_DB_PASSWORD="fe2sBkCp+D1L*evX"
```

Prérequis outillage local:
- `docker` est obligatoire (Terraform et Ansible s'exécutent uniquement en conteneurs).
- pas besoin d'installer `terraform` ni `ansible-playbook` sur l'hôte.

Images Docker utilisées par défaut:
- Terraform: `hashicorp/terraform:1.9.8`
- Ansible: `cytopia/ansible:latest-tools`
Si Terraform n'est pas encore installé:
- lance d'abord `./scripts/run_lab.sh validate`
- ou `./scripts/run_lab.sh ansible` si l'inventaire est prêt
- la commande `./scripts/run_lab.sh all` saute maintenant automatiquement les étapes dont le binaire est absent.


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

> Note: Les commandes Terraform/Ansible du script sont exécutées dans Docker (images configurables via `TERRAFORM_IMAGE` et `ANSIBLE_IMAGE`).

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
