# Exercise 03 — External Services (NodePort & LoadBalancer)

**Blueprint Domain:** 2 — Services & Service Discovery  
**Progressive Environment:** 🔵 Builds on Exercise 02 — Deployments and ClusterIP Services exist

## What Already Exists

From Exercise 02:
- Deployment `frontend` (3 replicas, `app=frontend`)
- Deployment `backend` (5 replicas, `app=backend`)
- Service `frontend-svc` (ClusterIP)
- Service `backend-svc` (ClusterIP)

## Objective

Expose the Bookstore **frontend** to traffic from **outside the cluster** using NodePort and LoadBalancer service types. Understand `externalTrafficPolicy` and its effect on source IP preservation. Also learn how to reference external services via ExternalName.

## Challenge

1. Create a **NodePort** Service named `frontend-nodeport` for the frontend pods. Access it from within the cluster using `<node-ip>:<nodePort>`.
2. Create a **LoadBalancer** Service named `frontend-lb` for the frontend. Wait for an external IP and test from your machine.
3. Set `externalTrafficPolicy: Local` on `frontend-lb`. Observe the impact on traffic routing.
4. Create an **ExternalName** Service named `external-api` that maps to `httpbin.org` — the Bookstore needs to call an external payment API.
5. Create a **Service without selectors** named `legacy-db` with a manual **EndpointSlice** pointing to an IP address you choose (e.g., `10.0.99.1`). This simulates connecting the Bookstore to a legacy database that isn't running in Kubernetes.

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| (from Ex 02) | `frontend`, `backend` | Deployments |
| (from Ex 02) | `frontend-svc`, `backend-svc` | ClusterIP Services |
| Service | `frontend-lb` | LoadBalancer, externalTrafficPolicy: Local |
| Service | `external-api` | ExternalName → httpbin.org |
| Service | `legacy-db` | No selector, manual EndpointSlice |

## Success Criteria

- [ ] NodePort Service `frontend-nodeport` is accessible via `<node-ip>:<nodePort>`
- [ ] LoadBalancer Service `frontend-lb` gets an external IP and is reachable from the internet
- [ ] You understand the difference between `externalTrafficPolicy: Cluster` (default) and `Local`
- [ ] ExternalName Service `external-api` resolves to `httpbin.org`
- [ ] Service `legacy-db` with no selector has a manually created EndpointSlice and a working ClusterIP

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

> **Note:** AKS provisions Azure Load Balancers for `type: LoadBalancer` services automatically.

---

## Hints

<details>
<summary>Hint 1 — Creating a NodePort Service</summary>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nodeport
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Optional — Kubernetes assigns one if omitted
```

See: https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport

</details>

<details>
<summary>Hint 2 — Getting node IPs in AKS</summary>

In AKS, nodes typically don't have public IPs. You can test NodePort from within the cluster:

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://$NODE_IP:30080
```

</details>

<details>
<summary>Hint 3 — LoadBalancer Service</summary>

Simply change `type: NodePort` to `type: LoadBalancer`. AKS will provision an Azure Load Balancer.

```bash
kubectl get svc my-app-lb -w  # Watch until EXTERNAL-IP is assigned
```

See: https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer

</details>

<details>
<summary>Hint 4 — externalTrafficPolicy</summary>

```bash
kubectl patch svc my-app-lb -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

With `Local`, traffic is only routed to pods on the node that received the packet. This preserves source IP but may cause uneven load distribution.

See: https://kubernetes.io/docs/concepts/services-networking/service/#external-traffic-policy

</details>

<details>
<summary>Hint 5 — ExternalName Service</summary>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-httpbin
spec:
  type: ExternalName
  externalName: httpbin.org
```

See: https://kubernetes.io/docs/concepts/services-networking/service/#externalname

</details>

<details>
<summary>Hint 6 — Service without selectors</summary>

Create a Service **without** a `selector` field. Kubernetes will not auto-create EndpointSlices, so you must create one manually.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-external-db
spec:
  ports:
  - port: 3306
    targetPort: 3306
```

Then create an EndpointSlice that references this Service:

```yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: my-external-db-1
  labels:
    kubernetes.io/service-name: my-external-db  # This links it to the Service
addressType: IPv4
ports:
- port: 3306
endpoints:
- addresses:
  - "10.0.99.1"
```

See: https://kubernetes.io/docs/concepts/services-networking/service/#services-without-selectors

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — NodePort Service for frontend

```yaml
# frontend-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f frontend-nodeport.yaml
NODE_PORT=$(kubectl get svc frontend-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "NodePort: $NODE_PORT, Node IP: $NODE_IP"

# Test from within the cluster
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://$NODE_IP:$NODE_PORT
```

### Step 2 — LoadBalancer Service for frontend

```yaml
# frontend-lb.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-lb
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f frontend-lb.yaml
kubectl get svc frontend-lb -w
# Wait for EXTERNAL-IP, then:
EXTERNAL_IP=$(kubectl get svc frontend-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP
```

### Step 3 — externalTrafficPolicy: Local

```bash
kubectl patch svc frontend-lb -p '{"spec":{"externalTrafficPolicy":"Local"}}'
# Health check probes will now only return healthy for nodes with frontend pods
kubectl describe svc frontend-lb | grep -i "external traffic policy"
```

### Step 4 — ExternalName Service

```yaml
# external-api.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: httpbin.org
```

```bash
kubectl apply -f external-api.yaml
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- nslookup external-api
# Should return CNAME pointing to httpbin.org
```

### Step 5 — Service without selectors (manual EndpointSlice)

```yaml
# legacy-db.yaml
apiVersion: v1
kind: Service
metadata:
  name: legacy-db
spec:
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: legacy-db-1
  labels:
    kubernetes.io/service-name: legacy-db
addressType: IPv4
ports:
- port: 3306
  protocol: TCP
endpoints:
- addresses:
  - "10.0.99.1"
```

```bash
kubectl apply -f legacy-db.yaml

# Verify the service has a ClusterIP
kubectl get svc legacy-db
# Note: no selector listed

# Verify the EndpointSlice is linked
kubectl get endpointslices -l kubernetes.io/service-name=legacy-db
# Should show one slice with the 10.0.99.1 address

# Verify DNS resolves (the service is reachable by name even though 10.0.99.1 is fake)
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- nslookup legacy-db
```

> ⚠️ **Do NOT clean up** `frontend-lb` or `external-api` — they are used later. You **can** delete `frontend-nodeport` (it was just for learning).

```bash
kubectl delete svc frontend-nodeport  # optional
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types
- https://kubernetes.io/docs/concepts/services-networking/service/#external-traffic-policy

</details>
