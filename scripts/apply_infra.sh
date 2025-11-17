#!/usr/bin/env bash
set -euo pipefail

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
TF_DIR="${REPO_ROOT}/infra/terraform"

mkdir -p "${REPO_ROOT}/logs"

# Timestamps & log paths
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
SESSION_ID="terraform_apply_${TIMESTAMP}"
RAW_LOG="${REPO_ROOT}/logs/${SESSION_ID}.log"
EVENT_LOG="${REPO_ROOT}/logs/agent_events.jsonl"
STATE_JSON="${REPO_ROOT}/logs/terraform_state_${TIMESTAMP}.json"

echo "Logging raw terraform output to ${RAW_LOG}"

# Helper to write one JSONL event per step (LLM-friendly)
log_event() {
  local step="$1"
  local cmd="$2"
  local exit_code="$3"
  local stdout_file="$4"
  local stderr_file="$5"

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Git info (best effort)
  local git_branch git_head git_status
  git_branch="$(cd "${REPO_ROOT}" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  git_head="$(cd "${REPO_ROOT}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  git_status="$(cd "${REPO_ROOT}" && git status --short 2>/dev/null || echo "")"

  # Tail stdout/stderr (last 40 lines)
  local stdout_tail stderr_tail
  stdout_tail="$(tail -n 40 "${stdout_file}" 2>/dev/null || true)"
  stderr_tail="$(tail -n 40 "${stderr_file}" 2>/dev/null || true)"

  local status="ok"
  if [ "${exit_code}" -ne 0 ]; then
    status="error"
  fi

  # Append JSON line (simple escaping)
  cat >> "${EVENT_LOG}" <<EOF
{"timestamp":"${ts}","session_id":"${SESSION_ID}","task":"infra/terraform/apply","step":"${step}","cmd":"${cmd}","cwd":"${TF_DIR}","exit_code":${exit_code},"status":"${status}","stdout_tail":"$(printf '%s' "${stdout_tail}" | tr '\n' ' ' | sed 's/"/'\''/g')","stderr_tail":"$(printf '%s' "${stderr_tail}" | tr '\n' ' ' | sed 's/"/'\''/g')","git":{"branch":"${git_branch}","head":"${git_head}","status_short":"$(printf '%s' "${git_status}" | tr '\n' ' ' | sed 's/"/'\''/g')"}}
EOF
}

cd "${TF_DIR}"

{
  echo "===== Terraform apply started at ${TIMESTAMP} ====="

  # terraform init
  INIT_OUT="$(mktemp)"
  INIT_ERR="$(mktemp)"
  set +e
  terraform init >"${INIT_OUT}" 2>"${INIT_ERR}"
  INIT_CODE=$?
  set -e
  cat "${INIT_OUT}"
  cat "${INIT_ERR}" >&2
  log_event "terraform_init" "terraform init" "${INIT_CODE}" "${INIT_OUT}" "${INIT_ERR}"
  rm -f "${INIT_OUT}" "${INIT_ERR}"
  if [ "${INIT_CODE}" -ne 0 ]; then
    echo "terraform init failed with code ${INIT_CODE}"
    exit "${INIT_CODE}"
  fi

  # terraform plan
  PLAN_OUT="$(mktemp)"
  PLAN_ERR="$(mktemp)"
  set +e
  terraform plan >"${PLAN_OUT}" 2>"${PLAN_ERR}"
  PLAN_CODE=$?
  set -e
  cat "${PLAN_OUT}"
  cat "${PLAN_ERR}" >&2
  log_event "terraform_plan" "terraform plan" "${PLAN_CODE}" "${PLAN_OUT}" "${PLAN_ERR}"
  rm -f "${PLAN_OUT}" "${PLAN_ERR}"
  if [ "${PLAN_CODE}" -ne 0 ]; then
    echo "terraform plan failed with code ${PLAN_CODE}"
    exit "${PLAN_CODE}"
  fi

  # terraform apply
  APPLY_OUT="$(mktemp)"
  APPLY_ERR="$(mktemp)"
  set +e
  terraform apply -auto-approve >"${APPLY_OUT}" 2>"${APPLY_ERR}"
  APPLY_CODE=$?
  set -e
  cat "${APPLY_OUT}"
  cat "${APPLY_ERR}" >&2
  log_event "terraform_apply" "terraform apply -auto-approve" "${APPLY_CODE}" "${APPLY_OUT}" "${APPLY_ERR}"
  rm -f "${APPLY_OUT}" "${APPLY_ERR}"
  if [ "${APPLY_CODE}" -ne 0 ]; then
    echo "terraform apply failed with code ${APPLY_CODE}"
    exit "${APPLY_CODE}"
  fi

  echo "===== Terraform apply finished at $(date +"%Y-%m-%d_%H-%M-%S") ====="
  echo
  echo "Terraform outputs:"
  terraform output

  # Snapshot the full Terraform state as JSON for future LLM agents
  echo
  echo "Writing Terraform state snapshot to ${STATE_JSON}"
  terraform show -json > "${STATE_JSON}"

} 2>&1 | tee "${RAW_LOG}"
