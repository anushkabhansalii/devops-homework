# Kubernetes — TaskBoard

The deployable unit is the Helm chart in [`../helm/taskboard`](../helm/taskboard); this folder holds what it turns into, plus the troubleshooting challenge.

| Path | Contents |
|---|---|
| [`render.sh`](./render.sh) | `helm template` the chart with dev and prod values |
| [`rendered/taskboard-dev.yaml`](./rendered/taskboard-dev.yaml) | plain manifests for minikube (local images, 1 replica, no HPA) |
| [`rendered/taskboard-prod.yaml`](./rendered/taskboard-prod.yaml) | plain manifests Argo CD applies in production (GHCR images, HPA) |
| [`troubleshooting/broken-values.yaml`](./troubleshooting/broken-values.yaml) | a "bad release": image tag typo, Ingress host typo, wrong readiness path |
| [`troubleshooting/break-db-secret.sh`](./troubleshooting/break-db-secret.sh) | half-done DB password rotation (Secret changed, database not) |

## Objects in the release
| Kind | Name | Purpose |
|---|---|---|
| ConfigMap | `taskboard-config` | non-secret settings: environment, DB host/port/name |
| Secret | `taskboard-db` | DB user + password (created out-of-band, not by Helm) |
| StatefulSet + headless Service | `taskboard-postgres` | PostgreSQL with a stable identity (`-0`) and its own **PersistentVolumeClaim** (`volumeClaimTemplates`, 1Gi, default StorageClass) |
| Deployment + Service | `taskboard-backend` | FastAPI; **init container** waits for the DB; **startup / readiness (`/ready`, checks DB) / liveness (`/health`) probes** |
| Deployment + Service | `taskboard-frontend` | nginx serving the React build and proxying `/api` to the backend Service |
| Ingress | `taskboard` | `taskboard.local`: `/api` → backend, `/` → frontend (NGINX Ingress Controller) |
| HorizontalPodAutoscaler | `taskboard-backend` | 2–6 replicas at 60% CPU (prod) |
| ServiceMonitor, PrometheusRule, dashboard ConfigMap | — | monitoring (see [`../monitoring`](../monitoring)) |

```text
             Ingress (taskboard.local)
             /api ───────────────┐      / ─────────────┐
                                 ▼                     ▼
                     Service taskboard-backend   Service taskboard-frontend
                                 │                     │   (nginx proxies /api too)
                     Deployment backend (HPA)    Deployment frontend
                     ConfigMap + Secret env            
                                 │
                     Service taskboard-postgres (headless)
                                 │
                     StatefulSet postgres-0 ── PVC data-taskboard-postgres-0 ── PV (StorageClass)
```
