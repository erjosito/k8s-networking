# Exercise 05 — DNS Resolution in Kubernetes

**Blueprint Domain:** 3 — DNS for Services and Pods  
**Progressive Environment:** 🔵 Builds on Exercise 04 — add a monitoring namespace and explore DNS in depth

## What Already Exists

From Exercise 04, the Bookstore has:
- Deployments: `frontend` (3 replicas), `backend` (5 replicas)
- StatefulSet: `database` (3 replicas) with headless `database-svc`
- Services: `frontend-svc`, `backend-svc`, `frontend-lb`, `external-api`

All resources are in the `default` namespace.

## Objective

Deep-dive into how Kubernetes DNS works using the existing Bookstore app: the `resolv.conf` configuration, cross-namespace resolution, SRV records, and custom DNS policies.

## Challenge

1. Inspect `/etc/resolv.conf` in one of the existing frontend pods. Identify the nameserver, search domains, and `ndots` value.
2. Create a `monitoring` namespace with a simple pod and service. From the monitoring pod, resolve `backend-svc` in the default namespace using:
   - Short name (should fail)
   - Namespace-qualified name (`backend-svc.default`)
   - Fully qualified domain name (`backend-svc.default.svc.cluster.local`)
3. Add a **named port** to `backend-svc` and look up its **SRV record**.
4. Deploy a pod with `dnsPolicy: None` and custom `dnsConfig` pointing to `8.8.8.8`. Verify it can resolve external names but **not** cluster Services.
5. Deploy a pod with `dnsPolicy: ClusterFirst` and verify it resolves both cluster Services and external names.

## What You'll Leave Running

| Resource | Name | Namespace | Details |
|----------|------|-----------|---------|
| (from Ex 04) | all previous resources | default | Full Bookstore |
| Namespace | `monitoring` | — | New namespace |
| Deployment | `monitor` | monitoring | 1 replica for DNS testing |
| Service | `monitor-svc` | monitoring | ClusterIP |

## Success Criteria

- [ ] You can explain every line in a pod's `/etc/resolv.conf`
- [ ] Cross-namespace DNS resolution works with qualified names
- [ ] SRV record for a named port returns the correct port number
- [ ] `dnsPolicy: None` with custom `dnsConfig` works as expected
- [ ] `ClusterFirst` resolves both internal and external names

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

**Pre-setup:**
```bash
kubectl create namespace monitoring
```

---

## Hints

<details>
<summary>Hint 1 — Inspecting resolv.conf</summary>

```bash
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- cat /etc/resolv.conf
```

You'll see `nameserver`, `search`, and `options ndots:5`. The search list enables short-name resolution.

See: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

</details>

<details>
<summary>Hint 2 — SRV records</summary>

SRV records follow the format: `_<port-name>._<protocol>.<service>.<namespace>.svc.cluster.local`

```bash
nslookup -type=SRV _http._tcp.my-service.team-a.svc.cluster.local
```

You need a Service with a **named** port for SRV records to exist.

</details>

<details>
<summary>Hint 3 — dnsPolicy: None with dnsConfig</summary>

```yaml
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 8.8.8.8
    searches:
    - example.com
```

See: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Inspect resolv.conf of an existing frontend pod

```bash
FRONTEND_POD=$(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec $FRONTEND_POD -- cat /etc/resolv.conf
```

Example output:
```
nameserver 10.0.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

- `nameserver 10.0.0.10` → CoreDNS service IP
- `search` → enables short-name resolution in this namespace, then cluster-wide
- `ndots:5` → queries with fewer than 5 dots are first attempted with search suffixes

### Step 2 — Cross-namespace resolution

```bash
# Deploy a monitoring workload
kubectl create deployment monitor --image=nginx:stable -n monitoring
kubectl expose deployment monitor --port=80 -n monitoring --name=monitor-svc

# Try resolving backend-svc (default namespace) from monitoring namespace
kubectl run test -n monitoring --rm -it --image=busybox:1.36 --restart=Never -- sh

# Inside the pod:
nslookup backend-svc                    # FAILS — searches monitoring.svc.cluster.local
nslookup backend-svc.default             # WORKS — matches via search suffix
nslookup backend-svc.default.svc.cluster.local  # WORKS — fully qualified
```

### Step 3 — SRV records for named port

```bash
# Patch backend-svc to have a named port
kubectl patch svc backend-svc --type='json' \
  -p='[{"op":"replace","path":"/spec/ports/0/name","value":"http"}]'

kubectl run srv-test --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup -type=SRV _http._tcp.backend-svc.default.svc.cluster.local
```

### Step 4 — Custom DNS with dnsPolicy: None

```yaml
# custom-dns-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 8.8.8.8
    searches:
    - example.com
    options:
    - name: ndots
      value: "1"
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
kubectl apply -f custom-dns-pod.yaml
kubectl exec custom-dns -- cat /etc/resolv.conf
kubectl exec custom-dns -- nslookup kubernetes.io     # WORKS (external)
kubectl exec custom-dns -- nslookup backend-svc        # FAILS (no cluster DNS)
kubectl delete pod custom-dns
```

### Step 5 — ClusterFirst resolves both

```bash
kubectl run cluster-first --rm -it --image=busybox:1.36 --restart=Never -- sh
# Inside:
nslookup backend-svc.default  # WORKS (cluster)
nslookup kubernetes.io         # WORKS (external, forwarded by CoreDNS)
```

> ⚠️ **Do NOT delete the `monitoring` namespace** — it will be used in later exercises.

### Optional Cleanup (only if starting over)

```bash
kubectl delete namespace monitoring
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

</details>
