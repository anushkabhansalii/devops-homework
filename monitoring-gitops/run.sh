#!/bin/bash
# Monitoring, Observability & GitOps homework (Session 20).
#   ./run.sh monitoring   kube-prometheus-stack + demo app + metrics/logs/alerts/dashboards
#   ./run.sh gitops       Argo CD + GitOps workflow (commits and pushes changes to 03-gitops/app!)
#   ./run.sh cleanup
# Requires minikube, helm, jq, curl. Set SHOT_DIR=/some/dir to save each step's output to a file.
set -e
cd "$(dirname "$0")"

CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
say()  { echo "$*" | tee -a "$CUR"; }
waitfor() { for _ in $(seq 1 ${3:-90}); do bash -c "$1" 2>/dev/null | grep -q -E "$2" && return 0; sleep 5; done; echo "timed out waiting for: $1 =~ $2"; }
PF_PIDS=()
pf() { kubectl port-forward -n "$1" "svc/$2" "$3" >/dev/null 2>&1 & PF_PIDS+=($!); sleep 3; }
trap 'kill ${PF_PIDS[@]} 2>/dev/null || true' EXIT
P="./01-monitoring/promql.sh"

monitoring() {
  shot 01-install-stack
  run helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  run "helm upgrade --install kps prometheus-community/kube-prometheus-stack --version 92.1.0 -n monitoring --create-namespace -f 01-monitoring/values-kube-prometheus-stack.yaml --wait --timeout 15m | grep -E 'NAME|STATUS|REVISION|CHART'"
  run kubectl get pods -n monitoring
  pf monitoring prometheus-operated 9090:9090
  pf monitoring alertmanager-operated 9093:9093
  pf monitoring kps-grafana 3000:80

  shot 02-demo-app
  run kubectl apply -f 01-monitoring/demo-app.yaml -f 01-monitoring/alerts.yaml
  kubectl -n monitoring-demo rollout status deploy/demo-app --timeout=180s >/dev/null
  run kubectl get pods,svc,servicemonitor,prometheusrule -n monitoring-demo
  run "kubectl -n monitoring-demo exec deploy/demo-app -c nginx -- wget -qO- localhost:9113/metrics | grep -E '^nginx_'"

  shot 03-targets
  waitfor "curl -s localhost:9090/api/v1/targets" 'monitoring-demo/demo-app' 60
  waitfor "$P 'count(up{namespace=\"monitoring-demo\"}) == 2 and count(up{namespace=\"monitoring-demo\"} == 1) == 2'" ' 2$' 60
  waitfor "$P 'count(rate(container_cpu_usage_seconds_total{namespace=\"monitoring-demo\",container=\"nginx\"}[1m]))'" ' 2$' 60
  run "curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | [.labels.job, .scrapeUrl, .health] | @tsv' | sort | column -t"
  run "$P 'up{namespace=\"monitoring-demo\"}'"

  waitfor "$P 'sum(rate(nginx_http_requests_total{namespace=\"monitoring-demo\"}[1m]))'" '[0-9]' 30
  shot 04-metrics-baseline
  say "# --- CPU (cores) per pod ---"
  run "$P 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"monitoring-demo\",container=\"nginx\"}[1m]))'"
  say "# --- memory working set (MiB) per pod ---"
  run "$P 'sum by (pod) (container_memory_working_set_bytes{namespace=\"monitoring-demo\",container=\"nginx\"}) / 1024 / 1024'"
  say "# --- request rate (req/s) ---"
  run "$P 'sum(rate(nginx_http_requests_total{namespace=\"monitoring-demo\"}[1m]))'"
  say "# --- application health ---"
  run "$P 'kube_deployment_status_replicas_available{namespace=\"monitoring-demo\"}'"
  run "$P 'nginx_up{namespace=\"monitoring-demo\"}'"

  shot 05-load-alerts
  run kubectl apply -f 01-monitoring/load-generator.yaml
  kubectl -n monitoring-demo rollout status deploy/load-generator --timeout=120s >/dev/null
  waitfor "curl -s localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.state==\"firing\") | .labels.alertname'" 'DemoAppHighCPU' 60
  waitfor "curl -s localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.state==\"firing\") | .labels.alertname'" 'DemoAppHighRequestRate' 30
  say "# --- under load: CPU (cores), memory (MiB), request rate ---"
  run "$P 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"monitoring-demo\",container=\"nginx\"}[1m]))'"
  run "$P 'sum by (pod) (container_memory_working_set_bytes{namespace=\"monitoring-demo\",container=\"nginx\"}) / 1024 / 1024'"
  run "$P 'sum(rate(nginx_http_requests_total{namespace=\"monitoring-demo\"}[1m]))'"
  run "curl -s localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.labels.namespace==\"monitoring-demo\" or (.labels.alertname|startswith(\"DemoApp\"))) | [.labels.alertname, .state, (.labels.pod // \"-\"), .annotations.summary] | @tsv' | column -t -s \$'\t'"

  shot 06-alertmanager
  waitfor "curl -s localhost:9093/api/v2/alerts" 'DemoAppHighCPU' 30
  run "curl -s localhost:9093/api/v2/alerts | jq -r '.[] | select(.labels.alertname|startswith(\"DemoApp\")) | [.labels.alertname, .labels.severity, .status.state, (.labels.pod // \"-\"), .startsAt[0:19]] | @tsv' | column -t -s \$'\t'"

  shot 07-grafana
  run "curl -s localhost:3000/api/health | jq ."
  run "curl -s 'localhost:3000/api/search?query=Compute%20Resources' | jq -r '.[] | [.uid, .title] | @tsv' | column -t -s \$'\t'"
  if [ -n "$SHOT_DIR" ]; then
    UID_NS=$(curl -s 'localhost:3000/api/search?query=Compute%20Resources%20/%20Namespace%20(Pods)' | jq -r '.[0].uid')
    sleep 60   # let the dashboard collect a few minutes of load history
    TMPP=$(mktemp -d)
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
      --user-data-dir="$TMPP" --window-size=1600,1250 --virtual-time-budget=20000 \
      --screenshot="$SHOT_DIR/grafana-dashboard.png" \
      "http://localhost:3000/d/$UID_NS/?orgId=1&var-datasource=prometheus&var-cluster=&var-namespace=monitoring-demo&from=now-15m&to=now&refresh=&kiosk" >/dev/null 2>&1 &
    CHROME=$!; sleep 40; kill $CHROME 2>/dev/null || true   # headless Chrome sometimes never exits after writing the file
    rm -rf "$TMPP"
  fi

  shot 08-logs
  run "kubectl -n monitoring-demo logs -l app=demo-app -c nginx --tail=3 --prefix"
  run "kubectl -n monitoring-demo logs -l app=demo-app -c nginx --tail=2000 | awk '{print \$9}' | sort | uniq -c | sort -rn | head -5"
  run "kubectl -n monitoring-demo logs deploy/demo-app -c exporter | head -5"

  shot 09-health-down
  run kubectl delete -f 01-monitoring/load-generator.yaml
  run kubectl -n monitoring-demo scale deploy/demo-app --replicas=0
  waitfor "curl -s localhost:9093/api/v2/alerts" 'DemoAppDown' 60
  run "$P 'kube_deployment_status_replicas_available{namespace=\"monitoring-demo\"}'"
  run "curl -s localhost:9093/api/v2/alerts | jq -r '.[] | select(.labels.alertname==\"DemoAppDown\") | [.labels.alertname, .labels.severity, .status.state, .annotations.description] | @tsv' | column -t -s \$'\t'"

  shot 10-health-recovered
  run kubectl -n monitoring-demo scale deploy/demo-app --replicas=2
  kubectl -n monitoring-demo rollout status deploy/demo-app --timeout=120s >/dev/null
  waitfor "curl -s localhost:9090/api/v1/alerts | jq -r '[.data.alerts[] | select(.labels.alertname==\"DemoAppDown\")] | length'" '^0$' 40
  run "$P 'kube_deployment_status_replicas_available{namespace=\"monitoring-demo\"}'"
  run "curl -s localhost:9090/api/v1/alerts | jq -r '[.data.alerts[] | select(.labels.alertname==\"DemoAppDown\")] | length' | sed 's/^/DemoAppDown alerts still active: /'"
}

gitops() {
  APP=03-gitops/app/deployment.yaml
  refresh() { kubectl -n argocd annotate application session20-gitops argocd.argoproj.io/refresh=normal --overwrite >/dev/null; }
  ARGO_STATUS="kubectl -n argocd get application session20-gitops -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}'"

  shot 11-argocd-install
  run "kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -"
  run "kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | tail -3"
  kubectl -n argocd rollout status deploy/argocd-server --timeout=300s >/dev/null
  kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s >/dev/null
  kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s >/dev/null
  run kubectl get pods -n argocd
  run "kubectl -n argocd get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"

  shot 12-argocd-app-sync
  run cat 03-gitops/argocd-application.yaml
  run kubectl apply -f 03-gitops/argocd-application.yaml
  waitfor "$ARGO_STATUS" '^Synced Healthy' 60
  run kubectl -n argocd get applications
  run kubectl get deploy,pods,svc -n session20-gitops

  shot 13-git-change
  sed -i '' 's/  replicas: 2/  replicas: 3/; s/image: nginx:1.27-alpine/image: nginx:1.28-alpine/' $APP
  run git diff -- $APP
  run "git add $APP && git commit -q -m 'GitOps demo: scale gitops-web to 3 replicas and upgrade nginx to 1.28' && git push -q && git log --oneline -1"
  NEW=$(git rev-parse HEAD)
  refresh
  waitfor "$ARGO_STATUS" "^Synced Healthy $NEW" 60
  kubectl -n session20-gitops rollout status deploy/gitops-web --timeout=180s >/dev/null
  run "kubectl -n argocd get application session20-gitops -o jsonpath='{.status.sync.status}{\" / \"}{.status.health.status}{\"  revision=\"}{.status.sync.revision}{\"\\n\"}'"
  run kubectl get pods -n session20-gitops -o wide
  run "kubectl -n session20-gitops get deploy gitops-web -o jsonpath='{.spec.replicas}{\" replicas, image \"}{.spec.template.spec.containers[0].image}{\"\\n\"}'"

  shot 14-self-heal
  say "# someone 'hot-fixes' production by hand, bypassing Git:"
  run kubectl -n session20-gitops scale deploy/gitops-web --replicas=6
  run "kubectl -n session20-gitops get deploy gitops-web"
  sleep 15
  say "# 15 seconds later - Argo CD detected the drift and put Git's value back:"
  run "kubectl -n session20-gitops get deploy gitops-web"
  run kubectl -n session20-gitops delete service gitops-web
  waitfor "kubectl -n session20-gitops get svc gitops-web" 'gitops-web' 20
  run kubectl -n session20-gitops get svc gitops-web
  run "kubectl -n argocd get application session20-gitops -o jsonpath='{range .status.history[*]}{.id}{\"  \"}{.revision}{\"  \"}{.deployedAt}{\"\\n\"}{end}'"

  shot 15-git-revert
  run "git revert --no-edit HEAD >/dev/null && git push -q && git log --oneline -3"
  NEW=$(git rev-parse HEAD)
  refresh
  waitfor "$ARGO_STATUS" "^Synced Healthy $NEW" 60
  kubectl -n session20-gitops rollout status deploy/gitops-web --timeout=180s >/dev/null
  sleep 5
  run "kubectl -n session20-gitops get deploy gitops-web -o jsonpath='{.spec.replicas}{\" replicas, image \"}{.spec.template.spec.containers[0].image}{\"\\n\"}'"
  run kubectl get pods -n session20-gitops
  run "kubectl -n argocd get application session20-gitops -o jsonpath='{range .status.history[*]}{.id}{\"  \"}{.revision}{\"  \"}{.deployedAt}{\"\\n\"}{end}'"
}

cleanup() {
  kubectl delete -f 03-gitops/argocd-application.yaml --ignore-not-found
  kubectl delete namespace session20-gitops argocd --ignore-not-found
  kubectl delete namespace monitoring-demo --ignore-not-found
  helm uninstall kps -n monitoring --ignore-not-found 2>/dev/null || true
  kubectl delete namespace monitoring --ignore-not-found
}

case "${1:-}" in
  monitoring) monitoring ;;
  gitops) gitops ;;
  cleanup) cleanup ;;
  *) echo "usage: $0 monitoring|gitops|cleanup"; exit 1 ;;
esac
