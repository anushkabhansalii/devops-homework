#!/bin/bash
# Removes everything created by run.sh
cd "$(dirname "$0")"
echo "[INFO] Deleting mini project + triage gauntlet..."
kubectl delete pods -l tier=triage-gauntlet --ignore-not-found
kubectl delete -f mini-project/deployment.yaml -f mini-project/service.yaml -f mini-project/fixed-pod.yaml --ignore-not-found
echo "[INFO] Deleting any leftover demo resources..."
kubectl delete pod logs-demo crash-demo image-demo pending-demo creating-demo client dns-test dns-client config-demo oom-demo --ignore-not-found
kubectl delete deployment web --ignore-not-found
kubectl delete svc web-service web-port-service --ignore-not-found
kubectl delete configmap site-content --ignore-not-found
kubectl delete secret db-secret --ignore-not-found
echo "[INFO] All demo resources removed."
