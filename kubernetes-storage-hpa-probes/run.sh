#!/bin/bash
# Kubernetes Storage, HPA & Probes homework (Session 13).
# Requires Docker Desktop running + minikube installed + minikube start already run.
# Usage: ./run.sh            (set SHOT_DIR=/some/dir to also save each step's output to a file)
set -e
cd "$(dirname "$0")"

# run: print the command like a terminal prompt, then execute it.
# shot: start a new output file (one per screenshot) when SHOT_DIR is set.
CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
ready() { kubectl wait --for=condition=Ready "$@" --timeout=120s >/dev/null; }

# old practice pod from class with the same name (busybox sleep) -- remove so the lab yaml applies cleanly
kubectl delete pod emptydir-demo --ignore-not-found >/dev/null

########################################################################
# TASK 1: Kubernetes Volumes
########################################################################
cd 01-kubernetes-volumes

shot 01-emptydir-write
run kubectl apply -f emptydir-pod.yaml
ready pod/emptydir-demo
run kubectl get pod emptydir-demo
run "kubectl exec emptydir-demo -- bash -c 'echo \"Hello Kubernetes from Anushka\" > /data/message.txt'"
run kubectl exec emptydir-demo -- cat /data/message.txt

shot 02-emptydir-lost
run kubectl delete pod emptydir-demo
run kubectl apply -f emptydir-pod.yaml
ready pod/emptydir-demo
run kubectl exec emptydir-demo -- cat /data/message.txt || true

shot 03-hostpath
run kubectl apply -f hostpath-pod.yaml
ready pod/hostpath-demo
run "kubectl exec hostpath-demo -- bash -c 'echo \"written via hostPath\" > /data/host.txt'"
run kubectl delete pod hostpath-demo
run kubectl apply -f hostpath-pod.yaml
ready pod/hostpath-demo
run kubectl exec hostpath-demo -- cat /data/host.txt
run minikube ssh -- cat /tmp/hostpath-data/host.txt

shot 04-pv-pvc-bound
run kubectl apply -f pv.yaml
run kubectl get pv student-pv
run kubectl apply -f pvc.yaml
sleep 2
run kubectl get pvc student-pvc
run kubectl get pv student-pv

shot 05-pvc-pod-persist
run kubectl apply -f pod.yaml
ready pod/storage-demo
run "kubectl exec storage-demo -- bash -c 'echo \"Kubernetes Storage - Anushka Jain\" > /data/message.txt'"
run kubectl delete pod storage-demo
run kubectl apply -f pod.yaml
ready pod/storage-demo
run kubectl exec storage-demo -- cat /data/message.txt

shot 06-storageclass-dynamic
run kubectl get storageclass
run "kubectl describe storageclass standard | grep -E 'Name|IsDefault|Provisioner|ReclaimPolicy|VolumeBindingMode'"
run kubectl apply -f dynamic-pvc.yaml
sleep 3
run kubectl get pvc
run kubectl get pv
cd ..

########################################################################
# TASK 2: HPA hands-on
########################################################################
cd 02-hpa

shot 07-metrics-server
run minikube addons enable metrics-server
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s >/dev/null
until kubectl top nodes >/dev/null 2>&1; do sleep 5; done
run "kubectl get pods -n kube-system | grep metrics-server"
run kubectl top nodes

shot 08-hpa-deploy
run kubectl apply -f deployment.yaml -f service.yaml
kubectl rollout status deployment/hpa-demo --timeout=120s >/dev/null
run kubectl apply -f hpa.yml
until kubectl get hpa hpa-demo -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null | grep -q '[0-9]'; do sleep 5; done
run kubectl get deployment,svc,hpa
run kubectl top pods -l app=hpa-demo

shot 09-load-generator
run kubectl apply -f load-generator.yaml
kubectl rollout status deployment/load-generator --timeout=120s >/dev/null
run kubectl get pods -l app=load-generator

shot 10-hpa-scale-up
echo "\$ kubectl get hpa hpa-demo -w     (sampled every 15s)" | tee -a "$CUR"
kubectl get hpa hpa-demo | head -1 | tee -a "$CUR"
for i in $(seq 1 20); do
  kubectl get hpa hpa-demo --no-headers | tee -a "$CUR"
  [ "$(kubectl get hpa hpa-demo -o jsonpath='{.status.currentReplicas}')" -ge 5 ] && break
  sleep 15
done
echo | tee -a "$CUR"

shot 11-hpa-pods-top
sleep 20
run kubectl get pods -l app=hpa-demo
run kubectl top pods -l app=hpa-demo

shot 12-hpa-describe
run "kubectl describe hpa hpa-demo | sed -n '/^Metrics/,\$p'"

shot 13-hpa-scale-down
run kubectl delete -f load-generator.yaml
echo "\$ kubectl get hpa hpa-demo -w     (sampled every 30s, default 5 min scale-down stabilization window)" | tee -a "$CUR"
kubectl get hpa hpa-demo | head -1 | tee -a "$CUR"
for i in $(seq 1 20); do
  kubectl get hpa hpa-demo --no-headers | tee -a "$CUR"
  [ "$(kubectl get hpa hpa-demo -o jsonpath='{.status.currentReplicas}')" -le 1 ] && break
  sleep 30
done
echo | tee -a "$CUR"
run kubectl get pods -l app=hpa-demo
cd ..

########################################################################
# TASK 3: Probes (liveness / readiness / startup)
########################################################################
cd 03-probes

shot 14-probes-healthy
run kubectl apply -f liveness.yaml -f readiness.yaml -f startup.yaml
ready pod/liveness-demo pod/readiness-demo pod/startup-demo
run kubectl get pods liveness-demo readiness-demo startup-demo
run "kubectl describe pod startup-demo | grep -E 'Liveness|Readiness|Startup'"
run kubectl expose pod readiness-demo --name=readiness-service --port=80
sleep 2
run kubectl get endpoints readiness-service

shot 15-readiness-broken
run kubectl apply -f readiness-broken.yaml
run kubectl expose pod readiness-broken --name=readiness-broken-service --port=80
sleep 25
run kubectl get pod readiness-broken
run kubectl get endpoints readiness-broken-service
run "kubectl describe pod readiness-broken | grep -A1 Unhealthy | tail -2"

shot 16-liveness-broken
run kubectl apply -f liveness-broken.yaml
sleep 50
run kubectl get pod liveness-broken
run "kubectl describe pod liveness-broken | sed -n '/^Events/,\$p'"
cd ..

########################################################################
# TASK 4: Mini project (PVC + HPA + all 3 probes)
########################################################################
cd mini-project

shot 17-mini-deploy
run kubectl apply -f namespace.yaml -f pvc.yaml
run kubectl apply -f deployment.yaml -f service.yaml -f hpa.yaml
kubectl -n production-webapp rollout status deployment/web-app --timeout=180s >/dev/null
until kubectl -n production-webapp get hpa web-app-hpa -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null | grep -q '[0-9]'; do sleep 5; done
run kubectl get pvc,pods,svc,hpa -n production-webapp

shot 18-mini-persistence
POD=$(kubectl get pods -n production-webapp -l app=web-app -o jsonpath='{.items[0].metadata.name}')
run "kubectl exec -n production-webapp $POD -- sh -c 'echo \"Student: Anushka Jain\" > /data/student.txt'"
run kubectl delete pod -n production-webapp $POD
kubectl -n production-webapp rollout status deployment/web-app --timeout=180s >/dev/null
ready pod -n production-webapp -l app=web-app
# read back from the NEWEST pod (the replacement), not the surviving replica
NEW=$(kubectl get pods -n production-webapp -l app=web-app --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
run kubectl get pods -n production-webapp
run kubectl exec -n production-webapp $NEW -- cat /data/student.txt

shot 19-mini-service
kubectl port-forward -n production-webapp svc/web-service 8081:80 >/dev/null 2>&1 &
PF=$!
sleep 3
run "curl -s http://localhost:8081 | grep -i '<title>'"
kill $PF 2>/dev/null; wait $PF 2>/dev/null || true

shot 20-mini-hpa-scale
run "kubectl run load-generator -n production-webapp --image=busybox:1.36 --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://web-service >/dev/null; done'"
run "kubectl run load-generator-2 -n production-webapp --image=busybox:1.36 --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://web-service >/dev/null; done'"
echo "\$ kubectl get hpa -n production-webapp -w     (sampled every 15s)" | tee -a "$CUR"
kubectl get hpa -n production-webapp | head -1 | tee -a "$CUR"
for i in $(seq 1 20); do
  kubectl get hpa -n production-webapp --no-headers | tee -a "$CUR"
  [ "$(kubectl -n production-webapp get hpa web-app-hpa -o jsonpath='{.status.currentReplicas}')" -ge 4 ] && break
  sleep 15
done
echo | tee -a "$CUR"
run kubectl get pods -n production-webapp
run kubectl delete pod -n production-webapp load-generator load-generator-2
cd ..

########################################################################
# Cleanup
########################################################################
shot 21-cleanup
run bash cleanup.sh
