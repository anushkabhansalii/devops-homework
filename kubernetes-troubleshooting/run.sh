#!/bin/bash
# Kubernetes Troubleshooting homework (Session 14).
# Requires Docker Desktop running + minikube started with the metrics-server addon enabled.
# Usage: ./run.sh            (set SHOT_DIR=/some/dir to also save each step's output to a file)
set -e
cd "$(dirname "$0")"

# run: print the command like a terminal prompt, then execute it.
# shot: start a new output file (one per screenshot) when SHOT_DIR is set.
# waitfor: poll a command until its output matches a pattern (max ~3 min).
CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
waitfor() { for _ in $(seq 1 90); do bash -c "$1" 2>/dev/null | grep -q -E "$2" && return 0; sleep 2; done; echo "timed out waiting for: $1 =~ $2"; }
ready() { kubectl wait --for=condition=Ready "$@" --timeout=180s >/dev/null; }

minikube addons enable metrics-server >/dev/null

########################################################################
# TASK 1: the 8 troubleshooting commands
########################################################################
cd 01-commands
kubectl apply -f pod.yaml >/dev/null; ready pod/logs-demo
waitfor "kubectl top pod logs-demo --no-headers" "logs-demo"

shot 01-get
run kubectl get pods
run kubectl get pods -o wide
run "kubectl get pod logs-demo -o jsonpath='{.status.phase}{\"  \"}{.status.podIP}{\"  \"}{.spec.nodeName}{\"\\n\"}'"

shot 02-describe
run "kubectl describe pod logs-demo | sed -n '1,12p;/^Containers:/,/^Conditions:/p'"

shot 03-logs-exec
run kubectl logs logs-demo --tail=5
run "kubectl exec logs-demo -- sh -c 'hostname; ps; cat /etc/resolv.conf'"

shot 04-events
run "kubectl events --for pod/logs-demo"
run "kubectl get events --sort-by=.lastTimestamp | tail -6"

shot 05-explain-top
run "kubectl explain pod.spec.containers.livenessProbe | head -16"
run kubectl top nodes
run kubectl top pod logs-demo
kubectl delete -f pod.yaml --wait=false >/dev/null
cd ..

########################################################################
# TASK 2: common issues -- identify, investigate, root cause, fix, verify
########################################################################
cd 02-common-issues

# 1. CrashLoopBackOff
cd 01-crashloopbackoff
kubectl apply -f broken.yaml >/dev/null
waitfor "kubectl get pod crash-demo -o jsonpath='{.status.containerStatuses[0].restartCount}'" "^[3-9]"
waitfor "kubectl get pod crash-demo -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'" "CrashLoopBackOff"
shot 06-crashloop-broken
run kubectl get pod crash-demo
run kubectl logs crash-demo --previous
run "kubectl describe pod crash-demo | grep -E 'State:|Reason:|Exit Code:|Restart Count:|Back-off'"
shot 07-crashloop-fixed
run kubectl delete pod crash-demo --wait
run kubectl apply -f fixed.yaml
ready pod/crash-demo
sleep 3
run kubectl get pod crash-demo
run kubectl logs crash-demo
kubectl delete pod crash-demo --wait=false >/dev/null
cd ..

# 2. ErrImagePull / ImagePullBackOff
cd 02-imagepullbackoff
kubectl apply -f broken.yaml >/dev/null
waitfor "kubectl get pod image-demo" "ErrImagePull|ImagePullBackOff"
shot 08-imagepull-broken
run kubectl get pod image-demo
sleep 20
run kubectl get pod image-demo
run "kubectl describe pod image-demo | sed -n '/^Events/,\$p'"
shot 09-imagepull-fixed
run kubectl delete pod image-demo --wait
run kubectl apply -f fixed.yaml
ready pod/image-demo
run kubectl get pod image-demo
kubectl delete pod image-demo --wait=false >/dev/null
cd ..

# 3. Pending
cd 03-pending
kubectl apply -f broken.yaml >/dev/null
waitfor "kubectl describe pod pending-demo" "FailedScheduling"
shot 10-pending-broken
run kubectl get pod pending-demo -o wide
run "kubectl describe pod pending-demo | sed -n '/^Events/,\$p'"
run "kubectl describe node minikube | grep -A6 'Allocatable:'"
shot 11-pending-fixed
run kubectl delete pod pending-demo --wait
run kubectl apply -f fixed.yaml
ready pod/pending-demo
run kubectl get pod pending-demo -o wide
kubectl delete pod pending-demo --wait=false >/dev/null
cd ..

# 4. Stuck in ContainerCreating
cd 04-containercreating
kubectl apply -f broken.yaml >/dev/null
waitfor "kubectl describe pod creating-demo" "FailedMount"
sleep 5
shot 12-containercreating-broken
run kubectl get pod creating-demo
run "kubectl describe pod creating-demo | sed -n '/^Events/,\$p'"
run kubectl get configmap site-content
shot 13-containercreating-fixed
run kubectl apply -f configmap.yaml
ready pod/creating-demo
run kubectl get pod creating-demo
run kubectl exec creating-demo -- curl -s localhost
kubectl delete -f broken.yaml -f configmap.yaml --wait=false >/dev/null
cd ..

# 5. Service connectivity (selector mismatch -> no endpoints)
cd 05-service-connectivity
kubectl apply -f deployment.yaml -f broken-service.yaml -f client.yaml >/dev/null
kubectl rollout status deployment/web --timeout=120s >/dev/null; ready pod/client
shot 14-service-broken
run kubectl exec client -- curl -s -m 3 http://web-service || true
run kubectl get endpoints web-service
run "kubectl describe svc web-service | grep -E 'Selector|Endpoints'"
run kubectl get pods -l app=web --show-labels
shot 15-service-fixed
run kubectl apply -f fixed-service.yaml
sleep 3
run kubectl get endpoints web-service
run "kubectl exec client -- curl -s -m 3 http://web-service | grep -i '<title>'"
cd ..

# 6. DNS
cd 06-dns
kubectl apply -f dns-test-pod.yaml -f broken-client.yaml >/dev/null
ready pod/dns-test pod/dns-client
sleep 8
shot 16-dns-broken
run kubectl logs dns-client --tail=3
run kubectl exec dns-test -- nslookup web-svc.production.svc.cluster.local || true
run kubectl get svc -A
shot 17-dns-investigate
run kubectl exec dns-test -- cat /etc/resolv.conf
run kubectl exec dns-test -- nslookup web-service
run kubectl exec dns-test -- nslookup web-service.default.svc.cluster.local
run kubectl get pods -n kube-system -l k8s-app=kube-dns
shot 18-dns-fixed
run kubectl delete pod dns-client --wait
run kubectl apply -f fixed-client.yaml
ready pod/dns-client
sleep 8
run kubectl logs dns-client --tail=3
kubectl delete pod dns-client dns-test --wait=false >/dev/null
cd ..

# 7. Pod networking (wrong targetPort -> connection refused)
cd 07-pod-networking
kubectl apply -f broken-service.yaml >/dev/null
sleep 3
shot 19-networking-broken
run kubectl exec client -- curl -s -m 3 http://web-port-service || true
run kubectl get endpoints web-port-service
POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].status.podIP}')
run "kubectl exec client -- curl -s -m 3 -o /dev/null -w '%{http_code}\\n' http://$POD:80"
run kubectl exec client -- curl -s -m 3 http://$POD:8080 || true
shot 20-networking-fixed
run kubectl apply -f fixed-service.yaml
sleep 3
run kubectl get endpoints web-port-service
run "kubectl exec client -- curl -s -m 3 http://web-port-service | grep -i '<title>'"
kubectl delete -f fixed-service.yaml -f ../05-service-connectivity/ --ignore-not-found --wait=false >/dev/null
cd ..

# 8. Configuration issue (CreateContainerConfigError)
cd 08-configuration
kubectl apply -f broken.yaml >/dev/null
waitfor "kubectl get pod config-demo" "CreateContainerConfigError"
shot 21-config-broken
run kubectl get pod config-demo
run "kubectl describe pod config-demo | sed -n '/^Events/,\$p' | tail -3"
shot 22-config-fixed
run kubectl apply -f secret.yaml
ready pod/config-demo
run kubectl get pod config-demo
run kubectl logs config-demo
kubectl delete -f broken.yaml -f secret.yaml --wait=false >/dev/null
cd ..

# 9. OOMKilled (bonus)
cd 09-oomkilled
kubectl apply -f broken.yaml >/dev/null
waitfor "kubectl describe pod oom-demo" "OOMKilled"
shot 23-oom-broken
run kubectl get pod oom-demo
run "kubectl describe pod oom-demo | grep -E -A4 'Last State'"
shot 24-oom-fixed
run kubectl delete pod oom-demo --wait
run kubectl apply -f fixed.yaml
ready pod/oom-demo
sleep 3
run kubectl get pod oom-demo
run kubectl logs oom-demo
kubectl delete pod oom-demo --wait=false >/dev/null
cd ../..

########################################################################
# TASK 3: mini project -- troubleshooting challenge + triage gauntlet
########################################################################
cd mini-project
kubectl apply -f deployment.yaml -f service.yaml >/dev/null
kubectl rollout status deployment/troubleshooting-app --timeout=120s >/dev/null
shot 25-mini-app
run kubectl get pods -o wide -l app=troubleshooting-app
run "kubectl describe service troubleshooting-service | grep -E 'Selector|TargetPort|Endpoints'"
run kubectl get endpoints troubleshooting-service
P=$(kubectl get pods -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}')
run "kubectl exec $P -- curl -s localhost | grep -i '<title>'"

kubectl apply -f broken-pod.yaml >/dev/null
waitfor "kubectl get pod project-broken-pod" "ErrImagePull|ImagePullBackOff"
sleep 10
shot 26-mini-broken-pod
run kubectl get pod project-broken-pod
run "kubectl describe pod project-broken-pod | sed -n '/^Events/,\$p'"
run kubectl delete pod project-broken-pod --wait
run kubectl apply -f fixed-pod.yaml
ready pod/project-broken-pod
run kubectl get pod project-broken-pod

cd scenarios
shot 27-gauntlet-broken
run bash triage_all.sh
waitfor "kubectl get pod fail-1-crashloop-pod -o jsonpath='{.status.containerStatuses[0].restartCount}'" "^[2-9]"
waitfor "kubectl get pod fail-5-oomkilled-pod" "CrashLoopBackOff|OOMKilled"
waitfor "kubectl get pod fail-2-imagepull-pod" "ImagePullBackOff"
run kubectl get pods -l tier=triage-gauntlet

shot 28-gauntlet-diagnose
run kubectl logs fail-1-crashloop-pod
run "kubectl describe pod fail-2-imagepull-pod | grep -E 'Failed.*pull' | tail -1"
run "kubectl describe pod fail-3-pending-pod | grep FailedScheduling"
run kubectl logs fail-4-dns-failure-pod
run "kubectl exec fail-4-dns-failure-pod -- nslookup postgres-db-wrong-name.production.svc.cluster.local 2>&1 | tail -3"
run "kubectl get pod fail-5-oomkilled-pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{\"  exitCode=\"}{.status.containerStatuses[0].lastState.terminated.exitCode}{\"\\n\"}'"

shot 29-gauntlet-fixed
run kubectl delete pods -l tier=triage-gauntlet --wait
run kubectl apply -f scenario-1-crashloop/fixed.yaml -f scenario-2-imagepull/fixed.yaml -f scenario-3-pending/fixed.yaml -f scenario-4-dns-failure/fixed.yaml -f scenario-5-oomkilled/fixed.yaml
ready pod -l tier=triage-gauntlet
sleep 5
run kubectl get pods -l tier=triage-gauntlet
run kubectl logs fail-1-crashloop-pod
run kubectl logs fail-4-dns-failure-pod
run kubectl logs fail-5-oomkilled-pod
cd ../..

shot 30-cleanup
run bash cleanup.sh
