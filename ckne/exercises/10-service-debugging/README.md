# Exercise 10 — Service Debugging

**Blueprint Domain:** 10 — Network Troubleshooting  
**Progressive Environment:** 🟠 Final exercise — debug a broken version of the Bookstore

## What Already Exists

From Exercise 09, you have a fully running Bookstore environment:
- Deployments: `frontend`, `backend`, `backend-v2` + StatefulSet `database`
- Services: `frontend-svc`, `backend-svc`, `backend-v2-svc`, `database-svc`, `external-api`
- NetworkPolicies: ingress and egress policies
- NGINX Ingress Controller + Ingress resources
- Gateway API with HTTPRoutes
- Namespace `monitoring`

## Objective

A colleague has attempted to deploy a second instance of the Bookstore in a new namespace (`staging`) but everything is broken. You need to use systematic debugging to find and fix **all 3 bugs** they introduced.

## Challenge

### Setup the broken environment

```bash
kubectl create namespace staging
```

Apply the broken manifests below. Your colleague was trying to replicate the production Bookstore but made several mistakes:

```yaml
# broken-bookstore.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: staging
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: front-end     # BUG 1: label "front-end" doesn't match Service selector "frontend"
    spec:
      containers:
      - name: web
        image: nginx:stable
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: staging
spec:
  selector:
    app: frontend          # Expects "frontend" but pods have "front-end"
  ports:
  - port: 80
    targetPort: 8080       # BUG 2: nginx listens on 80, not 8080
    protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: staging
spec:
  podSelector: {}
  policyTypes:
  - Ingress              # BUG 3: default-deny with no allow rule
```

### Your task

1. Apply the broken manifests to the `staging` namespace.
2. Deploy a test pod in `staging` and try to access `frontend-svc`. It will fail.
3. Use the systematic debugging approach (from your production experience!) to find and fix **all 3 bugs**.
4. Verify the Service works correctly after your fixes.
5. Use **`kubectl debug`** with an ephemeral container to troubleshoot a running pod without restarting it.

## Success Criteria

- [ ] You identify all 3 bugs without looking at the hints
- [ ] The Service returns the nginx welcome page after all fixes
- [ ] You can explain the debugging methodology you used
- [ ] You successfully attach an ephemeral debug container to a running pod

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

**Pre-setup:**
```bash
kubectl create namespace staging
# Copy the broken-bookstore.yaml content above and apply it
kubectl apply -f broken-bookstore.yaml
```

---

## Hints

<details>
<summary>Hint 1 — Debugging checklist</summary>

Follow this systematic order (from the Kubernetes docs):

1. **Does the Service exist?** → `kubectl get svc -n staging`
2. **Does the Service have endpoints?** → `kubectl get endpoints frontend-svc -n staging`
3. **Do the labels match?** → Compare `kubectl get pods -n staging --show-labels` with the Service selector
4. **Is the targetPort correct?** → Check what port the container actually listens on
5. **Is there a NetworkPolicy blocking traffic?** → `kubectl get networkpolicy -n staging`
6. **Does DNS resolve?** → `nslookup frontend-svc.staging`

💡 **Pro tip:** Compare with your working production setup in the `default` namespace!

See: https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/

</details>

<details>
<summary>Hint 2 — Bug 1: Label mismatch</summary>

The Deployment template uses `app: front-end` but the Service selector expects `app: frontend`. 

Check with:
```bash
kubectl get endpoints frontend-svc -n staging
# Will show "<none>" — no endpoints because labels don't match
```

Fix: Change the pod template label to `app: frontend`.

</details>

<details>
<summary>Hint 3 — Bug 2: Wrong targetPort</summary>

The Service forwards to `targetPort: 8080` but nginx listens on port `80`.

Check with:
```bash
kubectl exec -n staging <pod> -- ss -tlnp
# Shows nginx listening on port 80
```

Fix: Change `targetPort` to `80`.

</details>

<details>
<summary>Hint 4 — Bug 3: NetworkPolicy blocking traffic</summary>

The `deny-all` NetworkPolicy blocks all ingress traffic. You need to add a rule allowing traffic to the frontend pods — just like you did in Exercise 06 for production!

</details>

<details>
<summary>Hint 5 — Ephemeral containers (kubectl debug)</summary>

You can attach a debug container to a running pod — without restarting it — using `kubectl debug`. This is useful when the pod image doesn't have networking tools:

```bash
kubectl debug -n staging <pod-name> -it --image=nicolaka/netshoot -- bash
```

Inside the ephemeral container, you share the pod's network namespace, so you can use `curl`, `dig`, `tcpdump`, etc.

See: https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Debugging walkthrough

```bash
# Step 1: Does the Service exist?
kubectl get svc frontend-svc -n staging
# YES — exists with ClusterIP

# Step 2: Does it have endpoints?
kubectl get endpoints frontend-svc -n staging
# PROBLEM: <none> — no endpoints!

# Step 3: Check labels
kubectl get pods -n staging --show-labels
# Shows: app=front-end
kubectl get svc frontend-svc -n staging -o jsonpath='{.spec.selector}'
# Shows: {"app":"frontend"}
# MISMATCH! Fix the pod labels.
```

### Fix 1 — Correct the label

```bash
kubectl patch deployment frontend -n staging --type json \
  -p '[{"op":"replace","path":"/spec/template/metadata/labels/app","value":"frontend"}]'

# Wait for rollout
kubectl rollout status deployment/frontend -n staging

# Verify endpoints now exist
kubectl get endpoints frontend-svc -n staging
# Should now show 3 pod IPs
```

### Fix 2 — Correct the targetPort

```bash
kubectl patch svc frontend-svc -n staging --type json \
  -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
```

### Fix 3 — Fix the NetworkPolicy

```yaml
# allow-staging-traffic.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: staging
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - port: 80
      protocol: TCP
```

```bash
kubectl apply -f allow-staging-traffic.yaml
```

### Verify the fix

```bash
kubectl run test -n staging --rm -it --image=busybox:1.36 --restart=Never -- \
  wget -qO- --timeout=5 http://frontend-svc
# Should return the nginx welcome page!
```

### Step 4 — Ephemeral containers for debugging

```bash
# Get a frontend pod name
FRONTEND_POD=$(kubectl get pods -n staging -l app=frontend -o jsonpath='{.items[0].metadata.name}')

# Attach an ephemeral debug container to a running pod
kubectl debug -n staging $FRONTEND_POD -it --image=nicolaka/netshoot -- bash

# Inside the ephemeral container, you share the pod's network namespace:
# Try network diagnostics:
#   curl localhost:80           # test the nginx container on this pod
#   dig frontend-svc.staging.svc.cluster.local
#   ss -tlnp                   # see listening ports in this pod
#   tcpdump -i eth0 -c 5       # capture packets
# Type 'exit' when done
```

> **Why this matters:** Production pod images are often minimal (distroless, scratch) and lack debugging tools. Ephemeral containers let you attach a full toolbox without restarting the pod or modifying its spec.

### Cleanup

This is the last exercise in Track 1. You can now tear down everything:

```bash
# Delete staging namespace
kubectl delete namespace staging

# If you want to clean up the entire Bookstore environment:
# See ckne/infra/cleanup.sh
```

**References:**
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

</details>
