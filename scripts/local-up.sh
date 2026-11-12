#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Local demonstration environment (Part 3).
#
#   PostgreSQL (RDS stand-in) -> SonarQube
#
# Cluster selection (CLUSTER_PROVIDER):
#   auto            reuse a running docker-desktop / minikube / kind cluster,
#                   otherwise create a Kind cluster (default)
#   kind            create/use a Kind cluster
#   docker-desktop  use Docker Desktop's kubeadm cluster
#   existing        use KUBE_CONTEXT as-is
#
# Usage:
#   ./scripts/local-up.sh
#   CLUSTER_PROVIDER=docker-desktop ./scripts/local-up.sh
#   CLUSTER_PROVIDER=existing KUBE_CONTEXT=minikube ./scripts/local-up.sh
#   STORAGE_CLASS=hostpath ./scripts/local-up.sh
# ---------------------------------------------------------------------------
set -euo pipefail

CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-auto}"
CLUSTER_NAME="${CLUSTER_NAME:-sonarqube-local}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
NAMESPACE="${NAMESPACE:-sonarqube}"
SQ_RELEASE="${SQ_RELEASE:-sonarqube}"
# Helm fullname is <release>-<chart>, so the Service is not the release name.
SQ_SERVICE="${SQ_SERVICE:-${SQ_RELEASE}-sonarqube}"
CHART_VERSION="${CHART_VERSION:-2026.5.1004}"
HELM_TIMEOUT="${HELM_TIMEOUT:-20m}"
STARTUP_TIMEOUT_SECONDS="${STARTUP_TIMEOUT_SECONDS:-900}"
STORAGE_CLASS="${STORAGE_CLASS:-}"
SERVICE_TYPE="${SERVICE_TYPE:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-cluster.sh
source "$ROOT_DIR/scripts/lib-cluster.sh"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: $1 is required but not installed" >&2
    exit 1
  fi
}

require kubectl
require helm
require openssl

create_kind_cluster() {
  require kind
  echo "==> Creating Kind cluster '$CLUSTER_NAME'"
  kind create cluster --name "$CLUSTER_NAME"
  CONTEXT="kind-${CLUSTER_NAME}"
}

case "$CLUSTER_PROVIDER" in
  auto)
    if [[ -n "$KUBE_CONTEXT" ]]; then
      CONTEXT="$KUBE_CONTEXT"
      echo "==> Using KUBE_CONTEXT '$CONTEXT'"
    elif detected="$(detect_local_context)"; then
      CONTEXT="$detected"
      echo "==> Auto-detected a running cluster (context: $CONTEXT)"
    elif command -v kind >/dev/null 2>&1; then
      create_kind_cluster
    else
      echo "error: no reachable cluster found and kind is not installed." >&2
      echo "       Start Docker Desktop Kubernetes, minikube or a Kind cluster," >&2
      echo "       or set CLUSTER_PROVIDER=existing KUBE_CONTEXT=<context>." >&2
      exit 1
    fi
    ;;
  kind)
    create_kind_cluster
    ;;
  docker-desktop)
    # Docker Desktop ships a kubeadm-based cluster. It must already be enabled
    # in Docker Desktop settings; nothing is created here.
    CONTEXT="${KUBE_CONTEXT:-docker-desktop}"
    echo "==> Using the existing Docker Desktop cluster (context: $CONTEXT)"
    ;;
  existing)
    if [[ -z "$KUBE_CONTEXT" ]]; then
      echo "error: KUBE_CONTEXT is required when CLUSTER_PROVIDER=existing" >&2
      exit 1
    fi
    CONTEXT="$KUBE_CONTEXT"
    echo "==> Using existing cluster (context: $CONTEXT)"
    ;;
  *)
    echo "error: CLUSTER_PROVIDER must be one of: auto, kind, docker-desktop, existing" >&2
    exit 1
    ;;
esac

# Use --context everywhere instead of mutating the user's current context.
k() { kubectl --context "$CONTEXT" "$@"; }
h() { helm --kube-context "$CONTEXT" "$@"; }

if ! k cluster-info >/dev/null 2>&1; then
  echo "error: cannot reach cluster context '$CONTEXT'. Is it running?" >&2
  exit 1
fi

echo "==> Adding Helm repositories"
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube >/dev/null 2>&1 || true
# Only refresh the repo we use: `helm repo update` fails if any stale repo
# (for example an old bitnami entry) is unreachable.
helm repo update sonarqube >/dev/null

k get namespace "$NAMESPACE" >/dev/null 2>&1 || k create namespace "$NAMESPACE"

# Reuse the password from an existing Secret. PostgreSQL only applies
# POSTGRES_PASSWORD_FILE when it initializes the data directory, so rotating the
# Secret on every run would desynchronise it from the PVC and break SonarQube.
if [[ -n "${DB_PASSWORD:-}" ]]; then
  echo "==> Using DB_PASSWORD from the environment"
elif k -n "$NAMESPACE" get secret sonarqube-db >/dev/null 2>&1; then
  DB_PASSWORD="$(k -n "$NAMESPACE" get secret sonarqube-db -o jsonpath='{.data.password}' | base64 --decode)"
  echo "==> Reusing the existing database password from Secret sonarqube-db"
else
  DB_PASSWORD="$(openssl rand -hex 16)"
  echo "==> Generating a new database password"
fi
if [[ -z "$DB_PASSWORD" ]]; then
  echo "error: could not resolve a database password" >&2
  exit 1
fi

# Storage: rely on the cluster's default StorageClass unless the operator pins
# one (Kind: standard, Docker Desktop: hostpath, minikube: standard).
SQ_EXTRA_ARGS=()
if [[ -n "$STORAGE_CLASS" ]]; then
  SQ_EXTRA_ARGS+=(--set "persistence.storageClass=${STORAGE_CLASS}")
  echo "==> Using StorageClass '$STORAGE_CLASS'"
else
  echo "==> Using the cluster default StorageClass"
fi

if [[ -n "$SERVICE_TYPE" ]]; then
  SQ_EXTRA_ARGS+=(--set "service.type=${SERVICE_TYPE}")
  echo "==> Using Service type '$SERVICE_TYPE'"
else
  echo "==> Using Service type ClusterIP (port-forward)"
fi

# Migrate away from the earlier Bitnami-based local PostgreSQL. Helm OWNS the
# old Service/StatefulSet, and a kubectl apply can merge stale selector keys,
# leaving the Service with no endpoints.
echo "==> Cleaning up legacy local PostgreSQL (Bitnami) if present"
if helm --kube-context "$CONTEXT" status local-pg -n "$NAMESPACE" >/dev/null 2>&1; then
  helm --kube-context "$CONTEXT" uninstall local-pg -n "$NAMESPACE" --wait || true
fi

# The legacy StatefulSet uses a different name from ours, so removing it is
# always safe.
k -n "$NAMESPACE" delete statefulset local-pg-postgresql --ignore-not-found

# Recreate the Service only if it still carries Bitnami's selector/targetPort.
# Deleting our own Service on every run would briefly break SonarQube's DB
# connections.
if k -n "$NAMESPACE" get service local-pg-postgresql >/dev/null 2>&1; then
  pg_selector="$(k -n "$NAMESPACE" get service local-pg-postgresql -o jsonpath='{.spec.selector}' 2>/dev/null || true)"
  pg_target_port="$(k -n "$NAMESPACE" get service local-pg-postgresql -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || true)"
  if [[ "$pg_selector" == *"app.kubernetes.io/instance"* || "$pg_target_port" == "tcp-postgresql" ]]; then
    echo "    recreating the stale Bitnami Service local-pg-postgresql"
    k -n "$NAMESPACE" delete service local-pg-postgresql
  fi
fi

echo "==> Creating the sonarqube-db Secret (same keys as the AWS stack)"
k -n "$NAMESPACE" create secret generic sonarqube-db \
  --from-literal=host="local-pg-postgresql" \
  --from-literal=port="5432" \
  --from-literal=database="sonarqube" \
  --from-literal=username="sonar" \
  --from-literal=password="$DB_PASSWORD" \
  --from-literal=sslmode="disable" \
  --from-literal=jdbc-url="jdbc:postgresql://local-pg-postgresql:5432/sonarqube" \
  --dry-run=client -o yaml | k apply -f -

echo "==> Installing PostgreSQL (RDS stand-in, official postgres image)"
if [[ -n "$STORAGE_CLASS" ]]; then
  sed "s|# storageClassName: DEFAULT|storageClassName: ${STORAGE_CLASS}|" \
    "$ROOT_DIR/kubernetes/local/postgresql.yaml" | k apply -f -
else
  k apply -f "$ROOT_DIR/kubernetes/local/postgresql.yaml"
fi
k -n "$NAMESPACE" rollout status statefulset/local-pg --timeout=5m
k -n "$NAMESPACE" wait --for=condition=ready pod -l app.kubernetes.io/name=local-postgresql --timeout=180s
k -n "$NAMESPACE" exec local-pg-0 -- pg_isready -U sonar -d sonarqube

# Verify the same path SonarQube will use: DNS -> Service -> NetworkPolicy -> 5432.
echo "==> Verifying SonarQube -> PostgreSQL connectivity"
PG_CHECK_NAME="pg-connectivity-check-$(date +%s)"
if ! k -n "$NAMESPACE" run "$PG_CHECK_NAME" \
  --rm -i --restart=Never --quiet \
  --image=postgres:17.6-alpine3.22 \
  --labels=app=sonarqube \
  --pod-running-timeout=2m \
  --command -- pg_isready -h local-pg-postgresql -p 5432 -U sonar -d sonarqube; then
  echo "error: PostgreSQL is not reachable from a SonarQube-labelled pod." >&2
  echo
  echo "--- Postgres pod labels ---"
  k -n "$NAMESPACE" get pod local-pg-0 --show-labels || true
  echo
  echo "--- Service / endpoints ---"
  k -n "$NAMESPACE" get svc local-pg-postgresql -o wide || true
  k -n "$NAMESPACE" get endpoints local-pg-postgresql -o wide || true
  k -n "$NAMESPACE" get endpointslices -l kubernetes.io/service-name=local-pg-postgresql -o wide || true
  echo
  echo "--- NetworkPolicy ---"
  k -n "$NAMESPACE" describe networkpolicy local-pg-postgresql || true
  echo
  echo "--- PostgreSQL listeners ---"
  k -n "$NAMESPACE" exec local-pg-0 -- sh -c 'ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null || true' || true
  echo
  echo "Hint: if endpoints are empty, the Service selector and pod labels differ." >&2
  echo "      If listeners show only 127.0.0.1/unix, PostgreSQL is not listening on TCP." >&2
  exit 1
fi

echo "==> Installing SonarQube $CHART_VERSION (timeout: $HELM_TIMEOUT)"
if ! h upgrade --install "$SQ_RELEASE" sonarqube/sonarqube \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --values "$ROOT_DIR/helm/local/sonarqube-values.yaml" \
  "${SQ_EXTRA_ARGS[@]}" \
  --wait --timeout "$HELM_TIMEOUT"; then
  echo
  echo "ERROR: SonarQube did not become ready. Diagnostics:" >&2
  k -n "$NAMESPACE" get pods,pvc -o wide || true
  echo
  k -n "$NAMESPACE" get events --sort-by=.lastTimestamp | tail -30 || true
  echo
  SQ_POD="sonarqube-sonarqube-0"
  k -n "$NAMESPACE" describe pod "$SQ_POD" || k -n "$NAMESPACE" describe pod -l app=sonarqube || true
  echo
  echo "--- container logs (current and previous) ---"
  k -n "$NAMESPACE" logs "$SQ_POD" --all-containers --tail=160 || k -n "$NAMESPACE" logs -l app=sonarqube --all-containers --tail=160 || true
  k -n "$NAMESPACE" logs "$SQ_POD" --all-containers --previous --tail=160 2>/dev/null || true
  echo
  echo "Common causes:" >&2
  echo "  * Pending: storage class missing (set STORAGE_CLASS) or insufficient memory" >&2
  echo "  * Init:0/1: privileged initSysctl failed; raise vm.max_map_count in the VM" >&2
  echo "  * Running 0/1: database unreachable or Elasticsearch bootstrap rejected" >&2
  echo "  * ImagePullBackOff: registry access or a missing chart image tag" >&2
  exit 1
fi

# Helm's readiness probe accepts DB_MIGRATION_NEEDED / DB_MIGRATION_RUNNING,
# so a successful install does not mean the web UI is usable yet. First boot
# runs schema migrations and builds the Elasticsearch index.
SQ_POD="${SQ_RELEASE}-sonarqube-0"
echo
echo "==> Waiting for SonarQube to report UP (first boot migrates the database and builds the search index)"
deadline=$((SECONDS + STARTUP_TIMEOUT_SECONDS))
sq_status="unknown"
while (( SECONDS < deadline )); do
  sq_status="$(k -n "$NAMESPACE" exec "$SQ_POD" -- \
    curl -s --max-time 5 http://localhost:9000/api/system/status 2>/dev/null || true)"
  if grep -q '"status":"UP"' <<<"$sq_status"; then
    echo "==> SonarQube is UP"
    break
  fi
  echo "    status: ${sq_status:-unreachable} (${SECONDS}s elapsed, timeout ${STARTUP_TIMEOUT_SECONDS}s)"
  sleep 10
done

if ! grep -q '"status":"UP"' <<<"$sq_status"; then
  echo
  echo "WARNING: SonarQube has not reached UP after ${STARTUP_TIMEOUT_SECONDS}s." >&2
  echo "         status: ${sq_status:-unreachable}" >&2
  echo "         First boot on a slow Docker Desktop can take a while; extend with" >&2
  echo "         STARTUP_TIMEOUT_SECONDS=1800 ./scripts/local-up.sh" >&2
  echo
  k -n "$NAMESPACE" logs "$SQ_POD" --tail=80 || true
fi

echo
echo "==> Workloads"
k -n "$NAMESPACE" get pods,svc

cat <<EOF

SonarQube is ready on context: $CONTEXT

  URL:      http://localhost:9000
  Forward:  kubectl --context $CONTEXT -n $NAMESPACE port-forward svc/$SQ_SERVICE 9000:9000
  Admin:    admin / admin (SonarQube forces a password change on first login)

Day-2 demo:
  kubectl --context $CONTEXT apply -f $ROOT_DIR/kubernetes/sonarqube-db-fixer/job.yaml
  kubectl --context $CONTEXT -n $NAMESPACE logs -f job/sonarqube-db-fixer

Explore with k9s:
  k9s --context $CONTEXT -n $NAMESPACE
EOF

if [[ -n "$SERVICE_TYPE" ]]; then
  cat <<EOF

NodePort assigned:
  kubectl --context $CONTEXT -n $NAMESPACE get svc $SQ_RELEASE \
    -o jsonpath='{.spec.ports[0].nodePort}'
EOF
fi
