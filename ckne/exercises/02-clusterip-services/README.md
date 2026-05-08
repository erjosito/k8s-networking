# Exercise 02 — ClusterIP Services

**Blueprint Domain:** 2 — Services & Service Discovery  
**Progressive Environment:** 🔵 Builds on Exercise 01 — pods are running, now you add Services

## What Already Exists

From Exercise 01, you should have these pods running:
- `frontend` (label: `app=frontend, tier=frontend`)
- `backend` (label: `app=backend, tier=backend`)
- `frontend-debug` (multi-container pod)

## Objective

Replace the standalone pods with Deployments (for resilience and scaling) and create ClusterIP Services to provide stable endpoints. Understand how selectors bind pods to services and observe EndpointSlices.

## Challenge

1. Delete the standalone `frontend` and `backend` pods from Exercise 01 and replace them with **Deployments** (3 replicas each), keeping the same labels.
2. Create a ClusterIP Service named `frontend-svc` targeting the frontend pods on port 80.
3. Create a ClusterIP Service named `backend-svc` targeting the backend pods on port 80.
4. From a test pod, call `backend-svc` by its **cluster IP** — verify you get responses from different backend pods (load balancing).
5. Call `backend-svc` by its **DNS name** — verify it resolves to the cluster IP.
6. Inspect the EndpointSlice for `backend-svc` and verify it lists all 3 pod IPs.
7. Scale the backend to 5 replicas and verify the EndpointSlice updates automatically.

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| Deployment | `frontend` | 3 replicas, labels: `app=frontend, tier=frontend` |
| Deployment | `backend` | 5 replicas, labels: `app=backend, tier=backend` |
| Service | `frontend-svc` | ClusterIP, port 80 → frontend pods |
| Service | `backend-svc` | ClusterIP, port 80 → backend pods |
| Pod | `frontend-debug` | Multi-container pod from Ex 01 |

## Success Criteria

- [ ] Frontend and backend Deployments are running with correct labels
- [ ] ClusterIP Services `frontend-svc` and `backend-svc` exist and have cluster IPs
- [ ] Requests to `backend-svc` cluster IP return responses from different pods
- [ ] DNS resolution of `backend-svc.default.svc.cluster.local` works
- [ ] EndpointSlice contains the correct number of pod IPs
- [ ] Scaling the deployment automatically updates the EndpointSlice

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

No additional infrastructure required.

---

## Hints

<details>
<summary>Hint 1 — Creating the Deployment</summary>

```bash
kubectl create deployment hostnames --image=registry.k8s.io/serve_hostname --replicas=3
```

This container listens on port 9376 and returns its hostname.

See: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

</details>

<details>
<summary>Hint 2 — Creating the Service</summary>

```bash
kubectl expose deployment hostnames --port=80 --target-port=9376
```

Or use a YAML manifest. The key is mapping `port: 80` → `targetPort: 9376`.

See: https://kubernetes.io/docs/concepts/services-networking/service/#defining-a-service

</details>

<details>
<summary>Hint 3 — Testing load balancing</summary>

Run a loop from a test pod:

```bash
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- sh
# Inside the pod:
for i in $(seq 1 10); do wget -qO- hostnames; echo; done
```

You should see different hostnames in the output.

</details>

<details>
<summary>Hint 4 — Inspecting EndpointSlices</summary>

```bash
kubectl get endpointslices -l kubernetes.io/service-name=hostnames
kubectl describe endpointslice <name>
```

See: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Replace pods with Deployments

```bash
# Remove standalone pods from Exercise 01
kubectl delete pod frontend backend
```

```yaml
# bookstore-deployments.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: web
        image: nginx:stable
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: web
        image: nginx:stable
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f bookstore-deployments.yaml
kubectl get pods -l tier -o wide
```

### Step 2 — Create ClusterIP Services

```yaml
# bookstore-services.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
```

```bash
kubectl apply -f bookstore-services.yaml
kubectl get svc frontend-svc backend-svc
```

### Step 3 — Test load balancing

```bash
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- sh -c \
  'for i in $(seq 1 10); do wget -qO- http://backend-svc 2>/dev/null | head -1; done'
```

### Step 4 — Test DNS resolution

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup backend-svc
# Should resolve to backend-svc's cluster IP
```

### Step 5 — Inspect EndpointSlices

```bash
kubectl get endpointslices -l kubernetes.io/service-name=backend-svc -o yaml
# Verify the endpoints array contains 3 entries
```

### Step 6 — Scale and verify

```bash
kubectl scale deployment backend --replicas=5
sleep 5
kubectl get endpointslices -l kubernetes.io/service-name=backend-svc
# Should now show 5 endpoints
```

> ⚠️ **Do NOT clean up** — these Deployments and Services are used in Exercise 03.

### Optional Cleanup (only if starting over)

```bash
kubectl delete deployment frontend backend
kubectl delete svc frontend-svc backend-svc
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- https://kubernetes.io/docs/tutorials/services/connect-applications-service/

</details>
