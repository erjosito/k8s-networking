# Exercise 04 — Headless Services & StatefulSet DNS

**Blueprint Domain:** 2 — Services & Service Discovery + 3 — DNS  
**Progressive Environment:** 🔵 Builds on Exercise 03 — add a database tier to the Bookstore

## What Already Exists

From Exercise 03:
- Deployment `frontend` (3 replicas) + Service `frontend-svc` (ClusterIP) + `frontend-lb` (LoadBalancer)
- Deployment `backend` (5 replicas) + Service `backend-svc` (ClusterIP)
- Service `external-api` (ExternalName)

## Objective

Add a **database tier** to the Bookstore using a StatefulSet. Understand headless Services (Services without a cluster IP) and how they provide DNS records that resolve directly to individual pod IPs, giving each database replica a stable identity.


> **💡 Tip:** You can save your YAML manifests and notes in the `solution/` folder within this exercise directory — it is git-ignored and won't be committed.

## Challenge

1. Create a **headless Service** named `database-svc` (with `clusterIP: None`) targeting pods with label `app=database`.
2. Create a **StatefulSet** named `database` with 3 replicas using the headless Service.
3. Verify that `database-svc` does **not** get a cluster IP assigned.
4. Perform a DNS lookup on `database-svc` — verify it returns **individual pod IPs** (not a single virtual IP).
5. Resolve the DNS name of a **specific pod** using `database-0.database-svc.default.svc.cluster.local`.
6. Delete `database-1` and observe that it comes back with the **same name and DNS identity**.

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| (from Ex 03) | all previous resources | Deployments, Services |
| StatefulSet | `database` | 3 replicas, `app=database` |
| Service | `database-svc` | Headless (clusterIP: None) |

## Success Criteria

- [ ] Headless Service `database-svc` exists with `clusterIP: None`
- [ ] `nslookup database-svc` returns multiple A records (one per pod)
- [ ] `nslookup database-0.database-svc` resolves to that specific pod's IP
- [ ] Deleted StatefulSet pod `database-1` is recreated with the same ordinal name

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

---

## Hints

<details>
<summary>Hint 1 — What makes a Service "headless"</summary>

Set `clusterIP: None` in the Service spec. The Service won't get a virtual IP; instead, DNS queries return the IPs of the backing pods.

See: https://kubernetes.io/docs/concepts/services-networking/service/#headless-services

</details>

<details>
<summary>Hint 2 — StatefulSet requires a headless Service</summary>

A StatefulSet's `spec.serviceName` must reference a headless Service. This enables stable DNS names like `web-0.nginx.default.svc.cluster.local`.

See: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

</details>

<details>
<summary>Hint 3 — DNS lookup from inside the cluster</summary>

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup nginx
```

For a specific pod:
```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup web-0.nginx
```

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Create headless Service and StatefulSet

```yaml
# database.yaml
apiVersion: v1
kind: Service
metadata:
  name: database-svc
spec:
  clusterIP: None
  selector:
    app: database
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database-svc
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: db
        image: nginx:stable
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f database.yaml
kubectl get pods -l app=database -o wide
# Should show: database-0, database-1, database-2
```

### Step 2 — Verify headless Service

```bash
kubectl get svc database-svc
# CLUSTER-IP should show "None"
```

### Step 3 — DNS lookup returns individual pod IPs

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup database-svc
# Should return multiple addresses (one per pod)
```

### Step 4 — Resolve individual pod DNS

```bash
kubectl run dns-test2 --rm -it --image=busybox:1.36 --restart=Never -- nslookup database-0.database-svc
# Should resolve to database-0's specific IP

kubectl run dns-test3 --rm -it --image=busybox:1.36 --restart=Never -- nslookup database-2.database-svc
# Should resolve to database-2's specific IP
```

### Step 5 — Delete and observe stable identity

```bash
POD_IP_BEFORE=$(kubectl get pod database-1 -o jsonpath='{.status.podIP}')
echo "database-1 IP before delete: $POD_IP_BEFORE"

kubectl delete pod database-1
kubectl get pods -l app=database -w
# database-1 will be recreated with the same name

# The IP might change, but the DNS name (database-1.database-svc) stays stable
kubectl run dns-test4 --rm -it --image=busybox:1.36 --restart=Never -- nslookup database-1.database-svc
```

> ⚠️ **Do NOT clean up** — the database StatefulSet is part of the Bookstore environment.

### Optional Cleanup (only if starting over)

```bash
kubectl delete statefulset database
kubectl delete svc database-svc
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

</details>
