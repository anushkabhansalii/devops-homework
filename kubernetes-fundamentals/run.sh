#!/bin/bash
# Kubernetes Fundamentals homework. Requires Docker Desktop running + minikube installed.
# brew install minikube
# Usage: ./run.sh
OUT=/tmp/k8s-fundamentals.txt; : > "$OUT"
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

run 'minikube start'
run 'minikube status'
run 'kubectl cluster-info'
run 'kubectl get nodes -o wide'
run 'kubectl get pods -n kube-system'
run 'kubectl get all -A'

echo "Log written to $OUT"
