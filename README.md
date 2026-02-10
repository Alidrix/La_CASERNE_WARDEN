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
  - `TERRAFORM_IMAGE=hashicorp/terraform:1.14.4 ANSIBLE_IMAGE=cytopia/ansible:latest-tools ./scripts/run_lab.sh all`
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
- Terraform: `hashicorp/terraform:1.14.4`
- Ansible: `cytopia/ansible:latest-tools`

Préparer les fichiers d'entrée avant `all`:
1. Copier le template Terraform puis adapter les valeurs requises:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```
2. Copier et adapter l'inventaire Ansible:
```bash
cp inventory.ini.example inventory.ini
```
(ou définir `INVENTORY_FILE=/chemin/inventory.ini`).
> Le script valide désormais l'inventaire avec `ansible-inventory` (dans le conteneur Ansible) avant les playbooks.
3. Lancer le flux complet:
```bash
./scripts/run_lab.sh all
```

> Le script exécute Terraform et Ansible dans des conteneurs Docker. Aucune installation locale de `terraform` ou `ansible-playbook` n'est nécessaire.

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
