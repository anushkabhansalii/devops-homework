# Kubernetes Volumes

**Name:** Anushka Jain

What I learned about `emptyDir`, `hostPath`, PersistentVolume, PersistentVolumeClaim, StorageClass and dynamic provisioning. Every example below was run on my local minikube cluster (output from [`../run.sh`](../run.sh)). Manifests in this folder: [`emptydir-pod.yaml`](./emptydir-pod.yaml), [`hostpath-pod.yaml`](./hostpath-pod.yaml), [`pv.yaml`](./pv.yaml), [`pvc.yaml`](./pvc.yaml), [`pod.yaml`](./pod.yaml), [`dynamic-pvc.yaml`](./dynamic-pvc.yaml).

## Why volumes?
A container's filesystem is **ephemeral** — it lives and dies with the container. If a container crashes and the kubelet restarts it, or the Pod gets deleted and a ReplicaSet/Deployment creates a new one (with a new random name + new IP, as we saw in earlier sessions), anything written inside the container is gone. A **volume** gives the container a directory that lives *outside* its own writable layer. How long that directory survives depends on the volume type:

| Type | Lives as long as | Shared between | Typical use |
|---|---|---|---|
| `emptyDir` | the **Pod** | containers in the same Pod | scratch space, cache, sidecar sharing |
| `hostPath` | the **Node** | Pods scheduled on that node | node agents (logs, Docker socket), local testing |
| PV + PVC | independent of Pods (until PV is deleted / reclaimed) | depends on access mode | databases, uploads, any real app data |

```text
Container ──writes──► Volume ──(emptyDir)──► dies with the Pod
                             ──(hostPath)──► a folder on the node
                             ──(PVC)───────► PV ──► real disk (EBS, NFS, minikube-hostpath …)
```

---

## 1. `emptyDir` — temporary, Pod-scoped storage
Created empty when the Pod is scheduled, deleted when the Pod is removed. It **survives container restarts** (same Pod) but **not Pod deletion**.
```yaml
volumes:
  - name: app-storage
    emptyDir: {}          # can also be emptyDir: { medium: Memory } for a tmpfs (RAM) volume
```
```text
$ kubectl apply -f emptydir-pod.yaml
pod/emptydir-demo created

$ kubectl exec emptydir-demo -- bash -c 'echo "Hello Kubernetes from Anushka" > /data/message.txt'
$ kubectl exec emptydir-demo -- cat /data/message.txt
Hello Kubernetes from Anushka

$ kubectl delete pod emptydir-demo
pod "emptydir-demo" deleted from default namespace
$ kubectl apply -f emptydir-pod.yaml
pod/emptydir-demo created

$ kubectl exec emptydir-demo -- cat /data/message.txt
cat: /data/message.txt: No such file or directory
command terminated with exit code 1
```
New Pod → brand-new empty directory → data lost. Exactly what `emptyDir` promises.

![emptyDir write](../screenshots/01-emptydir-write.png)
![emptyDir lost after pod delete](../screenshots/02-emptydir-lost.png)

---

## 2. `hostPath` — mount a folder from the node
Mounts a real directory of the **node's** filesystem into the Pod. `type: DirectoryOrCreate` creates it if missing.
```yaml
volumes:
  - name: host-storage
    hostPath:
      path: /tmp/hostpath-data
      type: DirectoryOrCreate
```
```text
$ kubectl exec hostpath-demo -- bash -c 'echo "written via hostPath" > /data/host.txt'
$ kubectl delete pod hostpath-demo
$ kubectl apply -f hostpath-pod.yaml

$ kubectl exec hostpath-demo -- cat /data/host.txt
written via hostPath

$ minikube ssh -- cat /tmp/hostpath-data/host.txt      <- the file really lives on the minikube node
written via hostPath
```
It survived the Pod delete — but only because the new Pod landed on the **same node**. On a multi-node cluster the Pod could be rescheduled elsewhere and see an empty folder. It also gives the Pod access to the node's filesystem (security risk). So hostPath is fine for learning / single-node / DaemonSets that need node files (e.g. log collectors reading `/var/log`), but **not** for real application data.

![hostPath](../screenshots/03-hostpath.png)

---

## 3. PersistentVolume (PV) & PersistentVolumeClaim (PVC)
Kubernetes splits storage into two objects so that **who provides storage** is separated from **who uses it**:
- **PersistentVolume (PV)** — a piece of storage in the cluster (cluster-scoped, usually created by an admin or automatically). Has a capacity, access modes, a reclaim policy and the actual backend (hostPath, NFS, AWS EBS, …).
- **PersistentVolumeClaim (PVC)** — a *request* for storage by a user/app (namespaced): "I need 500Mi, ReadWriteOnce". Kubernetes finds a matching PV and **binds** them 1-to-1.
- The **Pod** only references the PVC by name — it never knows what disk is behind it.

```text
Pod ──uses──► PVC (request: 500Mi RWO) ──bound to──► PV (1Gi RWO, hostPath /tmp/student-data) ──► disk
```

**Access modes**

| Mode | Short | Meaning |
|---|---|---|
| ReadWriteOnce | RWO | read-write by a single **node** |
| ReadOnlyMany | ROX | read-only by many nodes |
| ReadWriteMany | RWX | read-write by many nodes (needs NFS/EFS-like storage) |
| ReadWriteOncePod | RWOP | read-write by a single **Pod** |

**Reclaim policy** (what happens to the PV after its PVC is deleted): `Retain` (keep the data, admin cleans up manually — used for our static PV), `Delete` (delete PV + underlying disk — the default for dynamically provisioned volumes).

**Static provisioning demo** — I created the PV by hand, then a PVC that claims it:
```text
$ kubectl apply -f pv.yaml
persistentvolume/student-pv created

$ kubectl get pv student-pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS
student-pv   1Gi        RWO            Retain           Available

$ kubectl apply -f pvc.yaml
persistentvolumeclaim/student-pvc created

$ kubectl get pvc student-pvc
NAME          STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS
student-pvc   Bound    student-pv   1Gi        RWO

$ kubectl get pv student-pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS
student-pv   1Gi        RWO            Retain           Bound    default/student-pvc
```
PV went **Available → Bound**. The PVC asked for 500Mi but got the whole 1Gi PV — binding is 1-to-1, the smallest PV that satisfies the request wins.

> **Gotcha I hit:** the lab's original `pvc.yaml` had no `storageClassName`. minikube has a *default* StorageClass (`standard`), and the DefaultStorageClass admission controller silently fills it in, so the PVC would get a **new dynamically-provisioned PV** instead of binding to my `student-pv` (which has no class). Setting `storageClassName: ""` on both the PV and the PVC means "no class, static binding only", and then they bind to each other.

![PV and PVC bound](../screenshots/04-pv-pvc-bound.png)

**Data survives Pod deletion** ([`pod.yaml`](./pod.yaml) mounts `student-pvc` at `/data`):
```text
$ kubectl exec storage-demo -- bash -c 'echo "Kubernetes Storage - Anushka Jain" > /data/message.txt'
$ kubectl delete pod storage-demo
pod "storage-demo" deleted from default namespace
$ kubectl apply -f pod.yaml
pod/storage-demo created

$ kubectl exec storage-demo -- cat /data/message.txt
Kubernetes Storage - Anushka Jain
```
Compare with emptyDir above — same test, opposite result. The storage's lifecycle is independent of the Pod.

![PVC data persists](../screenshots/05-pvc-pod-persist.png)

---

## 4. StorageClass & dynamic provisioning
Creating PVs by hand doesn't scale (100 developers → admin creates 100 PVs). A **StorageClass** describes a *type* of storage plus a **provisioner** that can create PVs on demand. When a PVC names a StorageClass (or the cluster has a default one), the provisioner automatically creates a matching PV and binds it — this is **dynamic provisioning**.
```text
PVC (storageClassName: standard) ──► StorageClass "standard" ──► provisioner k8s.io/minikube-hostpath ──► new PV pvc-<uid>
```
Important StorageClass fields: `provisioner` (who creates the disk — e.g. `ebs.csi.aws.com` on EKS, `k8s.io/minikube-hostpath` locally), `reclaimPolicy`, `volumeBindingMode` (`Immediate` = provision as soon as the PVC is created; `WaitForFirstConsumer` = wait until a Pod uses it so the disk is created in the right zone), `allowVolumeExpansion`, and `parameters` (disk type, IOPS, …).
```text
$ kubectl get storageclass
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  19d

$ kubectl apply -f dynamic-pvc.yaml
persistentvolumeclaim/dynamic-pvc created

$ kubectl get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
dynamic-pvc   Bound    pvc-77ca82d5-d728-4fb2-9c1d-43813fd86bd1   500Mi      RWO            standard
student-pvc   Bound    student-pv                                 1Gi        RWO

$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS
pvc-77ca82d5-d728-4fb2-9c1d-43813fd86bd1   500Mi      RWO            Delete           Bound    default/dynamic-pvc   standard
student-pv                                 1Gi        RWO            Retain           Bound    default/student-pvc
```
Side by side:
- `student-pv` — **static**: I wrote it, `Retain`, no class, 1Gi (more than requested).
- `pvc-77ca…` — **dynamic**: I never created it, the provisioner did, auto-generated name, exactly 500Mi, `Delete` (inherited from the StorageClass — deleting the PVC deletes the volume).

![StorageClass dynamic provisioning](../screenshots/06-storageclass-dynamic.png)

---

## Summary
```text
emptyDir      → temporary, dies with the Pod
hostPath      → a node folder, tied to that node
PV            → a piece of storage (static: admin-made / dynamic: provisioner-made)
PVC           → an app's request for storage, binds 1-to-1 to a PV
StorageClass  → "type of storage + provisioner", enables dynamic provisioning
Pod           → mounts the PVC, never cares what disk is behind it
```
In production: Deployments (stateless) mostly use no volume or emptyDir; databases use **StatefulSets** with `volumeClaimTemplates`, so each replica (`mysql-0`, `mysql-1`, …) gets its *own* dynamically provisioned PVC that follows it even when the Pod is rescheduled — this ties back to the StatefulSet / headless service discussion from class.

## Useful commands
```bash
kubectl get pv,pvc
kubectl describe pv student-pv
kubectl describe pvc student-pvc
kubectl get storageclass
kubectl describe storageclass standard
kubectl exec -it <pod> -- bash
```

## References
- https://kubernetes.io/docs/concepts/storage/volumes/
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- https://kubernetes.io/docs/concepts/storage/storage-classes/
- https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/
