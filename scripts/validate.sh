#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Full local validation pipeline (no AWS credentials required).
#
#   terraform fmt -check
#   terraform init -backend=false && terraform validate
#   checkov static analysis
#   terraform test (native HCL tests with mocked providers)
#
# Usage: ./scripts/validate.sh
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODULES=(
  core-infra/s3-remote-backend
  core-infra/core-vpc
  core-infra/core-secretsmanager
  core-infra/core-rds
  core-infra/core-eks
  core-infra/core-external-secrets
  core-infra/core-sonarqube
)

echo "==> terraform fmt -check"
terraform fmt -check -recursive core-infra

for module in "${MODULES[@]}"; do
  echo
  echo "==> $module"
  terraform -chdir="$module" init -backend=false -input=false -no-color >/dev/null
  terraform -chdir="$module" validate -no-color
  terraform -chdir="$module" test -test-directory=testing -no-color
done

echo
echo "==> secret hygiene"
./scripts/check-secret-hygiene.sh

echo
echo "==> checkov"
checkov -d . --framework terraform --compact --quiet

echo
echo "All local checks passed."
echo "For the plan/destroy gate run: ./scripts/plan-guard.sh"
