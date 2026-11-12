# Local environment (Part 3)

A laptop-sized replica of the AWS stack: PostgreSQL (RDS stand-in) + SonarQube,
deployed against a local Kubernetes cluster. The scripts support Kind, Docker
Desktop's kubeadm cluster and any other existing context.

PostgreSQL is a plain `StatefulSet` using the **official `postgres` image**
pinned to a specific patch and Alpine release (`postgres:17.6-alpine3.22`).
No Bitnami chart and no rolling tags, so there are no image warnings.

## One command

```bash
# No arguments: auto-detect a running cluster
./scripts/local-up.sh

# Force a provider
CLUSTER_PROVIDER=docker-desktop ./scripts/local-up.sh
CLUSTER_PROVIDER=kind ./scripts/local-up.sh
CLUSTER_PROVIDER=existing KUBE_CONTEXT=minikube ./scripts/local-up.sh
```

Auto-detection order (only for **reachable** contexts):

1. `docker-desktop` (Docker Desktop Kubernetes)
2. `minikube`
3. any existing `kind-*` cluster
4. otherwise create a Kind cluster if the `kind` binary is installed

So on a Docker Desktop-only machine, `./scripts/local-up.sh` with no arguments
uses Docker Desktop. On a machine with no running cluster and no Kind, it exits
with instructions.

The script:

1. Resolves the cluster context (creating Kind only when nothing is running).
2. Creates the `sonarqube-db` Secret with the same keys the Terraform stack uses
   (`host`, `port`, `database`, `username`, `password`, `sslmode`, `jdbc-url`).
3. Removes the legacy Bitnami PostgreSQL release (if present), recreates the
   `local-pg-postgresql` Service/NetworkPolicy and applies
   `kubernetes/local/postgresql.yaml`, then waits for the rollout.
4. Installs the official SonarQube chart with `helm/local/sonarqube-values.yaml`.
5. Prints the first-login credentials and the port-forward command.

It uses `--context` / `--kube-context` throughout, so it never rewrites your
current `kubectl` context.

## Docker Desktop specifics

* **Enable Kubernetes** in Docker Desktop settings and wait for the
  `docker-desktop` context (`kubectl config get-contexts`).
* Give the VM enough resources: **4+ CPUs and 8 GiB RAM** (SonarQube requests
  2 GiB, plus PostgreSQL and system pods).
* **Storage:** Docker Desktop's default StorageClass is `hostpath`. The script
  uses the cluster default for both PostgreSQL and SonarQube. If your version
  does not mark a default class, pin it:
  `STORAGE_CLASS=hostpath ./scripts/local-up.sh`.
* **Service exposure:** the chart uses `ClusterIP` and the demo uses
  `kubectl port-forward`, which works identically on Kind, Docker Desktop and
  minikube. Set `SERVICE_TYPE=NodePort` if you prefer direct node access on
  Docker Desktop/minikube (the assigned nodePort is random; NodePort is not
  exposed on Kind without extra port mappings).
* **`vm.max_map_count`:** SonarQube's `initSysctl` container needs privileged
  access. If the pod logs `max virtual memory areas vm.max_map_count is too low`,
  raise it in the Docker Desktop VM once:

  ```bash
  docker run --rm --privileged --pid=host alpine:3.20 \
    nsenter -t 1 -m -u -n -i sysctl -w vm.max_map_count=524288
  ```

## Database password invariant

`scripts/local-up.sh` reuses the password from the existing `sonarqube-db`
Secret. PostgreSQL only reads `POSTGRES_PASSWORD_FILE` when it initialises the
data directory, so changing the Secret alone desynchronises it from the PVC and
SonarQube will fail with `password authentication failed`. To reset the
credentials, delete the Secret **and** the PostgreSQL PVC (`data-local-pg-0`),
then re-run the script.

## First start is slow

The first boot runs database schema migrations and builds the Elasticsearch
index. The chart's readiness probe accepts `DB_MIGRATION_RUNNING` as ready, so
Helm can report success while the UI still shows a loading page. `local-up.sh`
now waits for `/api/system/status` to report `UP` and prints the status while it
waits (default 15 minutes; override with `STARTUP_TIMEOUT_SECONDS=1800`).

Check manually:

```bash
kubectl -n sonarqube exec sonarqube-sonarqube-0 -- \
  curl -s localhost:9000/api/system/status
```

* `STARTING` / `DB_MIGRATION_RUNNING` — still booting; wait.
* `UP` — open the UI.
* `DOWN` — check `kubectl -n sonarqube logs sonarqube-sonarqube-0`.

If you started the port-forward before the pod was ready, restart it after
`UP`: a pod restart breaks an existing `kubectl port-forward`.

## Demo flow

```bash
kubectl get pods -n sonarqube                 # local-pg-0 and sonarqube-sonarqube-0 Running 1/1

# wait for the API to be usable (the script does this automatically)
kubectl -n sonarqube exec sonarqube-sonarqube-0 -- \
  curl -s localhost:9000/api/system/status

kubectl logs -n sonarqube sonarqube-sonarqube-0 | grep -i "database"
# Forward the Service, not the pod: it follows the Service to its ready
# endpoint and survives pod restarts. Use pod/... only to debug a pod that is
# not Ready.
kubectl port-forward -n sonarqube svc/sonarqube-sonarqube 9000:9000
# equivalent, using the chart's named port
kubectl port-forward -n sonarqube svc/sonarqube-sonarqube 9000:http
kubectl apply -f kubernetes/sonarqube-db-fixer/job.yaml
kubectl -n sonarqube logs job/sonarqube-db-fixer
```

If you used a non-Kind cluster, pass the same context to the commands
(`kubectl --context docker-desktop ...`).

Use k9s for the walking tour: `:ns`, `:pods`, `l` (logs), `s` (shell), `e` (edit).

## If SonarQube does not become ready

`helm --wait` reports something like
`StatefulSet/sonarqube/sonarqube-sonarqube not ready ... Ready: 0/1` and exits
after the timeout. That is a symptom, not the cause. The script now prints pods,
PVCs, events, `describe` output and container logs automatically when the Helm
install fails. Check in this order:

1. **`Pending`** — the pod is not scheduled.
   * PVC `Pending`: the cluster has no default StorageClass. Re-run with
     `STORAGE_CLASS=hostpath` (Docker Desktop) or `STORAGE_CLASS=standard`
     (Kind/minikube). Delete the old PVC before retrying.
   * `FailedScheduling ... Insufficient memory`: raise Docker Desktop's memory
     allocation (8 GiB is comfortable; 4 GiB is the practical minimum).
2. **`Init:0/1`** — an init container is failing.
   * `initSysctl` requires privileged mode. If it logs
     `sysctl: permission denied`, raise `vm.max_map_count` in the Docker
     Desktop VM (command below) and retry.
   * `initFs` can fail on a storage class that ignores `fsGroup`; check its logs.
3. **`Running 0/1`** — the JVM is up but not ready.
   * `password authentication failed`: the Secret was rotated without resetting
     the PostgreSQL PVC. Delete `sonarqube-db`, `data-local-pg-0` and
     `sonarqube-sonarqube`, then re-run `./scripts/local-up.sh`.
   * Database unreachable: verify from the DB pod:
     ```bash
     kubectl -n sonarqube run pg-connectivity-check --rm -i --restart=Never \
       --image=postgres:17.6-alpine3.22 --labels=app=sonarqube \
       --command -- pg_isready -h local-pg-postgresql -p 5432 -U sonar -d sonarqube
     kubectl -n sonarqube exec local-pg-0 -- psql -U sonar -d sonarqube -c '\dt'
     ```
     Confirm the `sonarqube-db` Secret host is `local-pg-postgresql`. The local
     PostgreSQL NetworkPolicy allows any pod in the `sonarqube` namespace on
     5432 (production restricts this with the RDS security group instead).
   * Elasticsearch bootstrap rejected (`max virtual memory areas
     vm.max_map_count ... is too low`): apply the sysctl command below.
   * Readiness may simply need longer on a slow laptop; retry with
     `HELM_TIMEOUT=25m ./scripts/local-up.sh`.
4. **`ImagePullBackOff`** — registry access or a missing chart image tag. Check
   the image in `kubectl -n sonarqube describe pod ...`.
5. **Endpoints `<none>`** even though `local-pg-0` is Ready — usually a stale
   Service selector from the previous Bitnami release (it adds
   `app.kubernetes.io/instance: local-pg`). Re-run `./scripts/local-up.sh`; it
   uninstalls the legacy release and recreates the Service. Verify with
   `kubectl -n sonarqube get endpointslices -l kubernetes.io/service-name=local-pg-postgresql`
   (`kubectl get endpoints` is deprecated on Kubernetes 1.33+).

The script's diagnostics end with the container logs, which are usually enough to
identify the class of failure. If you need a clean retry:

```bash
 helm --kube-context <ctx> uninstall sonarqube -n sonarqube --ignore-not-found
 kubectl --context <ctx> -n sonarqube delete pvc sonarqube-sonarqube --ignore-not-found
 ./scripts/local-up.sh
```

## Live change ideas

```bash
# scale / restart
kubectl -n sonarqube rollout restart statefulset/sonarqube-sonarqube

# change a chart value without reinstalling
helm upgrade sonarqube sonarqube/sonarqube -n sonarqube \
  -f helm/local/sonarqube-values.yaml \
  --reuse-values --set resources.limits.memory=5Gi
```

## Tear down

```bash
./scripts/local-down.sh                                            # removes the workloads
CLUSTER_PROVIDER=kind DELETE_CLUSTER=1 ./scripts/local-down.sh     # deletes the Kind cluster
CLUSTER_PROVIDER=docker-desktop ./scripts/local-down.sh            # leaves Docker Desktop intact
```

`local-down.sh` deletes the SonarQube release, the PostgreSQL manifest, the
`data-local-pg-0` PVC and the `sonarqube-db` Secret.

Local values are intentionally weaker than production (single-node PostgreSQL,
ClusterIP + port-forward, inline passcode, small volumes). They exist only to
demonstrate the application and the Day-2 workflow.
