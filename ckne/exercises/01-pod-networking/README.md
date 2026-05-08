# Exercise 01 — Pod-to-Pod Networking

**Blueprint Domain:** 1 — Kubernetes Network Model Fundamentals  
**Progressive Environment:** 🟢 Starting point — you deploy the first pods

## Objective

Prove that the Kubernetes flat network model works: every pod can reach every other pod by IP address, regardless of which node they are scheduled on, **without NAT**.

## Challenge

You're building a "Bookstore" application that will grow across all exercises. In this first exercise, you deploy the **frontend** and **backend** tiers as standalone pods.

1. Deploy a `frontend` pod (nginx) and a `backend` pod (nginx) on **different nodes** in the cluster.
2. From `frontend`, reach `backend` using its **pod IP** — verify you get a response.
3. From `backend`, reach `frontend` using its **pod IP** — verify you get a response.
4. Prove that the source IP seen by the destination pod matches the sender's pod IP (no NAT).
5. Deploy a multi-container pod (`frontend-debug`) with **two containers** (nginx + busybox sidecar) and prove they communicate over `localhost`.
6. **Bonus — hostNetwork:** Deploy a pod with `hostNetwork: true` and verify it shares the node's network namespace (the pod's IP should be the node IP). Understand the security implications.

## What You'll Leave Running

After this exercise, the following resources remain for the next exercises:

| Resource | Name | Labels |
|----------|------|--------|
| Pod | `frontend` | `app=frontend, tier=frontend` |
| Pod | `backend` | `app=backend, tier=backend` |
| Pod | `frontend-debug` | `app=frontend-debug` |

## Success Criteria

- [ ] Two pods (`frontend` and `backend`) run on **different** nodes (use `kubectl get pods -o wide` to verify)
- [ ] Bidirectional HTTP connectivity between pods using pod IPs
- [ ] Source IP at the receiver matches the sender's pod IP
- [ ] Two containers in the same pod (`frontend-debug`) communicate via `localhost`
- [ ] (Bonus) A `hostNetwork: true` pod has the same IP as its node

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh` (3 nodes).

No additional infrastructure is required for this exercise.

## Pre-requisites

```bash
# Deploy the shared AKS cluster (if not already running)
cd ckne/infra && bash deploy-aks.sh
```

---

## Hints

<details>
<summary>Hint 1 — Scheduling pods on different nodes</summary>

You can use `nodeSelector` or pod anti-affinity to ensure pods land on different nodes. Alternatively, run enough replicas and verify with `-o wide`.

See: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/

</details>

<details>
<summary>Hint 2 — Getting the pod IP</summary>

```bash
kubectl get pods -o wide
```

The `IP` column shows each pod's cluster IP. You can also use:

```bash
kubectl get pod <name> -o jsonpath='{.status.podIP}'
```

</details>

<details>
<summary>Hint 3 — Testing connectivity from inside a pod</summary>

Use `kubectl exec` to run commands inside a pod:

```bash
kubectl exec -it <pod-name> -- curl <target-pod-ip>
```

If `curl` isn't available, use `wget -qO-` or deploy a pod with networking tools (e.g., `nicolaka/netshoot`).

</details>

<details>
<summary>Hint 4 — Verifying source IP (no NAT)</summary>

Run a web server that echoes the client IP. For example, use a pod running `nginx` and check access logs, or use `hashicorp/http-echo` combined with a server that logs headers.

A simpler approach: deploy a `netshoot` pod and use `tcpdump` on the receiving end.

</details>

<details>
<summary>Hint 5 — Multi-container pod (localhost communication)</summary>

Define a pod with two containers in the same spec. They share the same network namespace.

See: https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers

</details>

<details>
<summary>Hint 6 — hostNetwork pods</summary>

Setting `hostNetwork: true` in the pod spec places the pod in the node's network namespace instead of its own. The pod's IP will be the node's IP.

```yaml
spec:
  hostNetwork: true
  containers:
  - name: web
    image: nginx:stable
```

⚠️ Only port 80 of `hostNetwork` pods is accessible if the node firewall allows it. Two pods with `hostNetwork: true` on the same node **cannot** bind to the same port.

See: https://kubernetes.io/docs/concepts/services-networking/

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Deploy frontend and backend pods on different nodes

```yaml
# pod-a.yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    app: frontend
    tier: frontend
spec:
  containers:
  - name: web
    image: nginx:stable
    ports:
    - containerPort: 80
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: backend
        topologyKey: kubernetes.io/hostname
---
# pod-b.yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
  labels:
    app: backend
    tier: backend
spec:
  containers:
  - name: web
    image: nginx:stable
    ports:
    - containerPort: 80
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: frontend
        topologyKey: kubernetes.io/hostname
```

```bash
kubectl apply -f pod-a.yaml -f pod-b.yaml
kubectl get pods -o wide  # Verify different nodes
```

### Step 2 — Test pod-to-pod connectivity

```bash
BACKEND_IP=$(kubectl get pod backend -o jsonpath='{.status.podIP}')
kubectl exec frontend -- curl -s $BACKEND_IP

FRONTEND_IP=$(kubectl get pod frontend -o jsonpath='{.status.podIP}')
kubectl exec backend -- curl -s $FRONTEND_IP
```

### Step 3 — Verify no NAT (source IP)

```bash
# Check nginx access logs on backend after the curl from frontend
kubectl logs backend | tail -1
# The log should show frontend's IP as the client, e.g.:
# 10.244.1.5 - - [08/May/2026:...] "GET / HTTP/1.1" 200 ...
```

### Step 4 — Multi-container pod with localhost

```yaml
# multi-container.yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-debug
  labels:
    app: frontend-debug
spec:
  containers:
  - name: web
    image: nginx:stable
    ports:
    - containerPort: 80
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f multi-container.yaml
kubectl exec frontend-debug -c sidecar -- wget -qO- http://localhost:80
# Should return the nginx welcome page
```

### Step 5 — hostNetwork pod (Bonus)

```yaml
# hostnet-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostnet-test
spec:
  hostNetwork: true
  containers:
  - name: net
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f hostnet-pod.yaml
kubectl wait --for=condition=Ready pod/hostnet-test

# Compare pod IP with node IP — they should match
POD_IP=$(kubectl get pod hostnet-test -o jsonpath='{.status.podIP}')
NODE_NAME=$(kubectl get pod hostnet-test -o jsonpath='{.spec.nodeName}')
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "Pod IP: $POD_IP  Node IP: $NODE_IP"  # Should be identical

# Clean up — this is a learning exercise, not needed later
kubectl delete pod hostnet-test
```

> ⚠️ **Do NOT clean up** — these pods are used in Exercise 02.

### Optional Cleanup (only if starting over)

```bash
kubectl delete pod frontend backend frontend-debug
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/
- https://kubernetes.io/docs/concepts/cluster-administration/networking/
- https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers

</details>
