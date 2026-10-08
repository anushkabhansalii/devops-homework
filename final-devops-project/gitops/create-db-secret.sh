#!/bin/bash
# The production DB password is NOT in Git. Create the Secret once, out-of-band, before Argo CD syncs.
# (In a real cluster: External Secrets Operator / Sealed Secrets / AWS Secrets Manager instead.)
set -e
NS=taskboard-prod
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -
# idempotent: never replace an existing password (PostgreSQL keeps the one it was initialised with)
if kubectl -n $NS get secret taskboard-db >/dev/null 2>&1; then echo "secret/taskboard-db already exists - leaving it alone"; exit 0; fi
kubectl -n $NS create secret generic taskboard-db \
  --from-literal=POSTGRES_USER=taskboard \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "secret/taskboard-db ready in namespace $NS (random password, never written to disk)"
