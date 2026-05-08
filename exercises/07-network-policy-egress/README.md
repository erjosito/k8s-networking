# Exercise 07 — Network Policy: Egress Rules

**Blueprint Domain:** 4 — Network Policies  
**Progressive Environment:** 🔵 Builds on Exercise 06 — add egress controls to complement ingress

## What Already Exists

From Exercise 06, the Bookstore has:
- Full Bookstore workloads (frontend, backend, database) with Services
- Ingress NetworkPolicies: `default-deny-ingress`, `allow-frontend-to-backend`, `allow-backend-to-database`
- Service `external-api` (ExternalName → httpbin.org)
- Namespace `monitoring`

## Objective

Add **egress** NetworkPolicies to the Bookstore. The backend needs to call the external payment API (`httpbin.org`), but no other pod should be allowed to reach the internet. You must keep DNS working despite default-deny egress.

## Challenge

1. Verify that the backend pod can currently reach `httpbin.org` (via `external-api` service).
2. Apply a **default-deny egress** NetworkPolicy to all pods in the `default` namespace.
3. Verify that DNS resolution and external access both fail.
4. Create an egress rule that allows **DNS traffic** (UDP/TCP port 53) to CoreDNS in `kube-system`.
5. Create an egress rule that allows the **backend only** to reach external IPs on ports 80/443, but blocks access to cluster-internal CIDRs.
6. Verify: backend → httpbin.org ✅, frontend → httpbin.org ❌, backend → database ❌ (egress-blocked).

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| (from Ex 06) | all previous resources | Bookstore + ingress policies |
| NetworkPolicy | `default-deny-egress` | Blocks all egress in default ns |
| NetworkPolicy | `allow-dns` | DNS egress to kube-system |
| NetworkPolicy | `allow-backend-external` | Backend → internet (80/443) |

## Success Criteria

- [ ] Default-deny egress blocks all outgoing traffic (including DNS)
- [ ] DNS-allow rule restores name resolution for all pods
- [ ] Backend can reach httpbin.org but frontend cannot
- [ ] You understand that egress and ingress policies are evaluated independently

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh` (with Calico network policy).

---

## Hints

<details>
<summary>Hint 1 — Default-deny egress</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

This isolates all pods in the namespace for egress. **No outgoing traffic** is allowed — not even DNS.

See: https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-egress-traffic

</details>

<details>
<summary>Hint 2 — Allowing DNS</summary>

CoreDNS usually runs in `kube-system`. You need to allow UDP port 53 egress to it:

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - port: 53
    protocol: UDP
  - port: 53
    protocol: TCP
```

</details>

<details>
<summary>Hint 3 — Allowing external but blocking internal</summary>

Use `ipBlock` with `except` to allow all external IPs but exclude cluster CIDRs:

```yaml
egress:
- to:
  - ipBlock:
      cidr: 0.0.0.0/0
      except:
      - 10.0.0.0/8       # Adjust to match your cluster CIDRs
      - 172.16.0.0/12
```

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Verify current egress from backend

```bash
BE_POD=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec $BE_POD -- curl -s --max-time 5 http://httpbin.org/ip
# Should return your cluster's outbound IP
```

### Step 2 — Default-deny egress

```yaml
# deny-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

```bash
kubectl apply -f deny-egress.yaml
kubectl exec $BE_POD -- curl -s --max-time 5 http://httpbin.org/ip
# TIMEOUT — all egress is blocked, including DNS
```

### Step 3 — Allow DNS egress

```yaml
# allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

```bash
kubectl apply -f allow-dns.yaml
kubectl exec $BE_POD -- nslookup httpbin.org   # Should now resolve
kubectl exec $BE_POD -- curl -s --max-time 5 http://httpbin.org/ip
# Still TIMEOUT — DNS works but HTTP egress is still blocked
```

### Step 4 — Allow backend to reach external APIs

```yaml
# allow-backend-external.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-external
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
    ports:
    - port: 80
      protocol: TCP
    - port: 443
      protocol: TCP
```

```bash
kubectl apply -f allow-backend-external.yaml
kubectl exec $BE_POD -- curl -s --max-time 5 http://httpbin.org/ip
# Should now work — backend can reach external APIs
```

### Step 5 — Verify frontend is still blocked

```bash
FE_POD=$(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec $FE_POD -- curl -s --max-time 5 http://httpbin.org/ip
# TIMEOUT — frontend has no external egress rule
```

> ⚠️ **Do NOT delete the NetworkPolicies** — they demonstrate the full security posture for the Bookstore.

### Optional Cleanup (only if starting over)

```bash
kubectl delete networkpolicy default-deny-egress allow-dns allow-backend-external
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-egress-traffic

</details>
