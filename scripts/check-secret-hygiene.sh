#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Secret hygiene gate: fails if any Terraform configuration reintroduces a path
# that would persist secret material in state or plan files.
#
# Enforced rules:
#   * no non-ephemeral random_password resources
#   * no non-ephemeral aws_secretsmanager_secret_version data sources
#   * no `secret_string =` (must be `secret_string_wo` + version)
#   * no plain `password =` attribute (must be `password_wo` + version, or a
#     value sourced from an ephemeral resource)
#   * no `data =` map on kubernetes_secret_v1 (must be `data_wo` + revision)
#   * every write-only attribute has its version/revision counter
#   * no state files are tracked by git
#
# Usage: ./scripts/check-secret-hygiene.sh
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

pass() {
  echo "ok:   $1"
}

scan_absent() {
  local description="$1"
  local pattern="$2"
  local hits
  hits="$(grep -RInE "$pattern" --include='*.tf' --include='*.tftest.hcl' core-infra || true)"
  if [[ -n "$hits" ]]; then
    echo "$hits"
    fail "$description"
  else
    pass "$description"
  fi
}

echo "==> Secret hygiene"

scan_absent "no non-ephemeral random_password resources" '^[[:space:]]*resource[[:space:]]+"random_password"'
scan_absent "no non-ephemeral aws_secretsmanager_secret_version data sources" '^[[:space:]]*data[[:space:]]+"aws_secretsmanager_secret_version"'
scan_absent "no secret_string argument (use secret_string_wo)" '^[[:space:]]*secret_string[[:space:]]*='
scan_absent "no data map on kubernetes_secret_v1 (use data_wo)" '^[[:space:]]*data[[:space:]]*=[[:space:]]*\{'

plain_password_hits="$(grep -RInE '^[[:space:]]+password[[:space:]]*=' --include='*.tf' core-infra | grep -v 'ephemeral\.' || true)"
if [[ -n "$plain_password_hits" ]]; then
  echo "$plain_password_hits"
  fail "password attributes must use password_wo or an ephemeral value"
else
  pass "no plain password attributes are persisted"
fi

# Every write-only secret attribute must carry its version/revision counter.
# Count only assignments, ignoring comments.
count_assignment() {
  local attr="$1"
  { grep -RInE "^[[:space:]]*${attr}[[:space:]]*=" --include='*.tf' core-infra || true; } | wc -l | tr -d ' '
}

check_pair() {
  local write_only="$1"
  local counter="$2"
  local wc_count cc_count
  wc_count="$(count_assignment "$write_only")"
  cc_count="$(count_assignment "$counter")"
  if [[ "$wc_count" -eq "$cc_count" ]]; then
    pass "every $write_only has a $counter ($wc_count)"
  else
    fail "$write_only ($wc_count) and $counter ($cc_count) assignment counts differ"
  fi
}

check_pair "secret_string_wo" "secret_string_wo_version"
check_pair "password_wo" "password_wo_version"
check_pair "data_wo" "data_wo_revision"

tracked_state="$(git ls-files '*.tfstate' '*.tfstate.*' 2>/dev/null || true)"
if [[ -n "$tracked_state" ]]; then
  echo "$tracked_state"
  fail "no Terraform state files may be tracked by git"
else
  pass "no Terraform state files are tracked by git"
fi

echo
if [[ "$failures" -gt 0 ]]; then
  echo "Secret hygiene check failed with $failures violation(s)." >&2
  exit 1
fi

echo "Secret hygiene check passed: no secret material is persisted by Terraform."
