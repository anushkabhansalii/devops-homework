#!/bin/bash
# Helm class exercises (in addition to ../run.sh): bitnami chart install/uninstall, repo remove,
# lint catching a typo, upgrade vs upgrade --install, and the guestbook mini project.
set -e
cd "$(dirname "$0")"
CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }

shot 16-bitnami-install
run helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
run helm repo update bitnami
run "helm install my-nginx bitnami/nginx --set service.type=ClusterIP | grep -E 'NAME|STATUS|REVISION|CHART'"
run helm list
run "kubectl get deploy,svc -l app.kubernetes.io/instance=my-nginx"

shot 17-bitnami-uninstall-repo-remove
run helm uninstall my-nginx
run helm list
run "kubectl get all -l app.kubernetes.io/instance=my-nginx"
run helm repo remove bitnami
run helm repo list

shot 18-lint-catches-typo
rm -rf /tmp/lint-demo && cp -r simple-chart /tmp/lint-demo
run helm lint simple-chart
sed -i '' 's/^  replicas:/replicas:/' /tmp/lint-demo/templates/deployment.yaml
run "grep -n -B1 -A1 '^replicas:' /tmp/lint-demo/templates/deployment.yaml"
run "helm lint /tmp/lint-demo; true"

shot 19-upgrade-vs-install
run "helm upgrade my-app simple-chart; true"
run "helm upgrade --install my-app simple-chart | grep -E 'STATUS|REVISION'"
run "helm upgrade --install my-app simple-chart --set replicaCount=3 | grep -E 'STATUS|REVISION'"
run "helm install my-app simple-chart; true"
run helm history my-app
run helm uninstall my-app

shot 20-guestbook-mini-project
run helm lint guestbook-chart
run "helm install guestbook guestbook-chart | grep -E 'NAME|STATUS|REVISION'"
kubectl rollout status deploy/guestbook-app --timeout=120s >/dev/null
run helm list
run helm status guestbook
run "kubectl get deploy,svc,configmap | grep -E 'NAME|guestbook'"
run "kubectl exec deploy/guestbook-app -- env | grep -E 'welcome|appName'"
run helm uninstall guestbook
