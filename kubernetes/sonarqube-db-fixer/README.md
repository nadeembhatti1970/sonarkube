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
| No plaintext credentials | All connection settings come from files mounted from `sonarqube-db`, which External Secrets Operator keeps in sync with AWS Secrets Manager |
| Least privilege | Dedicated ServiceAccount with the API token not mounted, non-root user, read-only root filesystem, all capabilities dropped |

## Run it

```bash
# The Secret is created by core-sonarqube (Terraform) or by the ExternalSecret
# alternative in this folder.
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

## Prerequisite

`core-external-secrets` must be applied (it installs the operator and the
`aws-secretsmanager` ClusterSecretStore). Terraform installs the
ExternalSecrets from `helm/sonarqube-secrets/`.

## Re-running

`kubectl delete job sonarqube-db-fixer -n sonarqube` then apply again. The
statement is idempotent, so a rerun is safe.
