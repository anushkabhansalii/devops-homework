# Final DevOps Project — TaskBoard

**Name:** Anushka Jain

An end-to-end DevOps project (Session 21) built around **TaskBoard**, a task-management app (React + FastAPI + PostgreSQL), taking it from source code to a monitored, GitOps-managed Kubernetes deployment. Everything below ran for real — locally via [`run.sh`](./run.sh) (`local`, `terraform`, `deploy`, `troubleshoot`, `gitops`) and in GitHub Actions ([workflow](../.github/workflows/final-project.yml)).

```text
final-devops-project/
├── application/   backend/ (FastAPI, SQLAlchemy, Alembic, pytest) + frontend/ (React 19 + Vite 8)
├── docker/        backend.Dockerfile, frontend.Dockerfile, docker-compose.yml
├── kubernetes/    rendered manifests + troubleshooting challenge
├── helm/          taskboard chart (values.yaml, values-dev.yaml, values-prod.yaml)
├── terraform/     AWS VPC + IAM + EKS (+ KMS)
├── security/      DevSecOps controls, gitleaks config
├── monitoring/    metrics, alerts, Grafana dashboard
├── gitops/        Argo CD Application + out-of-band DB secret script
└── screenshots/
.github/workflows/final-project.yml   CI/CD + DevSecOps + GitOps promotion
```

## Architecture
```mermaid
flowchart LR
  dev[Developer] -->|git push| gh[GitHub]
  gh --> ci[GitHub Actions<br/>test · build · SAST · SCA · secrets · Trivy · IaC]
  ci -->|security gate passed| reg[(GHCR images)]
  ci -->|kind deploy test| ci
  ci -->|bot commits image tag| gh
  gh -->|watched by| argo[Argo CD]
  argo -->|helm render + sync| k8s
  tf[Terraform] -->|VPC + EKS| aws[(AWS)]
  subgraph k8s[Kubernetes]
    ing[Ingress] --> fe[frontend nginx]
    ing --> be[backend FastAPI<br/>HPA 2-6]
    fe --> be --> pg[(PostgreSQL<br/>StatefulSet + PVC)]
  end
  prom[Prometheus] -->|scrapes /metrics| be
  prom --> graf[Grafana]
  prom --> am[Alertmanager]
```

| Requirement | Where |
|---|---|
| Application | [`application/`](./application) — 11 backend tests (99% coverage), Vite build |
| Docker | [`docker/`](./docker) — hardened non-root images, compose stack |
| Kubernetes: Deployment, Service, ConfigMap, Secret, Ingress, HPA, Probes, Storage | [`helm/taskboard`](./helm/taskboard), explained in [`kubernetes/`](./kubernetes) |
| Helm | [`helm/taskboard`](./helm/taskboard) — dev & prod values |
| Terraform | [`terraform/`](./terraform) — VPC, NAT, IAM, EKS, KMS (23 resources) |
| CI/CD (build, test, docker build, image push, deploy) | [workflow](../.github/workflows/final-project.yml) |
| DevSecOps (SAST, SCA, secret scanning, image scanning, gate) | [`security/`](./security) |
| Monitoring (metrics, logs, alerts, dashboard) | [`monitoring/`](./monitoring) |
| GitOps | [`gitops/`](./gitops) — Argo CD |
| Troubleshooting challenge | [section below](#7-final-troubleshooting-challenge) |

---

## 1. Application + Docker (local)
```text
$ docker compose -f docker/docker-compose.yml up -d --build
 Container docker-postgres-1 Healthy
 Container docker-backend-1 Started
 Container docker-frontend-1 Started
$ curl -s localhost:3000/api/info
{"service":"TaskBoard API","version":"dev","environment":"local"}
$ curl -s -X POST localhost:3000/api/tasks -d '{"title":"Write final README","priority":"HIGH","assignee":"Anushka"}' ...
{"title":"Write final README",...,"status":"TODO","assignee":"Anushka","id":1,...}
$ docker compose exec backend id
uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
```
![TaskBoard UI](screenshots/02b-taskboard-ui.png)

## 2. Terraform — AWS platform
VPC (2 AZs, public + private subnets, IGW, NAT), IAM roles, KMS key, EKS cluster + managed node group. Run against **Moto** (local AWS emulator — no AWS account on this machine; `use_local_emulator=false` targets real AWS).
```text
$ terraform plan -out=tfplan
Plan: 23 to add, 0 to change, 0 to destroy.
$ terraform apply tfplan
aws_eks_cluster.main: Creation complete after 0s [id=taskboard-eks]
aws_eks_node_group.main: Creation complete after 0s [id=taskboard-eks:taskboard-eks-nodes]
Apply complete! Resources: 23 added, 0 changed, 0 destroyed.
cluster_endpoint  = "https://zxN3vYFFO2AyM7W4gRQw.H4R.ap-south-1.eks.amazonaws.com/"
node_group_status = "ACTIVE"
configure_kubectl = "aws eks update-kubeconfig --region ap-south-1 --name taskboard-eks"
$ terraform destroy -auto-approve
Destroy complete! Resources: 23 destroyed.
```

## 3. Kubernetes + Helm (minikube)
```text
$ bash gitops/create-db-secret.sh taskboard          <- random DB password, never in Git
$ helm upgrade --install taskboard helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml --wait
STATUS: deployed
$ kubectl -n taskboard get pods,svc,ingress,pvc
pod/taskboard-backend-697458449-2n8tz     1/1  Running   0
pod/taskboard-frontend-54c49d544d-87jv6   1/1  Running   0
pod/taskboard-postgres-0                  1/1  Running   0
ingress.networking.k8s.io/taskboard   nginx   taskboard.local
persistentvolumeclaim/data-taskboard-postgres-0   Bound   1Gi   RWO   standard
```
- **ConfigMap** (env, DB host) + **Secret** (DB user/password, values never printed)
- **init container** `wait-for-db` (fixed a crash-on-start race found during testing), **startup / readiness (`/ready`, checks DB) / liveness (`/health`) probes**
- every container non-root, read-only root FS, all capabilities dropped
```text
$ curl -s -H 'Host: taskboard.local' localhost:8090/api/info          (through the NGINX Ingress)
{"service":"TaskBoard API","version":"dev-local","environment":"dev"}
$ ... -X PUT /api/tasks/1 -d '{"status":"DONE"}'
{"id":1,"title":"Deployed on Kubernetes","status":"DONE"}
```
**Storage**: deleted `taskboard-postgres-0` → the StatefulSet recreated it on the same PVC → the task was still there.
> Found while testing: minikube's hostpath provisioner **does not wipe PV data when the PVC is deleted**, so a reinstall reused an old database with an old password (`password authentication failed`). `run.sh cleanup` now wipes it, and `deploy` refuses to start on stale data.

## 4. Monitoring
```text
$ curl -s localhost:9090/api/v1/targets | jq ...
taskboard-backend   http://10.244.0.82:8000/metrics   up
$ PromQL: sum by (handler, method, status) (rate(http_requests_total{namespace="taskboard"}[1m]))
GET   /api/tasks            2xx  1.42  req/s
GET   /api/tasks/stats      2xx  1.42  req/s
GET   /api/tasks/{task_id}  4xx  0     req/s
$ alert rules
TaskBoardBackendDown     ok  inactive
TaskBoardHighErrorRate   ok  inactive
TaskBoardSlowRequests    ok  inactive
TaskBoardPodRestarting   ok  firing        <- real: the stale-password crash loop above
```
The chart ships its own **Grafana dashboard** (ConfigMap picked up by the Grafana sidecar):

![TaskBoard Grafana dashboard](screenshots/11b-grafana-taskboard-dashboard.png)

## 5. CI/CD + DevSecOps pipeline
15 jobs, all green ([run 37727471059](https://github.com/anushkabhansalii/devops-homework/actions/runs/37727471059)):
```text
✓ Backend tests (pytest)            11 passed, 99% coverage
✓ Frontend build (Vite)             built in 96ms
✓ IaC check                          terraform fmt/validate, helm lint, Trivy config scan
✓ SAST (Bandit)                      No issues identified
✓ SCA (pip-audit + npm audit)        No known vulnerabilities / found 0 vulnerabilities
✓ Secret scan (gitleaks)             4 commits scanned, no leaks found
✓ Docker build (backend, frontend)
✓ Image scan (Trivy)                 0 HIGH/CRITICAL in both images
✓ Security gate                      PASSED
✓ Push images (GHCR)                 ghcr.io/anushkabhansalii/taskboard-{backend,frontend}:0b26cf9
✓ Deploy test (kind + Helm)          all pods Running; smoke test through nginx -> API -> PostgreSQL
✓ GitOps - promote to production     bot commit: values-prod.yaml tag "3b8c87b" -> "0b26cf9"
```
First run failed only because my informational Trivy IaC step passed two paths (it accepts one) — the gate correctly blocked the release. IaC findings were then fixed (KMS encryption for EKS Secrets, API endpoint restricted to admin CIDRs, no auto public IPs, PostgreSQL non-root); remaining accepted risks are in [`security/`](./security).

## 6. GitOps — and a real production incident
`kubectl apply -f gitops/argocd-application.yaml` once; Argo CD deploys `helm/taskboard` + `values-prod.yaml` from GitHub into `taskboard-prod`. The pipeline never touches the cluster — it only commits new image tags.

**First deploy (`3b8c87b`) → `Synced / Degraded`:**
```text
taskboard-prod-frontend-…   0/1   Error   3 restarts
Reason: OOMKilled                     <- nginx "worker_processes auto" = 10 workers (one per node CPU) in a 64Mi limit
nginx: [emerg] host not found in upstream "taskboard-prod-backend"   <- DNS blip while the node was NotReady; nginx resolves only at start
```
**Fix in Git** ([c2092e6](https://github.com/anushkabhansalii/devops-homework/commit/c2092e6)): `worker_processes 2` + 128Mi limit; nginx `resolver` + variable `proxy_pass` with the Service FQDN so DNS is resolved per request (a DNS outage becomes a 502, not a dead pod — verified with compose by stopping the backend).

**Pipeline → bot commit → Argo CD:**
```text
a4acb94 chore(gitops): deploy taskboard 0b26cf9 to prod [skip ci]      (github-actions[bot])
0b26cf9 Fix two production bugs found after the first GitOps deploy
$ argocd history
0  86dede2…  2026-10-08T04:14:15Z
1  0b26cf9…  2026-10-08T04:29:08Z
2  a4acb94…  2026-10-08T04:30:23Z
$ curl -s -H 'Host: taskboard-prod.local' localhost:8090/api/info
{"service":"TaskBoard API","version":"0b26cf9","environment":"prod"}
$ frontend: worker_processes 2;  resolver 10.96.0.10 valid=10s ipv6=off;
$ kubectl -n taskboard-prod get hpa       cpu: 6%/60%   2   6   2
$ kubectl -n argocd get application taskboard-prod
taskboard-prod   Synced   Healthy
```

## 7. Final troubleshooting challenge
A bad release with 4 faults at once ([`broken-values.yaml`](./kubernetes/troubleshooting/broken-values.yaml) + [`break-db-secret.sh`](./kubernetes/troubleshooting/break-db-secret.sh)):
```text
GET http://taskboard.local/          -> HTTP 404
GET http://taskboard.local/api/info  -> HTTP 404
taskboard-backend-dcccf9b5f-lx6fc     0/1   Error
taskboard-frontend-866db9c555-mx7vb   0/1   ErrImageNeverPull
```
| # | Symptom | Investigation | Root cause | Fix | Verify |
|---|---|---|---|---|---|
| 1 | every URL 404 | `kubectl get ingress` → host `taskboard.locl` | Ingress host typo | correct host via `helm upgrade` | `/` → 200 |
| 2 | new frontend pod never starts | `describe` → `ErrImageNeverPull ... taskboard-frontend:dev-typo` | image tag doesn't exist | correct tag | pod Running |
| 3 | new backend pods crash | `logs --previous` → `password authentication failed` | Secret rotated, DB not | `ALTER USER ... PASSWORD` to the Secret's value, restart | no crashes |
| 4 | new backend Running but 0/1 | EndpointSlice `ready=false`; `Readiness probe failed: 404`; `/ready` works from inside | probe path `/readyz` | correct path via `helm upgrade` | endpoint ready, API 200 |

Old pods kept serving the whole time — a rolling update never removes ready pods while new ones fail. After the fixes: all pods Running, `/` 200, `/api/info` OK, task data intact.

## Lessons learned
- Run it for real: init-container race, stale PV data, nginx OOM and DNS-at-startup all only appeared on a live cluster.
- The security gate works only if *every* check must pass — it blocked a release for a broken scanner step.
- GitOps makes production changes auditable: fix → commit → pipeline → bot commit → Argo CD, no kubectl in prod.
- Resource limits must account for how software sizes itself (`auto` worker counts follow node CPUs, not limits).
- Local clusters lie about memory (node reports host RAM, container has 3.9 GiB) — probes fail before the kubelet sees pressure.

## Screenshots
![compose up](screenshots/01-compose-up.png)
![compose test](screenshots/02-compose-test.png)
![TaskBoard UI](screenshots/02b-taskboard-ui.png)
![terraform plan](screenshots/03-terraform-plan.png)
![terraform apply](screenshots/04-terraform-apply.png)
![terraform destroy](screenshots/05-terraform-destroy.png)
![build images](screenshots/06-build-images.png)
![helm install](screenshots/07-helm-install.png)
![k8s objects](screenshots/08-k8s-objects.png)
![ingress crud](screenshots/09-ingress-crud.png)
![storage persistence](screenshots/10-storage-persistence.png)
![monitoring](screenshots/11-monitoring.png)
![grafana dashboard](screenshots/11b-grafana-taskboard-dashboard.png)
![ts break](screenshots/12-ts-break.png)
![ts identify](screenshots/13-ts-identify.png)
![ts issue 1 ingress](screenshots/14-ts-issue1-ingress.png)
![ts issue 2 image](screenshots/15-ts-issue2-image.png)
![ts issue 3 db secret](screenshots/16-ts-issue3-db-secret.png)
![ts issue 4 readiness](screenshots/17-ts-issue4-readiness.png)
![ts verify](screenshots/18-ts-verify.png)
![gitops setup](screenshots/19-gitops-setup.png)
![gitops verify](screenshots/20-gitops-verify.png)
![gitops incident](screenshots/21-gitops-incident.png)
![gitops promotion](screenshots/22-gitops-promotion.png)
![pipeline run](screenshots/23-pipeline-run.png)
![pipeline scans](screenshots/24-pipeline-scans.png)
![pipeline gate deploy promote](screenshots/25-pipeline-gate-deploy-promote.png)
