#!/bin/bash
# Final DevOps project (Session 21) - TaskBoard. Everything that runs on my machine:
#   ./run.sh local         docker compose: build, run, test, screenshot, tear down
#   ./run.sh terraform     VPC + EKS with Terraform (against the local Moto AWS emulator)
#   ./run.sh deploy        build images, Helm install on minikube, verify app/storage/probes/monitoring
#   ./run.sh troubleshoot  break the release in 4 ways, then diagnose and fix each one
#   ./run.sh gitops        Argo CD deploys the production release from Git (images built by CI)
#   ./run.sh cleanup
# Set SHOT_DIR=/some/dir to save each step's output to a file (used for the screenshots).
set -e
cd "$(dirname "$0")"

CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
say()  { echo "$*" | tee -a "$CUR"; }
waitfor() { for _ in $(seq 1 ${3:-60}); do bash -c "$1" 2>/dev/null | grep -q -E "$2" && return 0; sleep 5; done; echo "timed out waiting for: $1 =~ $2"; }
PF_PIDS=()
pf() { kubectl port-forward -n "$1" "svc/$2" "$3" >/dev/null 2>&1 & PF_PIDS+=($!); sleep 3; }
trap 'kill ${PF_PIDS[@]} 2>/dev/null || true' EXIT
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
screenshot() {  # url outfile [width,height]
  [ -n "$SHOT_DIR" ] && [ -x "$CHROME" ] || return 0
  local t; t=$(mktemp -d)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$t" --window-size="${3:-1440,900}" \
    --virtual-time-budget=15000 --screenshot="$SHOT_DIR/$2" "$1" >/dev/null 2>&1 & local c=$!
  sleep 25; kill $c 2>/dev/null || true; rm -rf "$t"
}
COMPOSE="docker compose -f docker/docker-compose.yml"
API="curl -s -H 'Host: taskboard.local' localhost:8090"   # through the NGINX Ingress controller

local_stack() {
  shot 01-compose-up
  run "$COMPOSE up -d --build 2>&1 | grep -E 'Built|Started|Healthy'"
  sleep 5
  shot 02-compose-test
  run "$COMPOSE ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
  run "$COMPOSE logs backend | grep -E 'alembic|Started|Uvicorn' | head -4"
  run "curl -s localhost:3000/api/info"
  run "curl -s -X POST localhost:3000/api/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Write final README\",\"priority\":\"HIGH\",\"assignee\":\"Anushka\"}'"
  run "curl -s localhost:3000/api/tasks/stats"
  run "$COMPOSE exec backend id"
  for t in 'Set up GitHub Actions pipeline|HIGH|DONE' 'Add Trivy image scan|HIGH|DONE' 'Terraform VPC + EKS|MEDIUM|IN_PROGRESS' 'Helm chart for TaskBoard|MEDIUM|IN_PROGRESS' 'Grafana dashboard|LOW|TODO'; do
    IFS='|' read -r ti pr st <<< "$t"
    curl -s -X POST localhost:3000/api/tasks -H 'Content-Type: application/json' -d "{\"title\":\"$ti\",\"priority\":\"$pr\",\"status\":\"$st\",\"assignee\":\"Anushka\"}" >/dev/null
  done
  screenshot http://localhost:3000/ taskboard-ui-local.png
  $COMPOSE down -v >/dev/null 2>&1
}

terraform_part() {
  export TF_IN_AUTOMATION=1 TF_CLI_ARGS="-no-color"
  docker start moto >/dev/null 2>&1 || docker run -d --name moto -p 4566:5000 -e MOTO_IAM_LOAD_MANAGED_POLICIES=true motoserver/moto:latest >/dev/null
  sleep 2
  cd terraform
  shot 03-terraform-plan
  run "terraform init | grep -E 'Installed|initialized'"
  run terraform fmt -check -recursive
  run terraform validate
  run "terraform plan -out=tfplan | grep -E '^  # |Plan:'"
  shot 04-terraform-apply
  run "terraform apply tfplan | grep -E 'aws_eks|aws_nat|Apply complete|^[a-z_]+ = '"
  run "terraform state list | sed 's/\\[.*//' | sort | uniq -c"
  shot 05-terraform-destroy
  run "terraform destroy -auto-approve | grep -E 'Destroy complete'"
  rm -f tfplan
  cd ..
}

deploy() {
  shot 06-build-images
  run "docker build -q -f docker/backend.Dockerfile --build-arg APP_VERSION=dev-local -t taskboard-backend:dev application/backend"
  run "docker build -q -f docker/frontend.Dockerfile -t taskboard-frontend:dev application/frontend"
  run minikube image load taskboard-backend:dev taskboard-frontend:dev
  run "minikube image ls | grep taskboard"

  shot 07-helm-install
  run bash gitops/create-db-secret.sh taskboard
  run helm lint helm/taskboard -f helm/taskboard/values-dev.yaml
  run "helm upgrade --install taskboard helm/taskboard -n taskboard --create-namespace -f helm/taskboard/values-dev.yaml --wait --timeout 5m | grep -E 'NAME|STATUS|REVISION'"
  run kubectl -n taskboard get pods,svc,ingress,pvc

  shot 08-k8s-objects
  run "kubectl -n taskboard get configmap taskboard-config -o jsonpath='{.data}' | jq ."
  run "kubectl -n taskboard get secret taskboard-db -o jsonpath='{.data}' | jq 'map_values(\"<base64 hidden>\")'"
  run "kubectl -n taskboard get pod -l app=taskboard-backend -o jsonpath='{.items[0].spec.initContainers[0].name}{\" -> \"}{.items[0].spec.containers[0].name}{\"\\n\"}'"
  run "kubectl -n taskboard logs deploy/taskboard-backend -c wait-for-db"
  run "kubectl -n taskboard describe pod -l app=taskboard-backend | grep -E '^ +(Startup|Readiness|Liveness):'"
  run "kubectl -n taskboard exec deploy/taskboard-backend -- id"

  shot 09-ingress-crud
  pf ingress-nginx ingress-nginx-controller 8090:80
  run "$API/api/info"
  run "$API -X POST localhost:8090/api/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Deployed on Kubernetes\",\"priority\":\"HIGH\",\"assignee\":\"Anushka\"}'"
  run "$API -X PUT localhost:8090/api/tasks/1 -H 'Content-Type: application/json' -d '{\"status\":\"DONE\"}' | jq -c '{id,title,status}'"
  run "$API/api/tasks/stats"
  run "$API/ | grep -o '<title>.*</title>'"

  shot 10-storage-persistence
  run "kubectl -n taskboard get pvc,pv | grep -E 'NAME|taskboard'"
  run kubectl -n taskboard delete pod taskboard-postgres-0
  kubectl -n taskboard wait --for=condition=Ready pod/taskboard-postgres-0 --timeout=180s >/dev/null
  sleep 5
  run kubectl -n taskboard get pod taskboard-postgres-0
  run "$API/api/tasks | jq -c '.[] | {id,title,status}'"

  shot 11-monitoring
  pf monitoring prometheus-operated 9090:9090
  waitfor "curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.namespace==\"taskboard\") | .health'" '^up' 40
  for _ in $(seq 1 60); do $API/api/tasks >/dev/null; $API/api/tasks/stats >/dev/null; $API/api/tasks/999 >/dev/null; done
  sleep 35
  run "curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.namespace==\"taskboard\") | [.labels.job, .scrapeUrl, .health] | @tsv'"
  run "../monitoring-gitops/01-monitoring/promql.sh 'sum by (handler, status) (rate(http_requests_total{namespace=\"taskboard\",handler!=\"/metrics\"}[1m]))' | sort"
  run "curl -s localhost:9090/api/v1/rules | jq -r '.data.groups[] | select(.name==\"taskboard.rules\") | .rules[] | [.name, .health, .state] | @tsv'"
  pf monitoring kps-grafana 3000:80
  run "curl -s 'localhost:3000/api/search?query=TaskBoard' | jq -r '.[] | [.uid, .title] | @tsv'"
  for _ in $(seq 1 200); do $API/api/tasks >/dev/null; done
  screenshot "http://localhost:3000/d/taskboard/?orgId=1&var-namespace=taskboard&from=now-15m&to=now&kiosk" grafana-taskboard.png 1600,1150
}

troubleshoot() {
  pf ingress-nginx ingress-nginx-controller 8090:80
  BROKEN="-f helm/taskboard/values-dev.yaml -f kubernetes/troubleshooting/broken-values.yaml"

  shot 12-ts-break
  say "# a bad release goes out: helm upgrade with broken values + an out-of-band DB password 'rotation'"
  run "grep -v '^#' kubernetes/troubleshooting/broken-values.yaml"
  run "helm upgrade taskboard helm/taskboard -n taskboard $BROKEN | grep -E 'STATUS|REVISION'"
  run bash kubernetes/troubleshooting/break-db-secret.sh
  sleep 60

  shot 13-ts-identify
  say "# 1. IDENTIFY - users report the site is down"
  run "$API/ -o /dev/null -w 'GET http://taskboard.local/          -> HTTP %{http_code}\\n'"
  run "$API/api/info -o /dev/null -w 'GET http://taskboard.local/api/info  -> HTTP %{http_code}\\n'"
  run kubectl -n taskboard get pods
  run kubectl -n taskboard get ingress

  shot 14-ts-issue1-ingress
  say "# ISSUE 1 - every URL returns 404 from the ingress controller"
  run "kubectl -n taskboard get ingress taskboard -o jsonpath='{.spec.rules[0].host}{\"\\n\"}'"
  say "# root cause: Ingress host is 'taskboard.locl' (typo) -> requests for taskboard.local match no rule -> default backend 404"
  run "helm upgrade taskboard helm/taskboard -n taskboard $BROKEN --set ingress.host=taskboard.local | grep REVISION"
  run kubectl -n taskboard get ingress taskboard

  shot 15-ts-issue2-image
  say "# ISSUE 2 - frontend pod never starts"
  run "kubectl -n taskboard get pods -l app=taskboard-frontend"
  run "kubectl -n taskboard describe pod -l app=taskboard-frontend | grep -E 'Image:|Warning' | sed 's/^ *//' | sort -u | cut -c1-170"
  run "minikube image ls | grep taskboard-frontend"
  say "# root cause: image tag 'dev-typo' does not exist (pullPolicy Never -> ErrImageNeverPull; from a registry it would be ImagePullBackOff)"
  run "helm upgrade taskboard helm/taskboard -n taskboard $BROKEN --set ingress.host=taskboard.local --set frontend.image.tag=dev | grep REVISION"
  kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=180s >/dev/null
  run "kubectl -n taskboard get pods -l app=taskboard-frontend"

  shot 16-ts-issue3-db-secret
  say "# ISSUE 3 - backend in CrashLoopBackOff"
  run "kubectl -n taskboard get pods -l app=taskboard-backend"
  run "kubectl -n taskboard logs deploy/taskboard-backend --previous 2>/dev/null | grep -E 'OperationalError' | tail -1 | cut -c1-200"
  say "# root cause: the Secret now holds a new password, but PostgreSQL still has the old one - the rotation was only half done"
  say "# fix: finish the rotation - set the DB user's password to the value in the Secret, then restart the API"
  say "\$ kubectl -n taskboard exec taskboard-postgres-0 -- psql -U taskboard -d taskboard -c \"ALTER USER taskboard PASSWORD '<value from secret/taskboard-db>'\""
  NEWPW=$(kubectl -n taskboard get secret taskboard-db -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
  kubectl -n taskboard exec taskboard-postgres-0 -- psql -U taskboard -d taskboard -c "ALTER USER taskboard PASSWORD '$NEWPW'" 2>&1 | tee -a "$CUR"
  echo | tee -a "$CUR"
  run kubectl -n taskboard rollout restart deployment/taskboard-backend
  sleep 50

  shot 17-ts-issue4-readiness
  say "# ISSUE 4 - backend Running, no more crashes, but never Ready -> /api still fails"
  run "kubectl -n taskboard get pods -l app=taskboard-backend"
  run "kubectl -n taskboard get endpointslices -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}  ready={.conditions.ready}{\"\\n\"}{end}'"
  run "kubectl -n taskboard describe pod -l app=taskboard-backend | grep 'Readiness probe failed' | tail -1 | sed 's/^ *//' | cut -c1-170"
  run "$API/api/info -o /dev/null -w 'GET /api/info -> HTTP %{http_code}\\n'"
  say "# root cause: readinessProbe path /readyz does not exist (404) - the API's readiness endpoint is /ready"
  run "helm upgrade taskboard helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml | grep REVISION"
  kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=180s >/dev/null

  shot 18-ts-verify
  say "# VERIFY"
  run kubectl -n taskboard get pods
  run "$API/ -o /dev/null -w 'GET http://taskboard.local/      -> HTTP %{http_code}\\n'"
  run "$API/api/info"
  run "$API/api/tasks/stats"
  run "helm history taskboard -n taskboard | tail -6"
}

gitops() {
  shot 19-gitops-setup
  run bash gitops/create-db-secret.sh taskboard-prod
  run kubectl apply -f gitops/argocd-application.yaml
  waitfor "kubectl -n argocd get application taskboard-prod -o jsonpath='{.status.sync.status} {.status.health.status}'" '^Synced Healthy' 60
  run kubectl -n argocd get application taskboard-prod
  run "kubectl -n argocd get application taskboard-prod -o jsonpath='{.status.sync.revision}{\"\\n\"}{.status.summary.images}{\"\\n\"}'"
  run kubectl -n taskboard-prod get pods,svc,ingress,hpa,pvc

  shot 20-gitops-verify
  pf ingress-nginx ingress-nginx-controller 8090:80
  run "curl -s -H 'Host: taskboard-prod.local' localhost:8090/api/info"
  run "git log --oneline -3 -- helm/taskboard/values-prod.yaml"
  run "grep -n 'tag:' helm/taskboard/values-prod.yaml"
}

cleanup() {
  kubectl delete -f gitops/argocd-application.yaml --ignore-not-found
  kubectl delete namespace taskboard-prod --ignore-not-found
  helm uninstall taskboard -n taskboard 2>/dev/null || true
  kubectl delete namespace taskboard --ignore-not-found
  $COMPOSE down -v 2>/dev/null || true
}

case "${1:-}" in
  local) local_stack ;;
  terraform) terraform_part ;;
  deploy) deploy ;;
  troubleshoot) troubleshoot ;;
  gitops) gitops ;;
  cleanup) cleanup ;;
  *) echo "usage: $0 local|terraform|deploy|troubleshoot|gitops|cleanup"; exit 1 ;;
esac
