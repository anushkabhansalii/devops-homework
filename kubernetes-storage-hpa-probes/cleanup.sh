#!/bin/bash
# Removes everything created by run.sh
cd "$(dirname "$0")"

echo "[INFO] Deleting mini project namespace (deployment, service, hpa, pvc)..."
kubectl delete namespace production-webapp --ignore-not-found

echo "[INFO] Deleting probe demo pods and services..."
kubectl delete svc readiness-service readiness-broken-service --ignore-not-found
kubectl delete -f 03-probes/ --ignore-not-found

echo "[INFO] Deleting HPA demo..."
kubectl delete -f 02-hpa/ --ignore-not-found

echo "[INFO] Deleting volume demo pods, PVCs and PV..."
kubectl delete -f 01-kubernetes-volumes/pod.yaml -f 01-kubernetes-volumes/emptydir-pod.yaml -f 01-kubernetes-volumes/hostpath-pod.yaml --ignore-not-found
kubectl delete -f 01-kubernetes-volumes/pvc.yaml -f 01-kubernetes-volumes/dynamic-pvc.yaml --ignore-not-found
kubectl delete -f 01-kubernetes-volumes/pv.yaml --ignore-not-found

echo "[INFO] All demo resources removed."
