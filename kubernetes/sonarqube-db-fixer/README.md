# SonarQube database fixer (Part 2)

An ephemeral Kubernetes `Job` that applies a targeted database change and exits:

```sql
UPDATE settings SET value = 'true' WHERE key = 'sonar.forceAuthentication';
```

## Why a Job (and not a Pod or Deployment)

| Requirement | How it is met |
| :--- | :--- |
| Run once, then stop | `kind: Job` with `restartPolicy: Never` |
| Survive a transient DB blip | `backoffLimit: 3` |
| Never hang forever | `activeDeadlineSeconds: 300` |
| Clean up afterwards | `ttlSecondsAfterFinished: 600` |
| Prove the change | `DO $$` block raises if the row is missing or not `true` |
| No plaintext credentials | All connection settings come from files mounted from `sonarqube-db`, which is created locally by `scripts/local-up.sh` or synced from AWS Secrets Manager by External Secrets Operator |
| Least privilege | Dedicated ServiceAccount with the API token not mounted, non-root user, read-only root filesystem, all capabilities dropped |

## Run it

```bash
# The Secret is created locally by scripts/local-up.sh, or synced from AWS
# Secrets Manager by External Secrets Operator in the AWS environment.
kubectl -n sonarqube get secret sonarqube-db

kubectl apply -f job.yaml
kubectl -n sonarqube wait --for=condition=complete job/sonarqube-db-fixer --timeout=120s
kubectl -n sonarqube logs job/sonarqube-db-fixer

# Expected tail:
#   UPDATE 1
#   key                          | value
#   -----------------------------+-------
#   sonar.forceAuthentication    | true
```

Watch it in k9s: `:jobs` -> select `sonarqube-db-fixer` -> `l` for logs, `s` to
shell into the pod while it runs.

## Local Kubernetes (no AWS)

The Job is cloud-agnostic: it reads a Kubernetes Secret and talks to PostgreSQL.
It never calls AWS, so External Secrets Operator and Secrets Manager are not
required locally.

```bash
kubectl --context docker-desktop -n sonarqube get secret sonarqube-db
kubectl --context docker-desktop apply -f kubernetes/sonarqube-db-fixer/job.yaml
kubectl --context docker-desktop -n sonarqube \
  wait --for=condition=complete job/sonarqube-db-fixer --timeout=120s
kubectl --context docker-desktop -n sonarqube logs job/sonarqube-db-fixer
```

`scripts/local-up.sh` already creates `sonarqube-db` with the keys the Job
expects (`host`, `port`, `database`, `username`, `password`, `sslmode`).
If you are not using that script, create the Secret manually:

```bash
kubectl --context docker-desktop -n sonarqube create secret generic sonarqube-db \
  --from-literal=host=local-pg-postgresql \
  --from-literal=port=5432 \
  --from-literal=database=sonarqube \
  --from-literal=username=sonar \
  --from-literal=password='<local db password>' \
  --from-literal=sslmode=disable
```

Prerequisites: SonarQube has reached `UP` (`GET /api/system/status`) so the
`settings` table exists, and the local PostgreSQL Service is reachable. The
statement updates a row that must already exist; if it does not, set
`sonar.forceAuthentication` once through the UI/API or insert the row first.

## Credential flow

```
core-secretsmanager / core-rds  (write-only secret versions in Secrets Manager)
        │
        ▼
External Secrets Operator (core-external-secrets, Pod Identity)
        │  ExternalSecret "sonarqube-db" (refreshInterval, deletionPolicy Retain)
        ▼
Kubernetes Secret sonarqube-db
        ├──► SonarQube Helm release (jdbcSecretName / jdbcSecretPasswordKey)
        └──► this Job (secret files mounted at /etc/sonarqube-db)
```

No credential is written into a manifest, a Helm value, a container image or
Terraform state.

## Credential prerequisites

* **Local:** `scripts/local-up.sh` creates `sonarqube-db`; no ESO or AWS needed.
* **AWS:** `core-external-secrets` installs the operator and
  `aws-secretsmanager` ClusterSecretStore; the chart `helm/sonarqube-secrets`
  creates the ExternalSecrets.
* **Manual:** create `sonarqube-db` with `host`, `port`, `database`,
  `username`, `password` and `sslmode`.

## Re-running

`kubectl delete job sonarqube-db-fixer -n sonarqube` then apply again. The
statement is idempotent, so a rerun is safe.
