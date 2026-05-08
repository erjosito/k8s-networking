# Exercise 08 — Ingress Controllers & Ingress Resources

**Blueprint Domain:** 5 — Ingress  
**Progressive Environment:** 🔵 Builds on Exercise 07 — expose the Bookstore through an Ingress

> **Context:** Ingress is the established approach for HTTP routing in Kubernetes and remains widely deployed in production. In Exercise 09, you'll learn the Gateway API — its modern successor.

## What Already Exists

From Exercise 07, the Bookstore has:
- Deployments: `frontend`, `backend` + StatefulSet `database`
- Services: `frontend-svc`, `backend-svc`, `database-svc`, `frontend-lb`, `external-api`
- NetworkPolicies: ingress (default-deny + selective) and egress (default-deny + DNS + backend-external)
- Namespace `monitoring`

## Objective

Replace the direct LoadBalancer exposure with proper HTTP routing through an **Ingress Controller**. Configure path-based and host-based routing with TLS termination for the Bookstore frontend and a monitoring dashboard.

## Challenge

1. Install the **NGINX Ingress Controller** in the cluster using Helm.
2. Create an Ingress resource with **path-based routing** for the Bookstore:
   - `/` → `frontend-svc` (the Bookstore frontend)
   - `/api` → `backend-svc` (the Bookstore API)
3. Verify that HTTP requests to `<ingress-ip>/` and `<ingress-ip>/api` are routed correctly.
4. Create a second Ingress with **host-based routing**:
   - `bookstore.example.com` → `frontend-svc`
   - `monitor.example.com` → `monitor-svc` (in the monitoring namespace)
5. Create a self-signed TLS certificate and configure **TLS termination** on the host-based Ingress.

## What You'll Leave Running

| Resource | Name | Details |
|----------|------|---------|
| (from Ex 07) | all previous resources | Full Bookstore + policies |
| Namespace | `ingress-nginx` | NGINX Ingress Controller |
| Ingress | `bookstore-paths` | Path-based routing |
| Ingress | `bookstore-hosts` | Host-based + TLS |
| Secret | `bookstore-tls` | Self-signed TLS cert |

> **Note:** You can delete `frontend-lb` LoadBalancer service — the Ingress replaces it.

## Success Criteria

- [ ] NGINX Ingress Controller is running and has an external IP
- [ ] Path-based routing works correctly (`/` → frontend, `/api` → backend)
- [ ] Host-based routing works with `Host` header (`bookstore.example.com`, `monitor.example.com`)
- [ ] TLS termination works (HTTPS connections succeed with the self-signed cert)

## Infrastructure

**Cluster:** Shared AKS cluster from `infra/deploy-aks.sh`.

**Additional setup:**
```bash
# Install NGINX Ingress Controller via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

---

## Hints

<details>
<summary>Hint 1 — Deploy the test applications</summary>

Use `hashicorp/http-echo` which returns a configurable text response:

```bash
kubectl create deployment app-a --image=hashicorp/http-echo -- -text="Hello from App A"
kubectl create deployment app-b --image=hashicorp/http-echo -- -text="Hello from App B"
kubectl expose deployment app-a --port=80 --target-port=5678
kubectl expose deployment app-b --port=80 --target-port=5678
```

</details>

<details>
<summary>Hint 2 — Path-based Ingress</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app-a
        pathType: Prefix
        backend:
          service:
            name: app-a
            port:
              number: 80
```

See: https://kubernetes.io/docs/concepts/services-networking/ingress/#simple-fanout

</details>

<details>
<summary>Hint 3 — Host-based Ingress</summary>

```yaml
rules:
- host: app-a.example.com
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: app-a
          port:
            number: 80
```

Test with: `curl -H "Host: app-a.example.com" http://<ingress-ip>/`

See: https://kubernetes.io/docs/concepts/services-networking/ingress/#name-based-virtual-hosting

</details>

<details>
<summary>Hint 4 — TLS termination</summary>

Create a self-signed certificate:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=*.example.com"
kubectl create secret tls example-tls --cert=tls.crt --key=tls.key
```

Then reference it in the Ingress:
```yaml
spec:
  tls:
  - hosts:
    - app-a.example.com
    secretName: example-tls
```

See: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Wait for external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

### Step 2 — (Optional) Delete the direct LoadBalancer

```bash
kubectl delete svc frontend-lb  # The Ingress replaces this
```

### Step 3 — Path-based routing for the Bookstore

```yaml
# bookstore-path-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookstore-paths
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 80
```

```bash
kubectl apply -f bookstore-path-ingress.yaml
curl http://$INGRESS_IP/       # Bookstore frontend (nginx)
curl http://$INGRESS_IP/api    # Bookstore backend (nginx)
```

### Step 4 — Host-based routing

```yaml
# bookstore-host-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookstore-hosts
spec:
  ingressClassName: nginx
  rules:
  - host: bookstore.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
  - host: monitor.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitor-svc.monitoring
            port:
              number: 80
```

```bash
kubectl apply -f bookstore-host-ingress.yaml
curl -H "Host: bookstore.example.com" http://$INGRESS_IP/
curl -H "Host: monitor.example.com" http://$INGRESS_IP/
```

### Step 5 — TLS termination

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=*.example.com"
kubectl create secret tls bookstore-tls --cert=tls.crt --key=tls.key
rm tls.key tls.crt
```

```yaml
# Update bookstore-hosts Ingress to add TLS
# bookstore-host-tls-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookstore-hosts
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - bookstore.example.com
    - monitor.example.com
    secretName: bookstore-tls
  rules:
  - host: bookstore.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
  - host: monitor.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitor-svc.monitoring
            port:
              number: 80
```

```bash
kubectl apply -f bookstore-host-tls-ingress.yaml
curl -k -H "Host: bookstore.example.com" https://$INGRESS_IP/
# Bookstore frontend over HTTPS with self-signed cert
```

> ⚠️ **Do NOT clean up** — the Ingress Controller and routes carry forward to Exercise 09.

### Optional Cleanup (only if starting over)

```bash
kubectl delete ingress bookstore-paths bookstore-hosts
kubectl delete secret bookstore-tls
helm uninstall ingress-nginx -n ingress-nginx
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/ingress/
- https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls

</details>
