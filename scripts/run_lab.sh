#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
INVENTORY_FILE="${INVENTORY_FILE:-${ROOT_DIR}/inventory.ini}"
TFVARS_FILE="${TFVARS_FILE:-${TF_DIR}/terraform.tfvars}"

# Exécution via conteneurs
TERRAFORM_IMAGE="${TERRAFORM_IMAGE:-hashicorp/terraform:1.14.4}"
ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-cytopia/ansible:latest-tools}"
LIBVIRT_SOCK="${LIBVIRT_SOCK:-/var/run/libvirt/libvirt-sock}"

usage() {
  cat <<USAGE
Usage: $0 [all|terraform|ansible|validate]

Commands:
  validate   Vérifie les prérequis et la politique des identifiants BDD
  terraform  Exécute terraform init/plan/apply (dans Docker)
  ansible    Exécute les playbooks Ansible (dans Docker)
  all        validate + terraform + ansible (défaut, saute les étapes si prérequis/fichiers absents)
  terraform  Exécute terraform init/plan/apply
  ansible    Exécute les playbooks Ansible dans l'ordre
  all        validate + terraform + ansible (défaut, saute les étapes si prérequis/fichiers absents)
  all        validate + terraform + ansible (défaut)

Variables attendues (env):
  BW_DB_USER
  BW_DB_PASSWORD

Variables optionnelles:
  INVENTORY_FILE=/home/sisu/workspace/LA_CASERNE_WARDEN/La_CASERNE_WARDEN-main/inventory.ini
  TFVARS_FILE=/home/sisu/workspace/LA_CASERNE_WARDEN/La_CASERNE_WARDEN-main/terraform/terraform.tfvars
  TERRAFORM_IMAGE=hashicorp/terraform:1.14.4
  ANSIBLE_IMAGE=cytopia/ansible:latest-tools
  LIBVIRT_SOCK=/var/run/libvirt/libvirt-sock

Fichiers attendus:
  ${ROOT_DIR}/terraform/terraform.tfvars (ou TFVARS_FILE=/chemin/fichier)
  ${ROOT_DIR}/inventory.ini (ou INVENTORY_FILE=/chemin/fichier)
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERREUR] Commande manquante: $1" >&2
    exit 1
  }
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_libvirt_socket() {
  [[ -S "$LIBVIRT_SOCK" ]]
}

validate_inventory_groups() {
  local inventory_file="${1:-}"
  [[ -n "$inventory_file" ]] || {
    echo "[ERREUR] validate_inventory_groups: chemin inventory manquant." >&2
    exit 1
  }

  local inventory_dir inventory_base inventory_in_container
  inventory_dir="$(dirname "$inventory_file")"
  inventory_base="$(basename "$inventory_file")"
  inventory_in_container="/workspace/${inventory_base}"
  local inventory_in_container="$1"
  local inventory_dir="$2"

  local inventory_json
  if ! inventory_json="$({
    docker run --rm \
      -v "${inventory_dir}:/workspace:ro" \
      "$ANSIBLE_IMAGE" ansible-inventory -i "$inventory_in_container" --list
  })"; then
    echo "[ERREUR] Impossible de parser l'inventory via ansible-inventory dans le conteneur ${ANSIBLE_IMAGE}." >&2
    echo "         Vérifiez le format INI, les permissions du fichier et l'image Ansible." >&2
    exit 1
  fi

  python3 - <<'PY' <<<"$inventory_json"
import json
import sys

required_groups = ["bitwarden_nodes", "mssql_nodes", "mssql_primary", "reverse_proxy"]

try:
    data = json.load(sys.stdin)
except Exception as exc:
    print(f"[ERREUR] Sortie ansible-inventory invalide (JSON): {exc}", file=sys.stderr)
    sys.exit(1)

missing = []
for group in required_groups:
    hosts = data.get(group, {}).get("hosts", [])
    if not hosts:
        missing.append(group)

if missing:
    print(
        "[ERREUR] Inventory Ansible invalide pour ansible-playbook: groupes manquants ou vides "
  local inventory_path="$1"

  python3 - "$inventory_path" <<'PY'
import re
import sys
from pathlib import Path

required_groups = ["bitwarden_nodes", "mssql_nodes", "mssql_primary", "reverse_proxy"]
group_hosts = {g: 0 for g in required_groups}

inventory = Path(sys.argv[1])
if not inventory.exists():
    print(f"[ERREUR] Inventory Ansible introuvable: {inventory}", file=sys.stderr)
    sys.exit(1)

current_group = None
for raw_line in inventory.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue

    section = re.match(r"^\[(.+)\]$", line)
    if section:
        name = section.group(1)
        current_group = name if name in group_hosts else None
        continue

    if current_group:
        group_hosts[current_group] += 1

missing = [g for g, count in group_hosts.items() if count == 0]
if missing:
    print(
        "[ERREUR] Inventory Ansible invalide: groupes manquants ou vides "
        + ", ".join(missing)
        + ".",
        file=sys.stderr,
    )
    print(
        "         Copiez inventory.ini.example vers inventory.ini puis adaptez les IP/variables.",
        file=sys.stderr,
    )
    sys.exit(1)

print("[OK] Inventory Ansible valide (ansible-inventory).")
print("[OK] Inventory Ansible valide.")
PY
}

require_libvirt_socket() {
  has_libvirt_socket || {
    echo "[ERREUR] Socket libvirt introuvable: ${LIBVIRT_SOCK}." >&2
    echo "         Démarrez libvirtd/virtqemud ou définissez LIBVIRT_SOCK vers un socket valide." >&2
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

  local fmt_status=0
  docker run --rm -v "${TF_DIR}:/workspace" -w /workspace "$TERRAFORM_IMAGE" fmt -check -recursive >/dev/null 2>&1 || fmt_status=$?
  if [[ $fmt_status -eq 0 ]]; then
    echo "[OK] Terraform fmt valide via conteneur ${TERRAFORM_IMAGE}."
  fi
  if [[ $fmt_status -ne 0 ]]; then
    echo "[WARN] Terraform fmt non validé via conteneur (image absente, réseau indisponible, démon Docker indisponible ou format à corriger)."
  fi
}

run_terraform() {
  require_cmd docker
  require_libvirt_socket
  [[ -f "$TFVARS_FILE" ]] || {
    echo "[ERREUR] terraform.tfvars introuvable: $TFVARS_FILE" >&2
    exit 1
  }

  local libvirt_sock_dir
  libvirt_sock_dir="$(dirname "$LIBVIRT_SOCK")"

  echo "[INFO] Terraform via Docker image: ${TERRAFORM_IMAGE}"
  docker run --rm -it \
    -v "${TF_DIR}:/workspace" \
    -v "${libvirt_sock_dir}:${libvirt_sock_dir}" \
    -w /workspace \
    "$TERRAFORM_IMAGE" init

  docker run --rm -it \
    -v "${TF_DIR}:/workspace" \
    -v "${libvirt_sock_dir}:${libvirt_sock_dir}" \
    -w /workspace \
    "$TERRAFORM_IMAGE" plan -var-file="$(basename "$TFVARS_FILE")"

  docker run --rm -it \
    -v "${TF_DIR}:/workspace" \
    -v "${libvirt_sock_dir}:${libvirt_sock_dir}" \
    -w /workspace \
    "$TERRAFORM_IMAGE" apply -auto-approve -var-file="$(basename "$TFVARS_FILE")"
}

run_ansible() {
  require_cmd docker
  require_cmd python3
  [[ -f "$INVENTORY_FILE" ]] || {
    echo "[ERREUR] Inventory Ansible introuvable: $INVENTORY_FILE" >&2
    exit 1
  }

  validate_inventory_groups "$INVENTORY_FILE"

  local inventory_in_container inventory_dir inventory_base
  inventory_dir="$(dirname "$INVENTORY_FILE")"
  inventory_base="$(basename "$INVENTORY_FILE")"
  inventory_in_container="/workspace/${inventory_base}"

  validate_inventory_groups "$INVENTORY_FILE"
  validate_inventory_groups "$inventory_in_container" "$inventory_dir"

  echo "[INFO] Ansible via Docker image: ${ANSIBLE_IMAGE}"

  docker run --rm -it \
    -v "${inventory_dir}:/workspace:ro" \
    -v "${ANSIBLE_DIR}:/ansible:ro" \
    -w /ansible \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$inventory_in_container" /ansible/setup_docker.yml

  docker run --rm -it \
    -v "${inventory_dir}:/workspace:ro" \
    -v "${ANSIBLE_DIR}:/ansible:ro" \
    -w /ansible \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$inventory_in_container" /ansible/config_db_replication.yml

  docker run --rm -it \
    -v "${inventory_dir}:/workspace:ro" \
    -v "${ANSIBLE_DIR}:/ansible:ro" \
    -w /ansible \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$inventory_in_container" /ansible/deploy_bitwarden.yml

  docker run --rm -it \
    -v "${inventory_dir}:/workspace:ro" \
    -v "${ANSIBLE_DIR}:/ansible:ro" \
    -w /ansible \
    "$ANSIBLE_IMAGE" ansible-playbook -i "$inventory_in_container" /ansible/configure_proxy.yml
}

run_all() {
  run_validate

  if ! has_cmd docker; then
    echo "[WARN] docker absent: étape terraform ignorée. Utilisez ./scripts/run_lab.sh terraform après installation de Docker."
  elif [[ ! -f "$TFVARS_FILE" ]]; then
    echo "[WARN] terraform.tfvars introuvable: ${TFVARS_FILE}. Étape terraform ignorée (copiez terraform/terraform.tfvars.example vers terraform/terraform.tfvars, puis adaptez les valeurs)."
  elif ! has_libvirt_socket; then
    echo "[WARN] Socket libvirt introuvable (${LIBVIRT_SOCK}): étape terraform ignorée."
    echo "       Démarrez libvirtd/virtqemud ou définissez LIBVIRT_SOCK vers un socket valide."
  else
    run_terraform
  fi

  if ! has_cmd docker; then
    echo "[WARN] docker absent: étape ansible ignorée. Utilisez ./scripts/run_lab.sh ansible après installation de Docker."
  elif [[ ! -f "$INVENTORY_FILE" ]]; then
    echo "[WARN] inventory Ansible introuvable: ${INVENTORY_FILE}. Étape ansible ignorée (utilisez INVENTORY_FILE=/chemin/fichier ou créez le fichier)."
  else
    run_ansible
  fi
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
      run_all
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
