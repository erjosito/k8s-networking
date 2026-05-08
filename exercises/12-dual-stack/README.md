# Exercise 12 — IPv4/IPv6 Dual-Stack Networking

**Blueprint Domain:** 8 — IPv4/IPv6 Dual-Stack

## Objective

Configure and test dual-stack networking on a Kubernetes cluster, where pods and services can have both IPv4 and IPv6 addresses simultaneously.


> **💡 Tip:** You can save your YAML manifests and notes in the `solution/` folder within this exercise directory — it is git-ignored and won't be committed.

## Challenge

1. Deploy a dual-stack AKS cluster (use the Bicep template below).
2. Verify that pods receive both an IPv4 and an IPv6 address.
3. Create a Service with `ipFamilyPolicy: PreferDualStack` — verify it gets both IPv4 and IPv6 cluster IPs.
4. Create a Service with `ipFamilyPolicy: RequireDualStack` and `ipFamilies: [IPv6, IPv4]` — verify IPv6 is the primary cluster IP.
5. Create a Service with `ipFamilyPolicy: SingleStack` and `ipFamilies: [IPv4]` — verify it only gets an IPv4 address.
6. Test connectivity over both IPv4 and IPv6 from within the cluster.

## Success Criteria

- [ ] Pods have both IPv4 and IPv6 addresses in `pod.status.podIPs`
- [ ] `PreferDualStack` Service has two cluster IPs
- [ ] `RequireDualStack` with `[IPv6, IPv4]` uses IPv6 as primary `clusterIP`
- [ ] `SingleStack` Service has only one cluster IP
- [ ] Both IPv4 and IPv6 connectivity works pod-to-service

## Infrastructure

**Cluster:** This exercise requires a **dual-stack AKS cluster**.

> **Note:** AKS dual-stack support requires Azure CNI Overlay or Azure CNI with dual-stack VNet. Check [AKS dual-stack documentation](https://learn.microsoft.com/en-us/azure/aks/configure-kubenet-dual-stack) for the latest requirements.

### Dual-Stack AKS Bicep Template

```bicep
// exercises/12-dual-stack/aks-dualstack.bicep

@description('Azure region')
param location string = 'swedencentral'

param clusterName string = 'ckne-dualstack'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${clusterName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
        'fd00:db8::/48'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefixes: [
            '10.240.0.0/16'
            'fd00:db8:1::/64'
          ]
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: clusterName
    kubernetesVersion: '1.30'
    agentPoolProfiles: [
      {
        name: 'default'
        count: 3
        vmSize: 'Standard_D2s_v5'
        mode: 'System'
        osType: 'Linux'
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      ipFamilies: ['IPv4', 'IPv6']
      serviceCidrs: ['10.0.0.0/16', 'fd00:db8:2::/112']
      dnsServiceIP: '10.0.0.10'
    }
  }
}

output clusterName string = aks.name
```

### Deploy script

```bash
#!/bin/bash
RG="${1:-ckne-dualstack-lab}"
LOCATION="${2:-swedencentral}"

az group create --name "$RG" --location "$LOCATION" --output none
az deployment group create \
  --resource-group "$RG" \
  --template-file aks-dualstack.bicep \
  --output none

az aks get-credentials --resource-group "$RG" --name ckne-dualstack --overwrite-existing
kubectl get nodes
```

> **Note:** Dual-stack AKS configurations may vary by Azure CNI version. If the Bicep template above doesn't work with your Azure subscription, refer to the latest [AKS documentation](https://learn.microsoft.com/en-us/azure/aks/configure-kubenet-dual-stack) and adjust accordingly.

---

## Hints

<details>
<summary>Hint 1 — Verify pod dual-stack addresses</summary>

```bash
kubectl get pod <name> -o jsonpath='{.status.podIPs}'
```

You should see two entries: one IPv4 and one IPv6 address.

See: https://kubernetes.io/docs/concepts/services-networking/dual-stack/

</details>

<details>
<summary>Hint 2 — ipFamilyPolicy options</summary>

- `SingleStack` — single IP family (default)
- `PreferDualStack` — dual-stack if available, fallback to single
- `RequireDualStack` — must be dual-stack, fails if not supported

The `ipFamilies` field controls which family is primary:
```yaml
spec:
  ipFamilyPolicy: RequireDualStack
  ipFamilies:
  - IPv6
  - IPv4
```

See: https://kubernetes.io/docs/concepts/services-networking/dual-stack/#services

</details>

<details>
<summary>Hint 3 — Inspecting dual-stack Service IPs</summary>

```bash
kubectl get svc <name> -o jsonpath='{.spec.clusterIPs}'
# Returns array like: ["10.0.1.5","fd00:db8:2::1a"]

kubectl get svc <name> -o jsonpath='{.spec.clusterIP}'
# Returns the PRIMARY IP (first in ipFamilies)
```

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Deploy dual-stack cluster

Follow the deploy script in the Infrastructure section.

### Step 2 — Deploy a workload and verify dual-stack pods

```bash
kubectl create deployment web --image=nginx:stable --replicas=3
kubectl wait --for=condition=Available deployment/web

# Check pod IPs
kubectl get pods -l app=web -o custom-columns=\
NAME:.metadata.name,IPs:.status.podIPs[*].ip
# Each pod should show both an IPv4 and IPv6 address
```

### Step 3 — PreferDualStack Service

```yaml
# dual-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-dualstack
spec:
  ipFamilyPolicy: PreferDualStack
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f dual-svc.yaml
kubectl get svc web-dualstack -o jsonpath='{.spec.clusterIPs}'
# Should show two IPs: [IPv4, IPv6]
```

### Step 4 — RequireDualStack with IPv6 primary

```yaml
# ipv6-primary-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-ipv6-primary
spec:
  ipFamilyPolicy: RequireDualStack
  ipFamilies:
  - IPv6
  - IPv4
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f ipv6-primary-svc.yaml
kubectl get svc web-ipv6-primary -o jsonpath='{.spec.clusterIP}'
# Should be an IPv6 address (primary)
kubectl get svc web-ipv6-primary -o jsonpath='{.spec.clusterIPs}'
# Should show [IPv6, IPv4]
```

### Step 5 — SingleStack IPv4

```yaml
# ipv4-only-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-ipv4-only
spec:
  ipFamilyPolicy: SingleStack
  ipFamilies:
  - IPv4
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f ipv4-only-svc.yaml
kubectl get svc web-ipv4-only -o jsonpath='{.spec.clusterIPs}'
# Should show only one IPv4 address
```

### Step 6 — Test connectivity

```bash
kubectl run test --rm -it --image=busybox:1.36 --restart=Never -- sh

# Inside the pod:
# Test IPv4
wget -qO- http://web-dualstack

# Test IPv6 (use the IPv6 cluster IP)
IPV6=$(kubectl get svc web-dualstack -o jsonpath='{.spec.clusterIPs[1]}' 2>/dev/null)
wget -qO- http://[$IPV6]
```

### Cleanup

```bash
az group delete --name ckne-dualstack-lab --yes --no-wait
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/dual-stack/
- https://learn.microsoft.com/en-us/azure/aks/configure-kubenet-dual-stack

</details>
