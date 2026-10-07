#!/bin/bash
# Helm homework (Session 15).
# Requires Docker Desktop running + minikube started + helm (v3/v4) installed.
# Usage: ./run.sh            (set SHOT_DIR=/some/dir to also save each step's output to a file)
set -e
cd "$(dirname "$0")"

CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
waitfor() { for _ in $(seq 1 90); do bash -c "$1" 2>/dev/null | grep -q -E "$2" && return 0; sleep 2; done; echo "timed out waiting for: $1 =~ $2"; }

########################################################################
# TASK 1: Helm commands
########################################################################
shot 01-version-create
run helm version
rm -rf myapp
run helm create myapp
run "find myapp -type f | sort"
run "grep -n -E '^replicaCount|repository|tag:|^  type:|^  port:' myapp/values.yaml"

shot 02-lint-template
run helm lint ./myapp
run "helm template web ./myapp | grep -E '^kind:|^# Source|image:|replicas:'"

shot 03-install
run helm install web ./myapp
run kubectl rollout status deployment/web-myapp --timeout=120s
run helm list

shot 04-status-get
run helm status web
run helm get values web --all \| head -12
run "helm get manifest web | grep -E '^kind:|image:'"

shot 05-upgrade-history
run helm upgrade web ./myapp --set replicaCount=2 --set image.tag=1.27
run kubectl rollout status deployment/web-myapp --timeout=120s
run helm list
run helm history web
run helm get values web

shot 06-rollback-uninstall
run helm rollback web 1
run kubectl rollout status deployment/web-myapp --timeout=120s
run helm history web
run "kubectl get deploy web-myapp -o jsonpath='{.spec.replicas}{\" replicas, image \"}{.spec.template.spec.containers[0].image}{\"\\n\"}'"
run helm uninstall web
run helm list

shot 07-repo-search
run helm repo add bitnami https://charts.bitnami.com/bitnami
run helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
run helm repo update
run helm repo list
run helm search repo nginx \| head -5
run helm search repo prometheus-community/kube-prometheus-stack --versions \| head -4
run helm search hub redis --max-col-width 60 \| head -5

########################################################################
# TASK 2: complete rollback workflow
# Install -> Upgrade -> Verify -> Upgrade again -> Verify -> Rollback -> Verify
########################################################################
shot 08-rb-install
run helm install shop ./myapp --set image.tag=1.26
run kubectl rollout status deployment/shop-myapp --timeout=120s
run "kubectl get deploy shop-myapp -o jsonpath='{.spec.replicas}{\" replicas, image \"}{.spec.template.spec.containers[0].image}{\"\\n\"}'"

shot 09-rb-upgrade1-verify
run helm upgrade shop ./myapp --set image.tag=1.27 --set replicaCount=3
run kubectl rollout status deployment/shop-myapp --timeout=120s
run kubectl get pods -l app.kubernetes.io/instance=shop
run "kubectl get deploy shop-myapp -o jsonpath='{.spec.replicas}{\" replicas, image \"}{.spec.template.spec.containers[0].image}{\"\\n\"}'"
run helm history shop

shot 10-rb-upgrade2-broken
run helm upgrade shop ./myapp --set image.tag=9.99-does-not-exist --set replicaCount=3
waitfor "kubectl get pods -l app.kubernetes.io/instance=shop" "ErrImagePull|ImagePullBackOff"
sleep 5
run kubectl get pods -l app.kubernetes.io/instance=shop
run "kubectl get pods -l app.kubernetes.io/instance=shop -o jsonpath='{range .items[*]}{.metadata.name}{\"  \"}{.spec.containers[0].image}{\"\\n\"}{end}'"
run helm history shop

shot 11-rb-rollback-verify
run helm rollback shop 2
run kubectl rollout status deployment/shop-myapp --timeout=120s
run kubectl get pods -l app.kubernetes.io/instance=shop
run "kubectl get deploy shop-myapp -o jsonpath='{.spec.replicas}{\" replicas, image \"}{.spec.template.spec.containers[0].image}{\"\\n\"}'"
run helm history shop
run helm uninstall shop

########################################################################
# TASK 3: mini project -- Notes App chart
########################################################################
cd mini-project
shot 12-notes-lint-template
run "find notes-chart -type f | sort"
run helm lint notes-chart
run helm template notes-dev notes-chart

shot 13-notes-install-dev
run helm install notes-dev notes-chart
run kubectl rollout status deployment/notes-dev-deploy --timeout=120s
run "kubectl get deploy,pods,svc,configmap | grep -E 'NAME|notes-dev'"
run kubectl get svc notes-dev-svc
run "kubectl exec deploy/notes-dev-deploy -- env | grep -E 'APP_NAME|ENVIRONMENT'"
kubectl port-forward svc/notes-dev-svc 8095:80 >/dev/null 2>&1 &
PF=$!; sleep 3
run "curl -s http://localhost:8095 | grep -i '<title>'"
run "curl -sI http://localhost:8095 | grep -i '^server'"
kill $PF 2>/dev/null; wait $PF 2>/dev/null || true

shot 14-notes-upgrade-prod
run helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml
run kubectl rollout status deployment/notes-dev-deploy --timeout=120s
run kubectl get pods -l app=notes-dev
run "kubectl exec deploy/notes-dev-deploy -- env | grep -E 'APP_NAME|ENVIRONMENT'"
run "kubectl get deploy notes-dev-deploy -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"
run helm history notes-dev

shot 15-notes-rollback-uninstall
run helm rollback notes-dev 1
run kubectl rollout status deployment/notes-dev-deploy --timeout=120s
run kubectl get pods -l app=notes-dev
run "kubectl get deploy notes-dev-deploy -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"
run helm history notes-dev
run helm uninstall notes-dev
run helm list -A
cd ..
