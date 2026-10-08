#!/bin/bash
# Render the Helm chart to plain Kubernetes YAML (what actually gets applied), for review / kubectl diff.
set -e
cd "$(dirname "$0")"
helm template taskboard ../helm/taskboard -n taskboard -f ../helm/taskboard/values-dev.yaml  > rendered/taskboard-dev.yaml
helm template taskboard ../helm/taskboard -n taskboard-prod -f ../helm/taskboard/values-prod.yaml > rendered/taskboard-prod.yaml
grep -h '^kind:' rendered/*.yaml | sort | uniq -c
