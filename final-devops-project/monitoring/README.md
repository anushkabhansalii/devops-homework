# Monitoring — TaskBoard

Monitoring is shipped **with the application** in the Helm chart, so every environment that installs the chart is observed the same way. It plugs into the kube-prometheus-stack installed in session 20 ([`monitoring-gitops`](../../monitoring-gitops)).

| Piece | Where | What it does |
|---|---|---|
| `/metrics` endpoint | [`application/backend/app/main.py`](../application/backend/app/main.py) (`prometheus-fastapi-instrumentator`) | request counts by handler/method/status, latency histograms |
| `/health`, `/ready` | backend | liveness (process up) and readiness (DB reachable) |
| **ServiceMonitor** | [`helm/taskboard/templates/monitoring.yaml`](../helm/taskboard/templates/monitoring.yaml) | Prometheus scrapes the backend Service every 15s |
| **PrometheusRule** | same file | 4 alerts (below) |
| **Grafana dashboard** | [`helm/taskboard/dashboards/taskboard.json`](../helm/taskboard/dashboards/taskboard.json), shipped as a ConfigMap labelled `grafana_dashboard: "1"` | Grafana's sidecar loads it automatically |
| Pod CPU/memory, replicas, restarts | kubelet/cAdvisor + kube-state-metrics (from the stack) | used by the dashboard and alerts |

## Alerts
| Alert | Condition | Severity |
|---|---|---|
| `TaskBoardBackendDown` | no available backend replicas for 1 min | critical |
| `TaskBoardHighErrorRate` | > 5% of API requests return 5xx for 2 min | warning |
| `TaskBoardSlowRequests` | p95 latency > 500 ms for 5 min | warning |
| `TaskBoardPodRestarting` | a container restarted > 2 times in 10 min | warning |

## Dashboard panels — "TaskBoard - Application Overview"
Requests/s · error rate · p95 latency · backend pods ready · requests by endpoint · latency p50/p95 · CPU by pod · memory by pod · responses by status code.

## Useful PromQL
```promql
sum by (handler, status) (rate(http_requests_total{namespace="taskboard", handler!="/metrics"}[1m]))
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="taskboard"}[5m])))
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="taskboard", container!=""}[1m]))
kube_deployment_status_replicas_available{namespace="taskboard"}
```
Live output from my cluster is in the [project README](../README.md#monitoring).
