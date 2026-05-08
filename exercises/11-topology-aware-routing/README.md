# Exercise 11 — Topology-Aware Routing

**Blueprint Domain:** 9 — Topology-Aware Routing

## Objective

Configure Topology Aware Routing to keep service traffic within the same availability zone, reducing latency and cross-zone data transfer costs.


> **💡 Tip:** You can save your YAML manifests and notes in the `solution/` folder within this exercise directory — it is git-ignored and won't be committed.

## Challenge

1. Deploy an AKS cluster with nodes spread across **3 availability zones** (use the multi-zone Bicep template below).
2. Deploy a Deployment with 6 replicas and a ClusterIP Service.
3. Verify pods are distributed across the 3 zones.
4. Enable **Topology Aware Routing** on the Service using the `service.kubernetes.io/topology-mode: Auto` annotation.
5. Inspect the EndpointSlice and verify that `hints.forZones` are populated.
6. From a client pod, make repeated requests to the Service and observe that responses come **preferentially from pods in the same zone**.
7. **Bonus — `trafficDistribution`:** Set `.spec.trafficDistribution` to `PreferSameZone` on a **second** Service. Compare this field-based approach with the annotation-based topology mode.

## Success Criteria

- [ ] Cluster has nodes in 3 availability zones
- [ ] Pods are distributed across zones
- [ ] EndpointSlice has zone hints after enabling topology-aware routing
- [ ] Traffic stays within the same zone (majority of responses from co-located pods)
- [ ] (Bonus) `trafficDistribution: PreferSameZone` achieves similar zone-local behavior

## Infrastructure

**Cluster:** This exercise requires a **multi-zone AKS cluster** (different from the shared cluster).

### Multi-Zone AKS Bicep Template

```bicep
// exercises/11-topology-aware-routing/aks-multizone.bicep

@description('Azure region (must support availability zones)')
param location string = 'swedencentral'

param clusterName string = 'ckne-multizone'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${clusterName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/8'] }
    subnets: [{ name: 'aks-subnet', properties: { addressPrefix: '10.240.0.0/16' } }]
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
        availabilityZones: ['1', '2', '3']  // Spread across 3 zones
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
  }
}

output clusterName string = aks.name
```

### Deploy script

```bash
#!/bin/bash
RG="${1:-ckne-multizone-lab}"
LOCATION="${2:-swedencentral}"

az group create --name "$RG" --location "$LOCATION" --output none
az deployment group create \
  --resource-group "$RG" \
  --template-file aks-multizone.bicep \
  --output none

az aks get-credentials --resource-group "$RG" --name ckne-multizone --overwrite-existing
kubectl get nodes -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone
```

---

## Hints

<details>
<summary>Hint 1 — Check node zones</summary>

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

Each node should show a zone label like `swedencentral-1`, `swedencentral-2`, `swedencentral-3`.

</details>

<details>
<summary>Hint 2 — Enable Topology Aware Routing</summary>

```bash
kubectl annotate svc my-service service.kubernetes.io/topology-mode=Auto
```

See: https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/

</details>

<details>
<summary>Hint 3 — Inspect EndpointSlice hints</summary>

```bash
kubectl get endpointslices -l kubernetes.io/service-name=my-service -o yaml
```

Look for the `hints.forZones` field on each endpoint. It should indicate which zone should receive traffic for that endpoint.

</details>

<details>
<summary>Hint 4 — Test zone-affinity</summary>

Deploy a client pod and check which zone it's in:
```bash
kubectl get pod client -o jsonpath='{.spec.nodeName}'
kubectl get node <node-name> -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'
```

Then make requests and correlate the responding pod's node zone.

</details>

<details>
<summary>Hint 5 — trafficDistribution field (Bonus)</summary>

Instead of the annotation `service.kubernetes.io/topology-mode`, you can use the Service spec field `.spec.trafficDistribution`. Available values:

- `PreferSameZone` — prefer endpoints in the same zone as the client
- `PreferSameNode` — prefer endpoints on the same node as the client

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zone-app-td
spec:
  selector:
    app: zone-app
  ports:
  - port: 80
    targetPort: 9376
  trafficDistribution: PreferSameZone
```

This is a newer alternative (v1.31+) to the annotation. It expresses a **preference**, not a guarantee.

See: https://kubernetes.io/docs/concepts/services-networking/service/#traffic-distribution

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Deploy multi-zone cluster

Follow the deploy script in the Infrastructure section above.

### Step 2 — Deploy application

```bash
kubectl create deployment zone-app --image=registry.k8s.io/serve_hostname --replicas=6
kubectl expose deployment zone-app --port=80 --target-port=9376
```

### Step 3 — Verify zone distribution

```bash
kubectl get pods -l app=zone-app -o custom-columns=\
NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP

# Check which zone each node is in
kubectl get nodes -L topology.kubernetes.io/zone
```

### Step 4 — Enable Topology Aware Routing

```bash
kubectl annotate svc zone-app service.kubernetes.io/topology-mode=Auto
```

### Step 5 — Verify EndpointSlice hints

```bash
kubectl get endpointslices -l kubernetes.io/service-name=zone-app -o yaml | grep -A2 hints
# Should show forZones entries mapping endpoints to specific zones
```

### Step 6 — Test zone-local traffic

```bash
# Deploy a client pod
kubectl run client --image=busybox:1.36 --command -- sleep 3600
kubectl wait --for=condition=Ready pod/client

# Find which zone the client is in
CLIENT_NODE=$(kubectl get pod client -o jsonpath='{.spec.nodeName}')
CLIENT_ZONE=$(kubectl get node $CLIENT_NODE -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
echo "Client is in zone: $CLIENT_ZONE"

# Make repeated requests
kubectl exec client -- sh -c 'for i in $(seq 1 20); do wget -qO- http://zone-app; echo; done'

# Cross-reference responding hostnames with pod locations
# Most responses should come from pods in $CLIENT_ZONE
```

### Step 7 — trafficDistribution (Bonus)

```bash
# Create a second service with trafficDistribution instead of the annotation
kubectl expose deployment zone-app --port=80 --target-port=9376 --name=zone-app-td
kubectl patch svc zone-app-td --type merge -p '{"spec":{"trafficDistribution":"PreferSameZone"}}'

# Verify the field is set
kubectl get svc zone-app-td -o jsonpath='{.spec.trafficDistribution}'
# Should show: PreferSameZone

# Test — traffic should prefer same-zone pods (similar to the annotation approach)
kubectl exec client -- sh -c 'for i in $(seq 1 20); do wget -qO- http://zone-app-td; echo; done'

# Compare: the annotation-based service uses EndpointSlice hints,
# while trafficDistribution is a higher-level preference.
# Check if EndpointSlice hints differ:
kubectl get endpointslices -l kubernetes.io/service-name=zone-app-td -o yaml | grep -A2 hints
```

### Cleanup

```bash
az group delete --name ckne-multizone-lab --yes --no-wait
```

**References:**
- https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/

</details>
