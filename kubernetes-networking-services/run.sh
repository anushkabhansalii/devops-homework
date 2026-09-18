#!/bin/bash
# Kubernetes Networking & Services homework.
# Requires Docker Desktop running + minikube installed + minikube start already run.
# Usage: ./run.sh
set -e
cd "$(dirname "$0")"

echo "### 1. ClusterIP (internal-only) ###"
kubectl apply -f 01-clusterip/app-deployment.yaml -f 01-clusterip/service.yaml -f 01-clusterip/client-pod.yaml
kubectl wait --for=condition=Ready pod -l app=web-clusterip --timeout=90s
kubectl wait --for=condition=Ready pod/curl-client --timeout=90s
kubectl get svc web-service-clusterip
kubectl get endpoints web-service-clusterip
kubectl exec curl-client -- curl -s http://web-service-clusterip:8080 | head -6
kubectl exec curl-client -- curl -s http://web-service-clusterip.default.svc.cluster.local:8080 | head -3
kubectl delete -f 01-clusterip/client-pod.yaml -f 01-clusterip/service.yaml -f 01-clusterip/app-deployment.yaml

echo "### 2. NodePort (external access) ###"
kubectl apply -f 02-nodeport/app-deployment.yaml -f 02-nodeport/service.yaml
kubectl wait --for=condition=Ready pod -l app=web-nodeport --timeout=90s
kubectl get svc web-service-nodeport
kubectl port-forward svc/web-service-nodeport 8086:80 >/tmp/pf.log 2>&1 &
sleep 2; curl -s http://localhost:8086 | head -6; kill %1 2>/dev/null; wait 2>/dev/null
kubectl delete -f 02-nodeport/service.yaml -f 02-nodeport/app-deployment.yaml

echo "### 3. ReplicaSet: selectors/labels + scaling ###"
kubectl apply -f replicaset/yatri-backend-rs.yaml -f replicaset/yatri-backend-service.yaml
kubectl wait --for=condition=Ready pod -l app=yatri-backend --timeout=90s
kubectl get rs
kubectl get pods -l app=yatri-backend --show-labels
kubectl scale rs/yatri-backend-rs --replicas=5
sleep 3; kubectl get pods -l app=yatri-backend
kubectl scale rs/yatri-backend-rs --replicas=1
sleep 3; kubectl get pods -l app=yatri-backend

echo "### 4. Troubleshooting: selector mismatch -> empty endpoints ###"
kubectl apply -f troubleshooting/empty-endpoints.yaml
kubectl get endpoints broken-backend-service
kubectl get endpoints yatri-backend-service
kubectl delete -f troubleshooting/empty-endpoints.yaml -f replicaset/yatri-backend-service.yaml -f replicaset/yatri-backend-rs.yaml

echo "### 5. Deployment rolling update: v1 -> v2 -> rollback ###"
kubectl apply -f rolling-update/deployment-v1.yaml -f rolling-update/service.yaml
kubectl rollout status deployment/app-rolling --timeout=90s
kubectl get pods -l app=app-rolling --show-labels
kubectl port-forward svc/app-rolling-service 8084:80 >/tmp/pf2.log 2>&1 &
sleep 2; curl -s http://localhost:8084 | grep VERSION; kill %1 2>/dev/null; wait 2>/dev/null

kubectl apply -f rolling-update/deployment-v2.yaml
kubectl rollout status deployment/app-rolling --timeout=90s
kubectl get pods -l app=app-rolling --show-labels
kubectl port-forward svc/app-rolling-service 8085:80 >/tmp/pf3.log 2>&1 &
sleep 2; curl -s http://localhost:8085 | grep VERSION; kill %1 2>/dev/null; wait 2>/dev/null
kubectl rollout history deployment/app-rolling

kubectl rollout undo deployment/app-rolling
kubectl rollout status deployment/app-rolling --timeout=90s
kubectl get pods -l app=app-rolling --show-labels

kubectl delete -f rolling-update/service.yaml -f rolling-update/deployment-v1.yaml
