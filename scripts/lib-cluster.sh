#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Shared cluster-context resolution for the local demo scripts.
#
# The scripts never mutate the current kubectl context; they resolve a context
# name and pass it explicitly with --context / --kube-context.
# ---------------------------------------------------------------------------

kube_context_exists() {
  kubectl config get-contexts -o name 2>/dev/null | grep -qx "$1"
}

kube_context_reachable() {
  kubectl --context "$1" cluster-info >/dev/null 2>&1
}

# Print the first reachable local cluster context, preferring the providers
# that the challenge brief allows:
#   1. docker-desktop (kubeadm cluster shipped with Docker Desktop)
#   2. minikube
#   3. any existing kind-* cluster
# Returns 1 when no reachable context is found.
detect_local_context() {
  local candidate

  for candidate in docker-desktop minikube; do
    if kube_context_exists "$candidate" && kube_context_reachable "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    if kube_context_reachable "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(kubectl config get-contexts -o name 2>/dev/null | grep -E '^kind-' || true)

  return 1
}
