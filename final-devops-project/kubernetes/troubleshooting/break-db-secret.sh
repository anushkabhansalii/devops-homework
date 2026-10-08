#!/bin/bash
# issue 4: someone "rotates" the DB password in the Secret only. PostgreSQL still has the old password,
# so the backend can no longer log in after its next restart.
kubectl -n taskboard patch secret taskboard-db --type merge -p '{"stringData":{"POSTGRES_PASSWORD":"rotated-but-not-in-db"}}'
kubectl -n taskboard rollout restart deployment/taskboard-backend
