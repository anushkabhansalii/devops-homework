# Security (DevSecOps) — TaskBoard

Every control below runs automatically in the pipeline ([`.github/workflows/final-project.yml`](../../.github/workflows/final-project.yml)); the **security gate** job blocks the image push, the deploy test and the GitOps promotion unless all of them pass.

| Layer | Control | Tool | Fails the build when |
|---|---|---|---|
| Code | **SAST** | Bandit (`bandit -r app -ll -ii`) | MEDIUM+ severity & confidence finding in the backend |
| Dependencies | **SCA** | pip-audit (PyPI/OSV advisories) + `npm audit --audit-level=high` | any known-vulnerable Python package, or a HIGH+ npm advisory |
| Repository | **Secret scanning** | gitleaks over the full git history of `final-devops-project/` ([`gitleaks.toml`](./gitleaks.toml)) | a credential pattern is found |
| Images | **Container image scanning** | Trivy (pinned `aquasec/trivy:0.65.0` image) | a fixable HIGH/CRITICAL CVE in OS or language packages |
| Infrastructure | **IaC checks** | `terraform fmt/validate`, `helm lint`, Trivy misconfiguration scan (informational) | invalid Terraform/Helm |
| Gate | **Security gate** | `needs.*.result` | any of the above did not succeed |

## Hardening built into the project
**Images** ([`docker/`](../docker))
- small bases (`python:3.13-alpine`, `nginxinc/nginx-unprivileged:1.29-alpine`), `apk upgrade` at build time
- pip/setuptools/wheel removed from the runtime image (they carried the CVEs found in session 17)
- non-root numeric users (backend `10001`, frontend `101`), no shells needed at runtime
- multi-stage frontend build: Node toolchain never ships, only static files + nginx

**Kubernetes** ([`helm/taskboard`](../helm/taskboard))
- `runAsNonRoot`, numeric `runAsUser`, `seccompProfile: RuntimeDefault` on every pod
- `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` on every container (writable `emptyDir`s only where needed)
- PostgreSQL runs as uid 70 with a read-only root filesystem
- resource requests/limits everywhere; probes on every container
- DB credentials only in a Secret that is **created out-of-band** ([`gitops/create-db-secret.sh`](../gitops/create-db-secret.sh), random password, never in Git); in a real cluster: External Secrets Operator + AWS Secrets Manager, or Sealed Secrets

**AWS** ([`terraform/`](../terraform))
- EKS Secrets encrypted with a customer-managed **KMS key** (rotation on)
- EKS API endpoint public **only for `cluster_admin_cidrs`** (validation rejects `0.0.0.0/0`); worker nodes in **private subnets** behind a NAT gateway
- public subnets don't auto-assign public IPs
- IAM: separate cluster and node roles with only the AWS-managed EKS policies they need

**Supply chain / CI**
- scanner images pinned to exact versions (the `aquasecurity/trivy-action` tags were hijacked in a 2026 supply-chain attack)
- least-privilege `GITHUB_TOKEN`: workflow default `contents: read`; only `push` gets `packages: write`, only `gitops-promote` gets `contents: write`
- CI never gets cluster credentials: production is changed only through Git (Argo CD pulls)

## Accepted risks (documented, not ignored)
| Finding (Trivy IaC scan) | Why it remains |
|---|---|
| `AVD-AWS-0040` EKS public endpoint enabled | needed for kubectl from a laptop without a VPN; restricted to admin CIDRs instead |
| `AVD-AWS-0041` open CIDR for public access | false positive: `public_access_cidrs` comes from `var.cluster_admin_cidrs`, which a validation rule forbids from containing `0.0.0.0/0` — a static scanner can't evaluate that |
