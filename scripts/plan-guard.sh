#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Plan export + destroy gate.
#
# For every root module this script:
#   1. initialises the S3 backend from dev.tfbackend
#   2. creates a plan with dev.tfvars
#   3. exports the plan as JSON
#   4. runs checkov's terraform_plan framework on it
#   5. fails if the plan deletes (or replaces) anything that is not explicitly
#      allowlisted in <module>/testing/.checkov-allowlist.json
#
# Requires AWS credentials with read access to the state bucket and the
# permissions needed to refresh the resources being planned.
#
# Usage:
#   ./scripts/plan-guard.sh                 # all modules
#   ./scripts/plan-guard.sh core-rds        # one module
#   ./scripts/plan-guard.sh --self-test     # verify the destroy guard offline
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${1:-}" == "--self-test" ]]; then
  python3 scripts/scan_plan.py --self-test
  exit 0
fi

ALL_MODULES=(
  core-infra/core-vpc
  core-infra/core-secretsmanager
  core-infra/core-rds
  core-infra/core-eks
  core-infra/core-external-secrets
  core-infra/core-sonarqube
)

if [[ $# -gt 0 ]]; then
  MODULES=("$@")
else
  MODULES=("${ALL_MODULES[@]}")
fi

PLAN_DIR="${PLAN_DIR:-${TMPDIR:-/tmp}/sonarkube-plan-guard}"
mkdir -p "$PLAN_DIR"

for module in "${MODULES[@]}"; do
  name="$(basename "$module")"
  plan_file="$PLAN_DIR/$name.tfplan"
  json_file="$PLAN_DIR/$name.json"
  allowlist="$module/testing/.checkov-allowlist.json"

  echo
  echo "==> $module"

  if [[ -f "$module/dev.tfbackend" ]]; then
    terraform -chdir="$module" init -input=false -no-color \
      -backend-config=dev.tfbackend >/dev/null
  else
    terraform -chdir="$module" init -input=false -no-color >/dev/null
  fi

  terraform -chdir="$module" plan -input=false -no-color \
    -var-file=dev.tfvars -out="$plan_file"

  terraform -chdir="$module" show -json "$plan_file" >"$json_file"

  echo "--> checkov terraform_plan"
  checkov -f "$json_file" --framework terraform_plan --compact --quiet

  echo "--> destroy guard"
  python3 scripts/scan_plan.py --plan "$json_file" --allowlist "$allowlist"
done

echo
echo "Plan guard passed for: ${MODULES[*]}"
