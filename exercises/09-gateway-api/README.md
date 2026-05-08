[⬅️ Previous: Ingress Controllers](../08-ingress-controllers/README.md) | [🏠 Home](../../README.md) | [Next: Service Debugging ➡️](../10-service-debugging/README.md)

# Exercise 09 — Gateway API

**Blueprint Domain:** 6 — Gateway API  
**Progressive Environment:** 🔵 Builds on Exercise 08 — add Gateway API as the modern replacement for Ingress

> **Context:** The Gateway API supersedes Ingress with richer routing, role-oriented design, and extensibility. Having used Ingress in Exercise 08, you can now compare both approaches side by side.

## What Already Exists

From Exercise 08, the Bookstore has:
- Full Bookstore workloads with Services and NetworkPolicies
- NGINX Ingress Controller with Ingress resources for the frontend
- Namespace `monitoring`

## Objective

Deploy the Gateway API alongside the existing Ingress setup. Use it to implement a **canary deployment** for the Bookstore backend (v2 rollout), demonstrating the Gateway API's traffic splitting, path-based routing, and header-based matching capabilities.


> **💡 Tip:** You can save your YAML manifests and notes in the `solution/` folder within this exercise directory — it is git-ignored and won't be committed.

## Challenge

1. Install the Gateway API CRDs and a Gateway API implementation (e.g., NGINX Gateway Fabric).
2. Create a **GatewayClass** and a **Gateway** listening on port 80.
3. Deploy a second version of the backend (`backend-v2`) with a Service.
4. Create an **HTTPRoute** with path-based routing:
   - `/v1` → `backend-svc` (original)
   - `/v2` → `backend-v2-svc`
5. Create an HTTPRoute for **canary traffic splitting**: 80% to `backend-svc`, 20% to `backend-v2-svc`.
6. Create an HTTPRoute with **header-based matching**: `X-Version: v2` → `backend-v2-svc`, all others → `backend-svc`.
7. **Bonus — GRPCRoute:** Create a **GRPCRoute** that routes gRPC traffic to a backend. Deploy a simple gRPC echo service and verify the route works.

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| (from Ex 08) | all previous resources | Full Bookstore + Ingress |
| Namespace | `nginx-gateway` | Gateway API implementation |
| Deployment | `backend-v2` | Canary version of backend |
| Service | `backend-v2-svc` | ClusterIP for backend-v2 |
| Gateway | `bookstore-gateway` | HTTP listener on port 80 |
| HTTPRoute | `backend-canary` | 80/20 traffic split |

## Success Criteria

- [ ] GatewayClass, Gateway, and HTTPRoute resources are created and accepted
- [ ] Path-based routing directs traffic to the correct backend
- [ ] Weighted traffic splitting distributes approximately 80/20
- [ ] Header-based matching works correctly
- [ ] (Bonus) A GRPCRoute correctly routes gRPC traffic

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

**Additional setup:**
```bash
# Install Gateway API CRDs (standard channel)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Install a Gateway API implementation — using NGINX Gateway Fabric as an example
helm repo add nginx-gateway https://nginx.github.io/nginx-gateway-fabric
helm repo update
helm install ngf nginx-gateway/nginx-gateway-fabric \
  --namespace nginx-gateway --create-namespace \
  --set service.type=LoadBalancer
```

> **Alternative:** You can use Envoy Gateway or any other [conformant implementation](https://gateway-api.sigs.k8s.io/implementations/).

---

## Hints

<details>
<summary>Hint 1 — GatewayClass and Gateway</summary>

The GatewayClass is typically created by the Gateway API implementation's Helm chart. Check:

```bash
kubectl get gatewayclass
```

If you need to create a Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: nginx   # Must match your installed GatewayClass
  listeners:
  - name: http
    protocol: HTTP
    port: 80
```

See: https://kubernetes.io/docs/concepts/services-networking/gateway/

</details>

<details>
<summary>Hint 2 — HTTPRoute for path-based routing</summary>

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-routes
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1
    backendRefs:
    - name: app-v1
      port: 80
```

See: https://gateway-api.sigs.k8s.io/guides/http-routing/

</details>

<details>
<summary>Hint 3 — Traffic splitting (weighted backends)</summary>

Use the `weight` field on `backendRefs`:

```yaml
rules:
- backendRefs:
  - name: app-v1
    port: 80
    weight: 80
  - name: app-v2
    port: 80
    weight: 20
```

See: https://gateway-api.sigs.k8s.io/guides/traffic-splitting/

</details>

<details>
<summary>Hint 4 — Header-based matching</summary>

```yaml
rules:
- matches:
  - headers:
    - name: X-Version
      value: v2
  backendRefs:
  - name: app-v2
    port: 80
```

See: https://gateway-api.sigs.k8s.io/guides/http-routing/#matching

</details>

<details>
<summary>Hint 5 — GRPCRoute (Bonus)</summary>

GRPCRoute is GA since Gateway API v1.2.0. You need a Gateway with an HTTP/2 listener and a gRPC backend service.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: grpc-route
spec:
  parentRefs:
  - name: bookstore-gateway
  rules:
  - matches:
    - method:
        service: echo.EchoService
    backendRefs:
    - name: grpc-echo-svc
      port: 50051
```

The `matches` field uses `method` with `service` and optionally `method` to match specific gRPC methods.

See: https://gateway-api.sigs.k8s.io/guides/grpc-routing/

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Install Gateway API

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
# Install your chosen implementation (see Infrastructure section above)
```

### Step 2 — Create Gateway for the Bookstore

```yaml
# gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bookstore-gateway
spec:
  gatewayClassName: nginx  # Match your GatewayClass
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
```

```bash
kubectl apply -f gateway.yaml
kubectl get gateway bookstore-gateway
```

### Step 3 — Deploy backend v2 (canary)

```bash
kubectl create deployment backend-v2 --image=nginx:stable
kubectl label deployment backend-v2 tier=backend version=v2
kubectl expose deployment backend-v2 --port=80 --target-port=80 --name=backend-v2-svc
```

### Step 4 — Path-based HTTPRoute

```yaml
# path-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-path-route
spec:
  parentRefs:
  - name: bookstore-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1
    backendRefs:
    - name: backend-svc
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /v2
    backendRefs:
    - name: backend-v2-svc
      port: 80
```

```bash
kubectl apply -f path-route.yaml
GW_IP=$(kubectl get gateway bookstore-gateway -o jsonpath='{.status.addresses[0].value}')
curl http://$GW_IP/v1   # Original backend
curl http://$GW_IP/v2   # Canary backend
```

### Step 5 — Traffic splitting

```yaml
# canary-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-canary
spec:
  parentRefs:
  - name: bookstore-gateway
  hostnames:
  - "canary.example.com"
  rules:
  - backendRefs:
    - name: backend-svc
      port: 80
      weight: 80
    - name: backend-v2-svc
      port: 80
      weight: 20
```

```bash
kubectl apply -f canary-route.yaml
# Test with multiple requests
for i in $(seq 1 20); do
  curl -s -H "Host: canary.example.com" http://$GW_IP/
done
# Approximately 80% original backend, 20% canary backend
```

### Step 6 — Header-based matching

```yaml
# header-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-header-route
spec:
  parentRefs:
  - name: bookstore-gateway
  hostnames:
  - "header.example.com"
  rules:
  - matches:
    - headers:
      - name: X-Version
        value: v2
    backendRefs:
    - name: backend-v2-svc
      port: 80
  - backendRefs:
    - name: backend-svc
      port: 80
```

```bash
kubectl apply -f header-route.yaml
curl -H "Host: header.example.com" http://$GW_IP/                    # Original backend
curl -H "Host: header.example.com" -H "X-Version: v2" http://$GW_IP/ # Canary backend
```

### Step 7 — GRPCRoute (Bonus)

```bash
# Deploy a gRPC echo server (using grpcbin as a test service)
kubectl create deployment grpc-echo --image=moul/grpcbin
kubectl expose deployment grpc-echo --port=50051 --target-port=9000 --name=grpc-echo-svc
```

```yaml
# grpc-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: grpc-route
spec:
  parentRefs:
  - name: bookstore-gateway
  hostnames:
  - "grpc.example.com"
  rules:
  - backendRefs:
    - name: grpc-echo-svc
      port: 50051
```

```bash
kubectl apply -f grpc-route.yaml
kubectl get grpcroute grpc-route
# Status should show Accepted: True

# If you have grpcurl installed, test it:
# grpcurl -plaintext -authority grpc.example.com $GW_IP:80 list
```

> **Note:** GRPCRoute support depends on your Gateway implementation. NGINX Gateway Fabric supports it from v1.2.0+.

> ⚠️ **Do NOT clean up** — this environment carries forward to the final debugging exercise.

### Optional Cleanup (only if starting over)

```bash
kubectl delete httproute backend-path-route backend-canary backend-header-route
kubectl delete gateway bookstore-gateway
kubectl delete deployment backend-v2
kubectl delete svc backend-v2-svc
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/gateway/
- https://gateway-api.sigs.k8s.io/
- https://gateway-api.sigs.k8s.io/guides/http-routing/

</details>

## 📚 Where to Look Next

Deepen your understanding of the topics in this exercise with the official Kubernetes documentation:

- [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) — Official Kubernetes overview of Gateway, GatewayClass, and route resources.
- [Gateway API — Getting Started](https://gateway-api.sigs.k8s.io/guides/) — Step-by-step guides from the upstream Gateway API project.
- [Gateway API — HTTPRoute](https://gateway-api.sigs.k8s.io/guides/http-routing/) — Path matching, header matching, and traffic splitting.
- [Gateway API — GRPCRoute](https://gateway-api.sigs.k8s.io/guides/grpc-routing/) — Routing gRPC traffic with the Gateway API.
- [Gateway API — API Reference](https://gateway-api.sigs.k8s.io/reference/spec/) — Full spec reference for all Gateway API resources.

---

[⬅️ Previous: Ingress Controllers](../08-ingress-controllers/README.md) | [🏠 Home](../../README.md) | [Next: Service Debugging ➡️](../10-service-debugging/README.md)
