# External secrets (runtime credential path)

Credentials are **not** written to Kubernetes by Terraform. Instead:

```
core-secretsmanager / core-rds   (write-only secret versions in AWS Secrets Manager)
        │
        ▼
core-external-secrets
   External Secrets Operator (Helm 2.15.0)
   IAM role + EKS Pod Identity association
   ClusterSecretStore "aws-secretsmanager"
        │
        ▼
helm/sonarqube-secrets
   ExternalSecret sonarqube-db      -> Secret sonarqube-db
   ExternalSecret sonarqube-admin   -> Secret sonarqube-admin
        │
        ├──► SonarQube Helm release (secrets by reference)
        └──► kubernetes/sonarqube-db-fixer Job (files mounted from the Secret)
```

## Apply order

1. `core-eks` (cluster, Pod Identity agent, node groups)
2. `core-secretsmanager` (secret containers + write-only versions)
3. `core-rds` (database + JDBC JSON secret version)
4. `core-external-secrets` (this operator and the store)
5. `core-sonarqube` (ExternalSecrets + the SonarQube release)

`core-external-secrets` comes after the producers so its IAM policy can be
scoped to the exact secret ARNs; `core-sonarqube` comes last so the
ClusterSecretStore already exists.

## Operational checks

```bash
kubectl -n external-secrets get pods
kubectl get clustersecretstore aws-secretsmanager -o wide
kubectl -n sonarqube get externalsecret
kubectl -n sonarqube describe externalsecret sonarqube-db

# Force an immediate refresh
kubectl -n sonarqube annotate externalsecret sonarqube-db \
  force-sync="$(date +%s)" --overwrite
```

A failed sync shows up as `SecretSyncedError` on the ExternalSecret and in the
controller logs:

```bash
kubectl -n external-secrets logs deploy/external-secrets -c external-secrets
```

## Design notes

* **Pod Identity, not keys.** The controller role trusts
  `pods.eks.amazonaws.com` and is bound to the `external-secrets` service
  account. No `SecretStore` auth block, no `aws-credentials` Secret.
* **Least privilege.** The policy lists the seven platform secret ARNs plus the
  secrets CMK; there is no `Resource: "*"`.
* **Retain on delete.** `target.deletionPolicy: Retain` keeps the Kubernetes
  Secret if an ExternalSecret is removed, so a bad rollout cannot strip
  credentials from a running SonarQube pod.
* **Rotation.** Changing a secret in Secrets Manager propagates within
  `external_secrets_refresh_interval` (default `1h`). Restart SonarQube after a
  database password rotation so it re-creates its JDBC pool.
* **No Terraform secret reads.** Terraform never calls
  `secretsmanager:GetSecretValue`; ESO does, at runtime, with its own identity.
