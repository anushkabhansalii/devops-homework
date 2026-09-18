#!/bin/bash
# Kubernetes Ingress, ConfigMaps & Secrets homework.
# Requires Docker Desktop running + minikube installed + minikube start already run.
# Usage: ./run.sh
set -e
cd "$(dirname "$0")"

echo "### 1. Enable the NGINX Ingress Controller ###"
minikube addons enable ingress
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=180s
kubectl get pods -n ingress-nginx

echo "### 2. ConfigMap: plain-text configuration ###"
kubectl apply -f configmap.yaml
kubectl get configmap yatri-app-config
kubectl describe configmap yatri-app-config
kubectl get configmap yatri-app-config -o jsonpath='{.data.ENVIRONMENT}'; echo

echo "### 3. The echo vs echo -n newline gotcha ###"
echo "-- wrong way (adds a trailing newline) --"
echo "mypassword" | base64
echo "-- correct way --"
echo -n "mypassword" | base64

echo "### 4. Secret: sensitive database credentials ###"
kubectl apply -f secret.yaml
kubectl get secret yatri-db-secret
kubectl describe secret yatri-db-secret
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode; echo

echo "### 5. Backend: inject ConfigMap + Secret as env vars ###"
kubectl apply -f backend.yaml
kubectl rollout status deployment/yatri-backend --timeout=90s
kubectl exec -it deployment/yatri-backend -- env | grep -E "ENVIRONMENT|LOG_LEVEL|DEFAULT_CURRENCY|POSTGRES"

echo "### 6. Frontend (both services stay ClusterIP -> need Ingress) ###"
kubectl apply -f frontend.yaml
kubectl rollout status deployment/yatri-frontend --timeout=90s
kubectl get svc yatri-frontend-service yatri-backend-service

echo "### 7. Ingress: one entry point, two path-based routes ###"
kubectl apply -f ingress.yaml
kubectl get ingress yatri-ingress
kubectl describe ingress yatri-ingress

echo "### 8. Test routing ###"
# NOTE: on macOS with the Docker driver, curling $(minikube ip) directly hangs/times out
# (this is the same limitation as NodePort in the previous lecture) -- 'minikube tunnel'
# or port-forwarding straight to the ingress controller service both work:
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8090:80 >/tmp/pfing.log 2>&1 &
sleep 3
curl -s -H "Host: yatri.local" http://localhost:8090/ | grep -i "<title>"
curl -s -H "Host: yatri.local" http://localhost:8090/api/
kill %1 2>/dev/null; wait 2>/dev/null

echo "### 9. ConfigMap live update -- env vars are only read at container start ###"
kubectl patch configmap yatri-app-config --type merge -p '{"data":{"ENVIRONMENT":"staging"}}'
echo "-- still old value until restart --"
kubectl exec -it deployment/yatri-backend -- env | grep ENVIRONMENT
kubectl rollout restart deployment/yatri-backend
kubectl rollout status deployment/yatri-backend --timeout=90s
echo "-- new value after restart --"
kubectl exec -it deployment/yatri-backend -- env | grep ENVIRONMENT
kubectl patch configmap yatri-app-config --type merge -p '{"data":{"ENVIRONMENT":"production"}}'

echo "### 10. Cleanup ###"
bash cleanup.sh
kubectl get all -l app=yatri-app
