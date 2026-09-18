#!/bin/bash
# Kubernetes Pods, ReplicaSets & Deployments homework.
# Requires Docker Desktop running + minikube installed + minikube start already run.
# Usage: ./run.sh
OUT=/tmp/k8s-pods.txt; : > "$OUT"
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

# 1. Pod
run 'kubectl apply -f pod.yml'
sleep 3
run 'kubectl get pods -o wide'
run 'kubectl logs nginx-pod'
run 'kubectl delete -f pod.yml'

# 2. Pod lifecycle (busybox runs once and exits -> Completed)
run 'kubectl apply -f hello.yml'
sleep 3
run 'kubectl get pods'
run 'kubectl logs hello-pod'
run 'kubectl delete -f hello.yml'

# 3. Bad image -> ErrImagePull / ImagePullBackOff
run 'kubectl apply -f hello-badimage.yml'
sleep 5
run 'kubectl get pods'
run 'kubectl describe pod hello-badimage-pod'
run 'kubectl delete -f hello-badimage.yml'

# 4. ReplicaSet + self-healing
run 'kubectl apply -f replicaset.yml'
sleep 3
run 'kubectl get rs'
run 'kubectl get pods -o wide -l app=nginx'
run 'kubectl delete pod $(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")'
sleep 3
run 'kubectl get pods -l app=nginx'
run 'kubectl delete -f replicaset.yml'

# 5. Deployment (manages a ReplicaSet, which manages the Pods)
run 'kubectl apply -f deployment.yml'
sleep 5
run 'kubectl get deployments'
run 'kubectl get rs'
run 'kubectl get pods -o wide'

# 6. Expose the Deployment with a Service
run 'kubectl apply -f service.yml'
run 'kubectl get svc'
run 'curl -s $(minikube service nginx-service --url) | head -8'

run 'kubectl delete -f service.yml -f deployment.yml'

echo "Log written to $OUT"
