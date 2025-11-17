#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra/terraform"

cd "$TF_DIR"

# Create logs dir if not exists
mkdir -p "${SCRIPT_DIR}/../logs"

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
LOG_FILE="${SCRIPT_DIR}/../logs/terraform_apply_${TIMESTAMP}.log"

echo "Logging to ${LOG_FILE}"

{
  echo "===== Terraform apply started at ${TIMESTAMP} ====="
  terraform init
  terraform plan
  terraform apply -auto-approve
  echo "===== Terraform apply finished at $(date +"%Y-%m-%d_%H-%M-%S") ====="
  echo
  echo "Terraform outputs:"
  terraform output
} 2>&1 | tee "${LOG_FILE}"
