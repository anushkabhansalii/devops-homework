# GitOps — TaskBoard production

```text
developer push ─► GitHub Actions: test → scan → gate → push images to GHCR → kind deploy test
                                                                                  │
                         gitops-promote job commits new image tags ◄──────────────┘
                         to helm/taskboard/values-prod.yaml  ("[skip ci]")
                                             │
                        Argo CD (in the cluster) sees the new commit on main
                                             │
                        renders the Helm chart with values-prod.yaml and syncs namespace taskboard-prod
```
- [`argocd-application.yaml`](./argocd-application.yaml) — applied once; `automated: {prune, selfHeal}`, `CreateNamespace=true`
- [`create-db-secret.sh`](./create-db-secret.sh) — creates the DB Secret out-of-band with a random password (idempotent: never rotates an existing one)

The pipeline has **no cluster credentials**: it can only propose a new desired state by committing to Git. Rolling back production = `git revert` of the promotion commit.
