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
  sleep 25; kill $c 2>/dev/null || true; sleep 2; rm -rf "$t" 2>/dev/null || true
}
COMPOSE="docker compose -f docker/docker-compose.yml"
API="curl -s -H 'Host: taskboard.local'"   # through the NGINX Ingress controller (port-forwarded to :8090)
U=localhost:8090
api() { curl -s -o /dev/null -H "Host: taskboard.local" "$U$1"; }   # quiet request, for generating traffic

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
  # minikube's hostpath provisioner leaves PV data on the node after the PVC/PV are deleted; a stale
  # database would still have an OLD password while create-db-secret.sh generates a NEW one
  if minikube ssh -- "sudo test -d /tmp/hostpath-provisioner/taskboard" 2>/dev/null && ! kubectl get ns taskboard >/dev/null 2>&1; then
    echo "stale PostgreSQL data from a previous install found on the node - run ./run.sh cleanup first"; exit 1
  fi
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
  waitfor "curl -s -o /dev/null -w '%{http_code}' -H 'Host: taskboard.local' $U/api/info" '^200' 30
  run kubectl -n taskboard get ingress taskboard
  run "$API $U/api/info"
  run "$API -X POST $U/api/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Deployed on Kubernetes\",\"priority\":\"HIGH\",\"assignee\":\"Anushka\"}'"
  run "$API -X PUT $U/api/tasks/1 -H 'Content-Type: application/json' -d '{\"status\":\"DONE\"}' | jq -c '{id,title,status}'"
  run "$API $U/api/tasks/stats"
  run "$API $U/ | grep -o '<title>.*</title>'"

  shot 10-storage-persistence
  run "kubectl -n taskboard get pvc,pv | grep -E 'NAME|taskboard'"
  run kubectl -n taskboard delete pod taskboard-postgres-0
  kubectl -n taskboard wait --for=condition=Ready pod/taskboard-postgres-0 --timeout=180s >/dev/null
  sleep 5
  run kubectl -n taskboard get pod taskboard-postgres-0
  run "$API $U/api/tasks | jq -c '.[] | {id,title,status}'"

  shot 11-monitoring
  pf monitoring prometheus-operated 9090:9090
  waitfor "curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.namespace==\"taskboard\") | .health'" '^up' 40
  for _ in $(seq 1 60); do api /api/tasks; api /api/tasks/stats; api /api/tasks/999; done
  sleep 35
  run "curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.namespace==\"taskboard\") | [.labels.job, .scrapeUrl, .health] | @tsv'"
  run "curl -s localhost:9090/api/v1/query --data-urlencode 'query=sum by (handler, method, status) (rate(http_requests_total{namespace=\"taskboard\",handler!=\"/metrics\"}[1m]))' | jq -r '.data.result[] | [.metric.method, .metric.handler, .metric.status, (.value[1]|tonumber*100|round/100|tostring)+\" req/s\"] | @tsv' | sort | column -t"
  run "curl -s localhost:9090/api/v1/rules | jq -r '.data.groups[] | select(.name==\"taskboard.rules\") | .rules[] | [.name, .health, .state] | @tsv'"
  pf monitoring kps-grafana 3000:80
  waitfor "curl -s 'localhost:3000/api/search?query=TaskBoard'" 'taskboard' 24
  run "curl -s 'localhost:3000/api/search?query=TaskBoard' | jq -r '.[] | [.uid, .title] | @tsv'"
  for _ in $(seq 1 200); do api /api/tasks; api /api/tasks/stats; done
  screenshot "http://localhost:3000/d/taskboard/?orgId=1&var-namespace=taskboard&from=now-15m&to=now&kiosk" grafana-taskboard.png 1600,1150
}

troubleshoot() {
  BROKEN="-f helm/taskboard/values-dev.yaml -f kubernetes/troubleshooting/broken-values.yaml"
  ingress_ready() { kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s >/dev/null; }
  ensure_pf() { curl -s -o /dev/null -m 3 localhost:8090 || { pkill -f 'port-forward -n ingress-nginx' 2>/dev/null || true; pf ingress-nginx ingress-nginx-controller 8090:80; }; }
  newest() { kubectl -n taskboard get pods -l app=$1 --sort-by=.metadata.creationTimestamp -o name | tail -1; }
  export -f newest
  ingress_ready; ensure_pf

  shot 12-ts-break
  say "# a bad release goes out: helm upgrade with broken values + an out-of-band DB password 'rotation'"
  run "grep -v '^#' kubernetes/troubleshooting/broken-values.yaml"
  run "helm upgrade taskboard helm/taskboard -n taskboard $BROKEN | grep -E 'STATUS|REVISION'"
  run bash kubernetes/troubleshooting/break-db-secret.sh
  waitfor "kubectl -n taskboard get pods -l app=taskboard-frontend" 'ErrImageNeverPull' 36
  waitfor "kubectl -n taskboard get pods -l app=taskboard-backend" 'Error|CrashLoopBackOff' 36
  ensure_pf

  shot 13-ts-identify
  say "# 1. IDENTIFY - users report the site is down"
  run "$API $U/ -o /dev/null -w 'GET http://taskboard.local/          -> HTTP %{http_code}\\n'"
  run "$API $U/api/info -o /dev/null -w 'GET http://taskboard.local/api/info  -> HTTP %{http_code}\\n'"
  run kubectl -n taskboard get pods
  run kubectl -n taskboard get ingress
  say "# note: the OLD backend/frontend pods are still Running - the rolling update never removes ready pods"
  say "# while the new ones fail, so the pods are not what users are hitting. Start with the 404s."

  shot 14-ts-issue1-ingress
  say "# ISSUE 1 - every URL returns 404 from the ingress controller"
  run "kubectl -n taskboard get ingress taskboard -o jsonpath='{.spec.rules[0].host}{\"\\n\"}'"
  say "# root cause: Ingress host is 'taskboard.locl' (typo) -> requests for taskboard.local match no rule -> default backend 404"
  ingress_ready
  run "helm upgrade taskboard helm/taskboard -n taskboard $BROKEN --set ingress.host=taskboard.local | grep -E 'REVISION|Error'"
  run kubectl -n taskboard get ingress taskboard
  ensure_pf
  waitfor "$API $U/ -o /dev/null -w '%{http_code}'" '^200' 12
  run "$API $U/ -o /dev/null -w 'GET http://taskboard.local/  -> HTTP %{http_code}\\n'"

  shot 15-ts-issue2-image
  say "# ISSUE 2 - new frontend pod never starts"
  run "kubectl -n taskboard get pods -l app=taskboard-frontend"
  run "kubectl -n taskboard describe \$(newest taskboard-frontend) | grep -E 'Image:|Warning' | sed 's/^ *//' | cut -c1-170"
  run "minikube image ls | grep taskboard-frontend"
  say "# root cause: image tag 'dev-typo' does not exist (pullPolicy Never -> ErrImageNeverPull; from a registry it would be ImagePullBackOff)"
  ingress_ready
  run "helm upgrade taskboard helm/taskboard -n taskboard $BROKEN --set ingress.host=taskboard.local --set frontend.image.tag=dev | grep -E 'REVISION|Error'"
  kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=180s >/dev/null
  run "kubectl -n taskboard get pods -l app=taskboard-frontend"

  shot 16-ts-issue3-db-secret
  say "# ISSUE 3 - new backend pods keep crashing"
  run "kubectl -n taskboard get pods -l app=taskboard-backend"
  run "kubectl -n taskboard logs \$(newest taskboard-backend) --previous 2>/dev/null | grep -E 'OperationalError' | tail -1 | cut -c1-210"
  say "# root cause: the Secret now holds a new password, but PostgreSQL still has the old one - the rotation was only half done"
  say "# fix: finish the rotation - set the DB user's password to the value now in the Secret, then restart the API"
  say "\$ kubectl -n taskboard exec taskboard-postgres-0 -- psql -U taskboard -d taskboard -c \"ALTER USER taskboard PASSWORD '<value from secret/taskboard-db>'\""
  NEWPW=$(kubectl -n taskboard get secret taskboard-db -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
  kubectl -n taskboard exec taskboard-postgres-0 -- psql -U taskboard -d taskboard -c "ALTER USER taskboard PASSWORD '$NEWPW'" 2>&1 | tee -a "$CUR"
  unset NEWPW
  echo | tee -a "$CUR"
  run kubectl -n taskboard rollout restart deployment/taskboard-backend
  waitfor "kubectl -n taskboard get \$(newest taskboard-backend) -o jsonpath='{.status.phase}'" '^Running' 36
  waitfor "kubectl -n taskboard describe \$(newest taskboard-backend)" 'Readiness probe failed' 36

  shot 17-ts-issue4-readiness
  say "# ISSUE 4 - the new backend pod is Running, no more crashes, but never becomes Ready"
  run "kubectl -n taskboard get pods -l app=taskboard-backend"
  run "kubectl -n taskboard get endpointslices -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}  ready={.conditions.ready}{\"\\n\"}{end}'"
  run "kubectl -n taskboard describe \$(newest taskboard-backend) | grep 'Readiness probe failed' | tail -1 | sed 's/^ *//' | cut -c1-170"
  run "kubectl -n taskboard exec \$(newest taskboard-backend) -- python -c \"import urllib.request as u; print(u.urlopen('http://localhost:8000/ready').read())\""
  say "# root cause: readinessProbe path /readyz does not exist (404) - the API's readiness endpoint is /ready (which works)"
  say "# the rollout is stuck: the old pod keeps serving, the new one never takes traffic"
  ingress_ready
  run "helm upgrade taskboard helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml | grep -E 'REVISION|Error'"
  kubectl -n taskboard rollout status deploy/taskboard-backend --timeout=180s >/dev/null
  kubectl -n taskboard rollout status deploy/taskboard-frontend --timeout=180s >/dev/null
  sleep 15; ensure_pf

  shot 18-ts-verify
  say "# VERIFY"
  run kubectl -n taskboard get pods
  run "kubectl -n taskboard get endpointslices -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}  ready={.conditions.ready}{\"\\n\"}{end}'"
  run "$API $U/ -o /dev/null -w 'GET http://taskboard.local/      -> HTTP %{http_code}\\n'"
  run "$API $U/api/info"
  run "$API $U/api/tasks | jq -c '.[] | {id,title,status}'"
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
  kubectl delete namespace taskboard --ignore-not-found --wait
  # the minikube hostpath provisioner does not wipe volume data when a PV is deleted - do it explicitly
  minikube ssh -- "sudo rm -rf /tmp/hostpath-provisioner/taskboard /tmp/hostpath-provisioner/taskboard-prod" 2>/dev/null || true
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
