#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
INVENTORY_FILE="${INVENTORY_FILE:-${ROOT_DIR}/inventory.ini}"
TFVARS_FILE="${TFVARS_FILE:-${TF_DIR}/terraform.tfvars}"

# Exécution obligatoire via conteneurs
TERRAFORM_IMAGE="${TERRAFORM_IMAGE:-hashicorp/terraform:1.9.8}"
ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-cytopia/ansible:latest-tools}"

usage() {
  cat <<USAGE
Usage: $0 [all|terraform|ansible|validate]

Commands:
  validate   Vérifie les prérequis + politique identifiants BDD
  terraform  Exécute Terraform dans un conteneur Docker
  ansible    Exécute Ansible dans un conteneur Docker
  validate   Vérifie les prérequis et la politique des identifiants BDD
  terraform  Exécute terraform init/plan/apply
  ansible    Exécute les playbooks Ansible dans l'ordre
  all        validate + terraform + ansible (défaut, saute les étapes si binaire absent)
  all        validate + terraform + ansible (défaut)

Variables attendues (env):
  BW_DB_USER
  BW_DB_PASSWORD

Variables optionnelles:
  INVENTORY_FILE=/chemin/inventory.ini
  TFVARS_FILE=/chemin/terraform.tfvars
  TERRAFORM_IMAGE=hashicorp/terraform:1.9.8
  ANSIBLE_IMAGE=cytopia/ansible:latest-tools
Optionnel:
  INVENTORY_FILE=/chemin/inventory.ini
  TFVARS_FILE=/chemin/terraform.tfvars
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERREUR] Commande manquante: $1" >&2
    exit 1
  }
}

check_password_complexity() {
  local pwd="$1"

  if [[ ${#pwd} -lt 12 ]]; then
    echo "[ERREUR] Le mot de passe BDD doit faire au moins 12 caractères." >&2
    return 1
  fi

  [[ "$pwd" =~ [A-Z] ]] || { echo "[ERREUR] Mot de passe: au moins une majuscule requise." >&2; return 1; }
  [[ "$pwd" =~ [a-z] ]] || { echo "[ERREUR] Mot de passe: au moins une minuscule requise." >&2; return 1; }
  [[ "$pwd" =~ [0-9] ]] || { echo "[ERREUR] Mot de passe: au moins un chiffre requis." >&2; return 1; }
  [[ "$pwd" =~ [^a-zA-Z0-9] ]] || { echo "[ERREUR] Mot de passe: au moins un caractère spécial requis." >&2; return 1; }

  return 0
}

validate_db_credentials_policy() {
  : "${BW_DB_USER:?BW_DB_USER doit être défini}"
  : "${BW_DB_PASSWORD:?BW_DB_PASSWORD doit être défini}"

  local low_user low_pwd
  low_user="$(echo "$BW_DB_USER" | tr '[:upper:]' '[:lower:]')"
  low_pwd="$(echo "$BW_DB_PASSWORD" | tr '[:upper:]' '[:lower:]')"

  # Valeurs par défaut/interdites courantes
  local -a forbidden_users=("sa" "admin" "bitwarden" "vault")
  local -a forbidden_passwords=("password" "password123" "changeme" "admin" "bitwarden" "vault" "sa")

  for u in "${forbidden_users[@]}"; do
    if [[ "$low_user" == "$u" ]]; then
      echo "[ERREUR] BW_DB_USER utilise une valeur par défaut/interdite: ${BW_DB_USER}" >&2
      return 1
    fi
  done

  for p in "${forbidden_passwords[@]}"; do
    if [[ "$low_pwd" == "$p" ]]; then
      echo "[ERREUR] BW_DB_PASSWORD utilise une valeur par défaut/interdite." >&2
      return 1
    fi
  done

  check_password_complexity "$BW_DB_PASSWORD"

  echo "[OK] Politique identifiants BDD validée."
}

run_validate() {
  require_cmd bash
  require_cmd python3
  require_cmd docker
  validate_db_credentials_policy

  validate_db_credentials_policy

  if command -v terraform >/dev/null 2>&1; then
    terraform -chdir="$TF_DIR" fmt -check -recursive
  else
    echo "[WARN] terraform non installé: fmt ignoré."
  fi

  python3 - <<'PY'
import glob
import sys
try:
    import yaml
except Exception:
    print('[WARN] pyyaml absent: validation YAML ignorée')
    sys.exit(0)

for p in glob.glob('ansible/*.yml') + glob.glob('compose/*.yml'):
    with open(p, 'r', encoding='utf-8') as f:
        yaml.safe_load(f)
print('[OK] YAML valide (ansible + compose)')
PY

  if docker run --rm -v "${TF_DIR}:/workspace" -w /workspace "$TERRAFORM_IMAGE" fmt -check -recursive >/dev/null 2>&1; then
    echo "[OK] Terraform fmt valide via conteneur ${TERRAFORM_IMAGE}."
  else
    echo "[WARN] Terraform fmt non validé (image absente, réseau indisponible ou format à corriger)."
  fi
}

run_terraform() {

}

run_terraform() {
  require_cmd terraform
  [[ -f "$TFVARS_FILE" ]] || {
    echo "[ERREUR] terraform.tfvars introuvable: $TFVARS_FILE" >&2
    exit 1
  }

  echo "[INFO] Terraform via Docker image: ${TERRAFORM_IMAGE}"
  docker run --rm -it \
    -v "${TF_DIR}:/workspace" \
    -w /workspace \
    "$TERRAFORM_IMAGE" init

  docker run --rm -it \
    -v "${TF_DIR}:/workspace" \
    -w /workspace \
    "$TERRAFORM_IMAGE" plan -var-file="$(basename "$TFVARS_FILE")"

  docker run --rm -it \
    -v "${TF_DIR}:/workspace" \
    -w /workspace \
    "$TERRAFORM_IMAGE" apply -auto-approve -var-file="$(basename "$TFVARS_FILE")"
}

run_ansible() {
  terraform -chdir="$TF_DIR" init
  terraform -chdir="$TF_DIR" plan -var-file="$TFVARS_FILE"
  terraform -chdir="$TF_DIR" apply -auto-approve -var-file="$TFVARS_FILE"
}

run_ansible() {
  require_cmd ansible-playbook
  [[ -f "$INVENTORY_FILE" ]] || {
    echo "[ERREUR] Inventory Ansible introuvable: $INVENTORY_FILE" >&2
    exit 1
  }

  echo "[INFO] Ansible via Docker image: ${ANSIBLE_IMAGE}"

  docker run --rm -it \
    -v "${ROOT_DIR}:/workspace" \
    -w /workspace \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/setup_docker.yml"

  docker run --rm -it \
    -v "${ROOT_DIR}:/workspace" \
    -w /workspace \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/config_db_replication.yml"

  docker run --rm -it \
    -v "${ROOT_DIR}:/workspace" \
    -w /workspace \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/deploy_bitwarden.yml"

  docker run --rm -it \
    -v "${ROOT_DIR}:/workspace" \
    -w /workspace \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/configure_proxy.yml"
  ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/setup_docker.yml"
  ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/config_db_replication.yml"
  ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/deploy_bitwarden.yml"
  ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/configure_proxy.yml"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

main() {
  local command="${1:-all}"

  case "$command" in
    validate)
      run_validate
      ;;
    terraform)
      run_validate
      run_terraform
      ;;
    ansible)
      run_validate
      run_ansible
      ;;
    all)
      run_validate
      if has_cmd terraform; then
        run_terraform
      else
        echo "[WARN] terraform absent: étape terraform ignorée. Utilisez ./scripts/run_lab.sh terraform après installation."
      fi

      if has_cmd ansible-playbook; then
        run_ansible
      else
        echo "[WARN] ansible-playbook absent: étape ansible ignorée. Utilisez ./scripts/run_lab.sh ansible après installation."
      fi
      run_terraform
      run_ansible
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "[ERREUR] Commande inconnue: $command" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
