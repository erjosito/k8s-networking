# Exercise 06 — Network Policy: Ingress Rules

**Blueprint Domain:** 4 — Network Policies  
**Progressive Environment:** 🔵 Builds on Exercise 05 — lock down the Bookstore with ingress policies

## What Already Exists

From Exercise 05, the Bookstore has:
- Deployments: `frontend` (`app=frontend, tier=frontend`), `backend` (`app=backend, tier=backend`)
- StatefulSet: `database` (`app=database, tier=database`)
- Services: `frontend-svc`, `backend-svc`, `database-svc` (headless), `frontend-lb`, `external-api`
- Namespace: `monitoring` with `monitor` deployment

## Objective

Use NetworkPolicies to lock down the Bookstore's **inbound traffic**. Only the intended communication paths should be allowed: frontend ← users, backend ← frontend, database ← backend.

## Challenge

1. Verify that **all Bookstore pods can reach all other pods** by default (no isolation).
2. Create a **default-deny ingress** NetworkPolicy that blocks all inbound traffic to all pods in the `default` namespace.
3. Verify that frontend can no longer reach backend, and backend can no longer reach database.
4. Create a NetworkPolicy that allows **only frontend pods** to reach the backend on port 80.
5. Create a NetworkPolicy that allows **only backend pods** to reach the database on port 80.
6. Verify:
   - Frontend → Backend: ✅ Allowed
   - Frontend → Database: ❌ Blocked
   - Backend → Database: ✅ Allowed
   - External test pod → Backend: ❌ Blocked

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| (from Ex 05) | all previous resources | Full Bookstore + monitoring |
| NetworkPolicy | `default-deny-ingress` | Blocks all ingress in default ns |
| NetworkPolicy | `allow-frontend-to-backend` | frontend → backend on port 80 |
| NetworkPolicy | `allow-backend-to-database` | backend → database on port 80 |

## Success Criteria

- [ ] Default-deny policy blocks all ingress traffic
- [ ] Selective policies allow traffic only on the intended paths
- [ ] You understand the difference between single-element and multi-element `from` selectors

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

> **Important:** The cluster must have a CNI plugin that supports NetworkPolicy (the shared cluster uses Calico).

---

## Hints

<details>
<summary>Hint 1 — Default-deny ingress policy</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}    # Selects ALL pods in the namespace
  policyTypes:
  - Ingress
  # No ingress rules = deny all ingress
```

See: https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-traffic

</details>

<details>
<summary>Hint 2 — Allow specific traffic</summary>

Use `podSelector` in the `from` field to allow traffic from pods with specific labels:

```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        tier: frontend
  ports:
  - port: 80
```

</details>

<details>
<summary>Hint 3 — Testing connectivity</summary>

```bash
BACKEND_IP=$(kubectl get pod -l tier=backend -o jsonpath='{.items[0].status.podIP}')
kubectl exec <frontend-pod> -- wget -qO- --timeout=3 http://$BACKEND_IP
```

A timeout indicates the traffic is blocked. A successful response means it's allowed.

</details>

<details>
<summary>Hint 4 — Single vs. multi-element selectors</summary>

**Single element (AND):** both conditions must be true:
```yaml
- podSelector:
    matchLabels:
      tier: frontend
  namespaceSelector:
    matchLabels:
      env: prod
```

**Multi element (OR):** either condition can be true:
```yaml
- podSelector:
    matchLabels:
      tier: frontend
- namespaceSelector:
    matchLabels:
      env: prod
```

See: https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Verify default connectivity (using existing Bookstore pods)

```bash
FE_POD=$(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BE_IP=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].status.podIP}')
DB_IP=$(kubectl get pod -l app=database -o jsonpath='{.items[0].status.podIP}')

kubectl exec $FE_POD -- curl -s --max-time 3 http://$BE_IP   # Should work
kubectl exec $FE_POD -- curl -s --max-time 3 http://$DB_IP   # Should work
```

### Step 2 — Default-deny ingress

```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```bash
kubectl apply -f default-deny.yaml
kubectl exec $FE_POD -- curl -s --max-time 3 http://$BE_IP   # TIMEOUT — blocked
```

### Step 3 — Allow frontend → backend

```yaml
# allow-fe-to-be.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 80
      protocol: TCP
```

### Step 4 — Allow backend → database

```yaml
# allow-be-to-db.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - port: 80
      protocol: TCP
```

```bash
kubectl apply -f allow-fe-to-be.yaml -f allow-be-to-db.yaml
```

### Step 5 — Verify the rules

```bash
BE_POD=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Frontend → Backend: ALLOWED
kubectl exec $FE_POD -- curl -s --max-time 3 http://$BE_IP

# Frontend → Database: BLOCKED
kubectl exec $FE_POD -- curl -s --max-time 3 http://$DB_IP

# Backend → Database: ALLOWED
kubectl exec $BE_POD -- curl -s --max-time 3 http://$DB_IP

# Random pod → Backend: BLOCKED
kubectl run outsider --rm -it --image=busybox:1.36 --restart=Never -- \
  wget -qO- --timeout=3 http://$BE_IP
```

> ⚠️ **Do NOT delete the NetworkPolicies** — they are carried forward into Exercise 07 (egress).

### Optional Cleanup (only if starting over)

```bash
kubectl delete networkpolicy default-deny-ingress allow-frontend-to-backend allow-backend-to-database
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/

</details>
