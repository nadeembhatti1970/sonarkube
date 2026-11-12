#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Tear down the local demonstration environment.
#
#   ./scripts/local-down.sh                                  # auto-detect cluster
#   DELETE_CLUSTER=1 ./scripts/local-down.sh                 # Kind: delete cluster
#   CLUSTER_PROVIDER=docker-desktop ./scripts/local-down.sh  # Docker Desktop
#
# Docker Desktop's cluster is never deleted by this script; disable it in the
# Docker Desktop UI if you want to reclaim the resources.
# ---------------------------------------------------------------------------
set -euo pipefail

CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-auto}"
CLUSTER_NAME="${CLUSTER_NAME:-sonarqube-local}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
NAMESPACE="${NAMESPACE:-sonarqube}"
SQ_RELEASE="${SQ_RELEASE:-sonarqube}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-cluster.sh
source "$ROOT_DIR/scripts/lib-cluster.sh"

case "$CLUSTER_PROVIDER" in
  auto)
    if detected="$(detect_local_context)"; then
      CONTEXT="$detected"
      echo "==> Auto-detected a running cluster (context: $CONTEXT)"
    else
      echo "error: no reachable cluster found." >&2
      echo "       Set CLUSTER_PROVIDER/ KUBE_CONTEXT explicitly." >&2
      exit 1
    fi
    ;;
  kind)
    CONTEXT="kind-${CLUSTER_NAME}"
    ;;
  docker-desktop)
    CONTEXT="${KUBE_CONTEXT:-docker-desktop}"
    ;;
  existing)
    CONTEXT="${KUBE_CONTEXT:?KUBE_CONTEXT is required when CLUSTER_PROVIDER=existing}"
    ;;
  *)
    echo "error: CLUSTER_PROVIDER must be one of: auto, kind, docker-desktop, existing" >&2
    exit 1
    ;;
esac

echo "==> Removing SonarQube release and local PostgreSQL (context: $CONTEXT)"
helm --kube-context "$CONTEXT" uninstall "$SQ_RELEASE" --namespace "$NAMESPACE" --ignore-not-found || true
# Legacy Bitnami release from the earlier local setup, if it still exists.
helm --kube-context "$CONTEXT" uninstall local-pg --namespace "$NAMESPACE" --ignore-not-found || true
kubectl --context "$CONTEXT" -n "$NAMESPACE" delete -f "$ROOT_DIR/kubernetes/local/postgresql.yaml" --ignore-not-found || true
kubectl --context "$CONTEXT" -n "$NAMESPACE" delete pvc data-local-pg-0 --ignore-not-found || true
kubectl --context "$CONTEXT" -n "$NAMESPACE" delete secret sonarqube-db --ignore-not-found || true

echo "==> Removing the fixer Job"
kubectl --context "$CONTEXT" -n "$NAMESPACE" delete job sonarqube-db-fixer --ignore-not-found || true

if [[ "$CLUSTER_PROVIDER" == "kind" && "${DELETE_CLUSTER:-0}" == "1" ]]; then
  echo "==> Deleting Kind cluster $CLUSTER_NAME"
  kind delete cluster --name "$CLUSTER_NAME"
elif [[ "$CLUSTER_NAME" == "sonarqube-local" && "$CLUSTER_PROVIDER" == "auto" && "${DELETE_CLUSTER:-0}" == "1" ]]; then
  echo "==> DELETE_CLUSTER was set but the cluster was auto-detected; it is left untouched."
else
  echo "==> Keeping the cluster (managed outside this script)"
fi
