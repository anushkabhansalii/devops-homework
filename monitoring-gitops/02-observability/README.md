# Observability — the three pillars

**Name:** Anushka Jain

## Monitoring vs observability
| | Monitoring | Observability |
|---|---|---|
| Question | "Is the system working?" | "**Why** is it not working?" |
| Built around | **known** failure modes — predefined dashboards and alerts (CPU > 80%, pod down, 5xx rate) | **unknown** failure modes — explore rich telemetry to ask new questions you didn't plan for |
| Output | green/red status, alerts | the ability to debug any state from the outside |
| Relationship | a *subset* of observability | monitoring + correlated metrics, logs and traces |

A system is *observable* when you can understand its internal state just from the data it emits — without SSH-ing in or shipping new code to add a print statement.

## Pillar 1 — Metrics
**Numeric measurements over time** (time series): a name, labels, and a value sampled every few seconds.
```text
nginx_http_requests_total{namespace="monitoring-demo", pod="demo-app-7c9…"}   48213    @ 1728371112
container_memory_working_set_bytes{pod="demo-app-7c9…", container="nginx"}     4.1e6
```
- **Types**: counter (only goes up — requests, errors), gauge (up/down — memory, queue length), histogram/summary (latency distribution → p95/p99)
- **Strengths**: cheap to store, fast to query and aggregate, ideal for **dashboards and alerting** and trends
- **Weakness**: tells you *that* something is wrong and roughly *where*, rarely *why*; high-cardinality labels (user IDs) explode storage
- **Golden signals / RED / USE**: latency, traffic, errors, saturation · Rate–Errors–Duration for services · Utilization–Saturation–Errors for resources
- In my demo: Prometheus scrapes kubelet/cAdvisor (CPU, memory), kube-state-metrics (replicas available, pod ready) and my app's exporter sidecar (`nginx_http_requests_total`, `nginx_connections_active`)

## Pillar 2 — Logs
**Timestamped, discrete event records** emitted by applications and infrastructure.
```text
10.244.0.31 - - [08/Oct/2026:02:31:07 +0000] "GET / HTTP/1.1" 200 615 "-" "Wget" "-"
{"level":"error","ts":"2026-10-08T02:31:07Z","msg":"db timeout","order_id":"o-981","trace_id":"4bf92f35…"}
```
- **Strengths**: full detail and context of individual events — exact error messages, stack traces, request parameters
- **Weakness**: expensive at volume, slow to aggregate, unstructured text is hard to query
- **Best practice**: structured (JSON) logs with consistent fields, log levels, **no secrets/PII**, include a `trace_id` to jump to the trace
- In Kubernetes: containers write to **stdout/stderr**; the kubelet stores them per container (`kubectl logs`), but they vanish with the pod → a node agent (Fluent Bit, Promtail/Grafana Alloy, Vector) ships them to a central store (Loki, Elasticsearch/OpenSearch, CloudWatch)

## Pillar 3 — Traces
A **trace** follows one request end-to-end across services; it is a tree of **spans** (one per operation) with start time, duration, attributes and parent/child links, all sharing a `trace_id` propagated in headers (W3C `traceparent`).
```text
trace 4bf92f35…  POST /checkout                               480 ms
├── api-gateway         auth                                   12 ms
├── order-service       create order                          410 ms
│   ├── postgres        INSERT orders                           9 ms
│   └── payment-service charge card                           385 ms   <- the slow part
│       └── HTTP POST   bank API                              370 ms
└── notification        enqueue email                           6 ms
```
- **Strengths**: shows *where* time goes and *which* service failed in a distributed (microservices) system — the only pillar that captures causality across services
- **Weakness**: needs instrumentation in every service; usually **sampled** (e.g. 10% + all errors) because of volume
- **Standard**: **OpenTelemetry** (SDKs + Collector) — vendor-neutral instrumentation for traces, metrics and logs

## How the pillars work together
```text
ALERT (metric):   error rate of checkout > 5% for 5 min          → something is wrong, in checkout
   │  click the spike on the Grafana panel
   ▼
TRACE (exemplar): slow/failed traces at that time                 → payment-service → bank API call times out
   │  follow trace_id
   ▼
LOGS:             payment-service logs with that trace_id         → "TLS handshake timeout to bank-api:443"
```
Metrics tell you **what & when**, traces tell you **where**, logs tell you **why**. Correlation via shared labels (`namespace`, `pod`, `service`) and IDs (`trace_id`) is what turns three data sources into observability.

## Why observability is required
- Modern systems are **distributed** (microservices, Kubernetes, managed cloud services): one user request touches many components; failures are partial and emergent
- Pods are **ephemeral** — restarted, rescheduled, autoscaled — you can't SSH into "the server" to look around
- Faster **MTTD / MTTR** (mean time to detect / resolve) and less guesswork during incidents
- Define and track **SLIs/SLOs** (e.g. 99.9% of requests < 300 ms) and error budgets
- Capacity planning and cost (right-size requests/limits from real usage — which also feeds the HPA from session 13)
- Verify deployments: canary analysis, compare error rate before/after a release
- Security & audit: unusual traffic, auth failures

## Common tools
| Purpose | Open source | Managed / commercial |
|---|---|---|
| Metrics collection + storage | **Prometheus**, VictoriaMetrics, Thanos / Mimir (long-term, HA) | Amazon Managed Prometheus, CloudWatch, Datadog, New Relic |
| Dashboards | **Grafana** | Grafana Cloud, Datadog, CloudWatch dashboards |
| Alerting | Prometheus rules + **Alertmanager** (routing, grouping, silencing → Slack/PagerDuty/email) | PagerDuty, Opsgenie, Datadog monitors |
| Logs | **Loki** + Promtail/Alloy, ELK/EFK (Elasticsearch/OpenSearch + Fluent Bit + Kibana) | CloudWatch Logs, Splunk, Datadog Logs |
| Traces | **Jaeger**, Grafana **Tempo**, Zipkin | AWS X-Ray, Datadog APM, Honeycomb |
| Instrumentation standard | **OpenTelemetry** SDKs + Collector | (all major vendors ingest OTLP) |
| Kubernetes-native | kube-state-metrics, node-exporter, metrics-server, Kubernetes events | — |

## Kubernetes observability
| Layer | What to watch | Where it comes from |
|---|---|---|
| **Cluster / nodes** | CPU, memory, disk, network, node conditions (`MemoryPressure`, `DiskPressure`) | node-exporter, kubelet |
| **Control plane** | API server latency/errors, etcd health, scheduler queue | component `/metrics` endpoints |
| **Workloads** | pod restarts, `CrashLoopBackOff`, OOMKilled, readiness, desired vs available replicas, HPA status | **kube-state-metrics**, kubelet |
| **Containers** | CPU usage vs requests/limits, throttling, memory working set vs limit | **cAdvisor** (inside the kubelet) |
| **Applications** | RED metrics, business metrics, logs, traces | app `/metrics` + ServiceMonitor, stdout logs, OpenTelemetry |
| **Events** | scheduling failures, image pull errors, evictions | `kubectl get events` / event exporter |

Two separate metrics paths exist in Kubernetes:
- **metrics-server** → the *Resource Metrics API* (`kubectl top`, HPA) — only current CPU/memory, no history
- **Prometheus** → full time-series history, any metric, PromQL, alerting — what this session's demo installs with **kube-prometheus-stack** (Prometheus Operator, Prometheus, Alertmanager, Grafana with ~25 pre-built Kubernetes dashboards, node-exporter, kube-state-metrics)

The Prometheus Operator adds Kubernetes-native config objects: **ServiceMonitor/PodMonitor** (what to scrape — I used one for my app) and **PrometheusRule** (alerting/recording rules — my 4 demo alerts), so monitoring config lives in Git next to the app, just like the GitOps part of this session.

The live demo of all of this (metrics, logs, alerts, CPU/memory utilization, application health) is in the [session README](../README.md).
