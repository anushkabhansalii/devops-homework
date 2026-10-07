# Mini Project: Production-Ready Kubernetes Web App

**Name:** Anushka Jain

Session 13 capstone combining the three topics of the session in one app: **persistent storage** (PVC), **autoscaling** (HPA) and **health checks** (startup / readiness / liveness probes). Output from [`../run.sh`](../run.sh) on my minikube cluster.

## Architecture
```text
                         [ Service: web-service (ClusterIP :80) ]
                                         │  only sends traffic to READY pods
                  ┌──────────────────────┼──────────────────────┐
                  ▼                      ▼                      ▼
          [ Pod web-app-1 ]      [ Pod web-app-2 ]      [ Pod web-app-N ]
          startup / readiness / liveness probes, cpu request 100m, limit 200m
                  │                      │                      │
                  └──────── /data ───────┴──────── /data ───────┘
                                         │
                        PVC web-data (500Mi, RWO) ──► StorageClass standard ──► PV pvc-<uid>

        metrics-server ──► HPA web-app-hpa (min 2, max 5, target 50% CPU) ──► Deployment web-app
```

## Files
| File | What it does |
|---|---|
| [`namespace.yaml`](./namespace.yaml) | dedicated namespace `production-webapp` |
| [`pvc.yaml`](./pvc.yaml) | 500Mi `ReadWriteOnce` claim, no class → default `standard` StorageClass provisions it dynamically |
| [`deployment.yaml`](./deployment.yaml) | 2 replicas of nginx:1.27, `strategy: Recreate`, CPU/memory requests+limits, all 3 probes, PVC mounted at `/data` |
| [`service.yaml`](./service.yaml) | ClusterIP `web-service` port 80 |
| [`hpa.yaml`](./hpa.yaml) | autoscaling/v2 HPA, 2–5 replicas, 50% CPU |

Design notes:
- **`strategy: Recreate`** — the PVC is `ReadWriteOnce`. On a single-node cluster all replicas can share it (RWO is per *node*), but on a multi-node cluster a RollingUpdate could try to start the new pod on another node while the old one still holds the volume. Recreate stops old pods first.
- **Probes:** startup gives nginx up to `30 × 2s = 60s` to come up; readiness (every 5s, 2 failures) gates traffic; liveness (every 5s, 3 failures) restarts a hung container.
- **CPU request `100m`** is what makes the HPA's "50%" mean something (50% of 100m = 50m per pod).

## 1. Deploy
```text
$ kubectl apply -f namespace.yaml -f pvc.yaml
namespace/production-webapp created
persistentvolumeclaim/web-data created

$ kubectl apply -f deployment.yaml -f service.yaml -f hpa.yaml
deployment.apps/web-app created
service/web-service created
horizontalpodautoscaler.autoscaling/web-app-hpa created

$ kubectl get pvc,pods,svc,hpa -n production-webapp
NAME                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
persistentvolumeclaim/web-data   Bound    pvc-fd2cecb4-d0e9-4c87-8d54-994e36ad7975   500Mi      RWO            standard

NAME                          READY   STATUS    RESTARTS   AGE
pod/web-app-d45775485-mq8rq   1/1     Running   0          91s
pod/web-app-d45775485-rc6wm   1/1     Running   0          91s

NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/web-service   ClusterIP   10.104.63.65   <none>        80/TCP    91s

NAME                                              REFERENCE            TARGETS       MINPODS   MAXPODS   REPLICAS
horizontalpodautoscaler.autoscaling/web-app-hpa   Deployment/web-app   cpu: 1%/50%   2         5         2
```
PVC bound to a dynamically created PV, both pods `1/1` (all probes passing), HPA reading metrics.

![mini project deployed](../screenshots/17-mini-deploy.png)

## 2. Verify storage persistence
Write from one pod, delete that pod, read from the **replacement** pod the Deployment creates:
```text
$ kubectl exec -n production-webapp web-app-d45775485-mq8rq -- sh -c 'echo "Student: Anushka Jain" > /data/student.txt'

$ kubectl delete pod -n production-webapp web-app-d45775485-mq8rq
pod "web-app-d45775485-mq8rq" deleted from production-webapp namespace

$ kubectl get pods -n production-webapp
NAME                      READY   STATUS    RESTARTS   AGE
web-app-d45775485-jwvnn   1/1     Running   0          9s       <- brand new pod
web-app-d45775485-rc6wm   1/1     Running   0          100s

$ kubectl exec -n production-webapp web-app-d45775485-jwvnn -- cat /data/student.txt
Student: Anushka Jain
```
The writer pod is gone, but the new pod (`jwvnn`, 9s old) reads the file — the data lives on the PV, not in the pod.

![mini project persistence](../screenshots/18-mini-persistence.png)

## 3. Verify the Service
ClusterIP is internal only, so (as in previous sessions on macOS + Docker driver) I used port-forward:
```text
$ kubectl port-forward -n production-webapp svc/web-service 8081:80 &
$ curl -s http://localhost:8081 | grep -i '<title>'
<title>Welcome to nginx!</title>
```
![mini project service](../screenshots/19-mini-service.png)

## 4. Trigger HPA scaling
```text
$ kubectl run load-generator   -n production-webapp --image=busybox:1.36 --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://web-service >/dev/null; done'
$ kubectl run load-generator-2 -n production-webapp --image=busybox:1.36 --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://web-service >/dev/null; done'

$ kubectl get hpa -n production-webapp -w     (sampled every 15s)
NAME          REFERENCE            TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
web-app-hpa   Deployment/web-app   cpu: 1%/50%    2     5     2     103s
web-app-hpa   Deployment/web-app   cpu: 34%/50%   2     5     2     2m44s
web-app-hpa   Deployment/web-app   cpu: 62%/50%   2     5     2     3m45s
web-app-hpa   Deployment/web-app   cpu: 62%/50%   2     5     3     4m        <- scaled 2 -> 3
web-app-hpa   Deployment/web-app   cpu: 51%/50%   2     5     3     4m31s
web-app-hpa   Deployment/web-app   cpu: 42%/50%   2     5     3     6m33s     <- settled under target

$ kubectl get pods -n production-webapp
NAME                      READY   STATUS    RESTARTS   AGE
load-generator            1/1     Running   0          5m5s
load-generator-2          1/1     Running   0          5m5s
web-app-d45775485-2qgzz   1/1     Running   0          3m18s     <- added by the HPA
web-app-d45775485-jwvnn   1/1     Running   0          5m17s
web-app-d45775485-rc6wm   1/1     Running   0          6m48s
```
`ceil(2 × 62/50) = ceil(2.48) = 3` replicas — and the new pod also mounted the same PVC and passed its startup/readiness probes before receiving traffic. After that, load per pod dropped to ~42%, so no further scaling was needed.

![mini project hpa scale](../screenshots/20-mini-hpa-scale.png)

## Probe reference
| Probe | Question | On failure |
|---|---|---|
| Startup | Has the process initialized? | restart container; other probes disabled until it passes |
| Readiness | Can the Pod receive traffic? | Pod IP removed from Service endpoints (no restart) |
| Liveness | Is the container alive? | kubelet restarts the container |

(Readiness vs liveness failure demos are in the main README, Task 3.)

## Troubleshooting guide
| Symptom | Check | Cause / fix |
|---|---|---|
| PVC stuck `Pending` | `kubectl describe pvc web-data -n production-webapp` | no default StorageClass → `minikube addons enable default-storageclass storage-provisioner`, check `kubectl get sc` |
| HPA `TARGETS <unknown>/50%` | `kubectl top pods -n production-webapp` | metrics-server off (`minikube addons enable metrics-server`) or container has no `resources.requests.cpu`. Also normal for the first ~30-60s |
| Pod `0/1 Running`, Service has no endpoints | `kubectl get endpoints web-service -n production-webapp` | readiness probe failing — wrong `path`/`port` |
| `CrashLoopBackOff`, RESTARTS climbing | `kubectl describe pod <pod>` → `Liveness probe failed` | liveness path/port wrong, or `initialDelaySeconds`/startup probe too short for the app |

## Cleanup
```bash
kubectl delete namespace production-webapp
```
