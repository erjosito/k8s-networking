# Exercise 13 — CNI Deep Dive

**Blueprint Domain:** 1 — Kubernetes Network Model Fundamentals (topics 1.4, 1.5)  
**Standalone Exercise** — uses kubeadm on Azure VMs (not AKS)

> **Why not AKS?** Managed Kubernetes services like AKS abstract away the CNI — it's pre-installed and configured. To truly understand how CNI works, you need a cluster where you install it yourself. This exercise uses `kubeadm` on raw VMs so you can see the cluster in a "no CNI" state and manually bring networking to life.

## Objective

Understand the Container Networking Interface (CNI) by bootstrapping a Kubernetes cluster **without a CNI plugin**, observing what breaks, installing a CNI plugin manually, and inspecting the network plumbing it creates.

## Challenge

1. Deploy 3 Azure VMs and bootstrap a Kubernetes cluster with `kubeadm` (the deploy script handles VM setup; you run `kubeadm`).
2. After `kubeadm init`, observe that nodes are **NotReady** and the CoreDNS pods are **Pending** — explain why.
3. Inspect `/etc/cni/net.d/` and `/opt/cni/bin/` on a node — describe what you find (and don't find).
4. Install **Calico** as the CNI plugin. Watch nodes become **Ready** and CoreDNS pods start.
5. Inspect the network changes Calico made:
   - What files appeared in `/etc/cni/net.d/`?
   - What network interfaces were created (`ip link show`)?
   - What routes were added (`ip route show`)?
6. Deploy two pods on **different nodes** and verify pod-to-pod connectivity by IP.
7. **Bonus — Compare CNIs:** Remove the cluster (`kubeadm reset`), re-init, and install **Flannel** instead. Compare the network interfaces, routes, and CNI config files with what Calico created.

## Success Criteria

- [ ] You can explain why nodes are NotReady without a CNI plugin
- [ ] You identified the CNI config directory (`/etc/cni/net.d/`) and binary directory (`/opt/cni/bin/`)
- [ ] Calico (or another CNI) is installed and all nodes are Ready
- [ ] You can describe the network interfaces and routes the CNI plugin created
- [ ] Pod-to-pod communication works across nodes
- [ ] (Bonus) You can articulate at least 2 differences between Calico and Flannel's network setup

## Infrastructure

**Cluster:** This exercise requires **3 Azure VMs** (1 control-plane + 2 workers) — not AKS.

### Deploy script

```bash
cd exercises/13-cni-deep-dive
bash deploy-vms.sh [resource-group] [location] [ssh-public-key-path]
# Defaults: ckne-cni-lab, swedencentral, ~/.ssh/id_rsa.pub
```

The script deploys 3 Ubuntu 22.04 VMs with:
- containerd pre-installed and configured
- kubeadm, kubelet, kubectl installed
- Kernel modules and sysctl settings for Kubernetes
- **No CNI plugin** — that's your job!

Wait ~5 minutes for cloud-init to complete, then SSH to the control-plane VM.

### Bicep template

See [`kubeadm-cluster.bicep`](kubeadm-cluster.bicep) for the full infrastructure template.

---

## Hints

<details>
<summary>Hint 1 — Initialize the control plane</summary>

SSH to the control-plane VM and run:

```bash
# Check cloud-init is done
cloud-init status --wait

# Initialize the cluster (use the VM's private IP)
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$PRIVATE_IP

# Set up kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

The `--pod-network-cidr` flag tells Kubernetes which CIDR to use for pod IPs. Different CNI plugins expect different CIDRs (Flannel defaults to `10.244.0.0/16`, Calico to `192.168.0.0/16`).

Save the `kubeadm join` command from the output — you'll need it for the workers.

See: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

</details>

<details>
<summary>Hint 2 — Why nodes are NotReady</summary>

```bash
kubectl get nodes
# NAME          STATUS     ROLES           AGE   VERSION
# ckne-cni-cp   NotReady   control-plane   1m    v1.30.x
```

The kubelet reports NotReady because no CNI plugin is installed. Without a CNI, the kubelet can't configure pod networking, so it marks the node as not ready.

Check the kubelet logs:
```bash
sudo journalctl -u kubelet | grep -i cni
# "Network plugin returns error: cni plugin not initialized"
```

CoreDNS pods will be Pending because they need the network to be ready:
```bash
kubectl get pods -n kube-system
# coredns-xxx   0/1   Pending   0   1m
```

See: https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/

</details>

<details>
<summary>Hint 3 — Inspect CNI directories (before install)</summary>

```bash
# CNI configuration directory — may be empty or have only a loopback config
ls -la /etc/cni/net.d/

# CNI binary directory — contains the base CNI binaries (bridge, host-local, loopback, etc.)
ls -la /opt/cni/bin/
```

The CNI spec defines two key directories:
- `/etc/cni/net.d/` — JSON config files that tell the kubelet which plugin to use
- `/opt/cni/bin/` — the actual plugin binaries

Without a network plugin config in `/etc/cni/net.d/`, the kubelet can't set up pod networking.

See: https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/#cni

</details>

<details>
<summary>Hint 4 — Install Calico</summary>

```bash
# Install the Calico operator and CRDs
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

# Install Calico with custom pod CIDR
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
```

If you used `--pod-network-cidr=10.244.0.0/16`, edit the `custom-resources.yaml` to match:
```bash
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
sed -i 's|192.168.0.0/16|10.244.0.0/16|' custom-resources.yaml
kubectl create -f custom-resources.yaml
```

Watch the nodes become Ready:
```bash
kubectl get nodes -w
```

See: https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart

</details>

<details>
<summary>Hint 5 — Inspect Calico's network plumbing</summary>

After Calico is installed, inspect what changed:

```bash
# New CNI config file
cat /etc/cni/net.d/10-calico.conflist

# New network interfaces (cali* = veth pairs for pods, tunl0 = IPIP tunnel)
ip link show | grep -E 'cali|tunl|vxlan'

# Routes — Calico adds routes for each node's pod CIDR
ip route show | grep -E 'cali|tunl|bird'

# Calico-specific: check the BGP peering (if using BGP mode)
# sudo calicoctl node status   # (if calicoctl is installed)
```

Key things to notice:
- Each pod gets a `cali*` veth pair connecting it to the host
- Routes point pod CIDRs on other nodes through IPIP tunnels (`tunl0`) or direct BGP
- The CNI config in `/etc/cni/net.d/` tells kubelet to use the `calico` binary

</details>

<details>
<summary>Hint 6 — Join worker nodes</summary>

SSH to each worker VM and run the `kubeadm join` command from Step 1:

```bash
sudo kubeadm join <control-plane-private-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

If you lost the join command, regenerate the token on the control plane:
```bash
kubeadm token create --print-join-command
```

</details>

<details>
<summary>Hint 7 — Compare with Flannel (Bonus)</summary>

To reset and try Flannel:

```bash
# On all nodes:
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d/*

# On control plane, re-init:
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$PRIVATE_IP

# Install Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Compare with Calico:
- CNI config: `cat /etc/cni/net.d/10-flannel.conflist` (simpler than Calico's)
- Interfaces: `flannel.1` (VXLAN) instead of `tunl0` (IPIP)
- Routes: Flannel uses VXLAN overlay; Calico uses IPIP or BGP
- Flannel is simpler but doesn't support NetworkPolicy; Calico does

</details>

---

## Solution

<details>
<summary>Full Solution</summary>

### Step 1 — Deploy VMs and initialize the cluster

```bash
# Deploy the infrastructure
cd exercises/13-cni-deep-dive
bash deploy-vms.sh

# SSH to the control plane (use the IP from the script output)
ssh azureuser@<control-plane-ip>

# Wait for cloud-init
cloud-init status --wait

# Initialize the cluster
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$PRIVATE_IP

# Set up kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Save the join command for later!
```

### Step 2 — Observe the broken state (no CNI)

```bash
kubectl get nodes
# STATUS: NotReady — no CNI plugin

kubectl get pods -n kube-system
# CoreDNS pods: Pending — can't schedule without networking

# Check kubelet logs
sudo journalctl -u kubelet --no-pager | grep -i "cni" | tail -5
# "cni plugin not initialized"

# Inspect CNI directories
ls -la /etc/cni/net.d/
# Empty or only loopback — no network plugin config

ls -la /opt/cni/bin/
# Base binaries exist (bridge, host-local, loopback) but no calico/flannel
```

### Step 3 — Install Calico

```bash
# Download and adjust the pod CIDR to match kubeadm init
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
sed -i 's|192.168.0.0/16|10.244.0.0/16|' custom-resources.yaml
kubectl create -f custom-resources.yaml

# Watch nodes become Ready
kubectl get nodes -w
# Wait until STATUS changes to Ready

# CoreDNS should now be Running
kubectl get pods -n kube-system
```

### Step 4 — Inspect the network plumbing

```bash
# CNI config file created by Calico
cat /etc/cni/net.d/10-calico.conflist
# Shows: plugin type "calico", IPAM type "calico-ipam"

# Network interfaces
ip link show | grep -E 'cali|tunl|vxlan'
# tunl0: IPIP tunnel interface
# cali*: veth pairs for each pod on this node

# Routes
ip route show
# 10.244.x.x/26 via <other-node-ip> dev tunl0  (pod CIDR routes to other nodes)
# 10.244.y.y/32 dev cali*  (local pod routes)

# New binaries
ls /opt/cni/bin/ | grep calico
# calico, calico-ipam
```

### Step 5 — Join workers and test pod-to-pod

```bash
# On each worker VM:
ssh azureuser@<worker-ip>
sudo kubeadm join <control-plane-private-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Back on control plane — verify all nodes
kubectl get nodes
# All 3 nodes should be Ready

# Deploy test pods on different nodes
kubectl run pod-a --image=nginx:stable --overrides='{"spec":{"nodeName":"ckne-cni-w1"}}'
kubectl run pod-b --image=nginx:stable --overrides='{"spec":{"nodeName":"ckne-cni-w2"}}'
kubectl wait --for=condition=Ready pod/pod-a pod/pod-b

# Test connectivity
POD_B_IP=$(kubectl get pod pod-b -o jsonpath='{.status.podIP}')
kubectl exec pod-a -- curl -s $POD_B_IP
# Should return the nginx welcome page — pod-to-pod networking works!

# Verify source IP (no NAT)
kubectl logs pod-b | tail -1
# Should show pod-a's IP as the client
```

### Step 6 — Compare with Flannel (Bonus)

```bash
# Reset the cluster on ALL nodes
# On workers first:
ssh azureuser@<worker-ip> "sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d/*"

# On control plane:
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d/*

# Re-initialize
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$PRIVATE_IP
mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config

# Install Flannel instead of Calico
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for Ready, then compare:
cat /etc/cni/net.d/10-flannel.conflist
# Simpler config: plugin type "flannel", delegate to "bridge"

ip link show | grep flannel
# flannel.1 — VXLAN interface (vs Calico's tunl0 IPIP)

ip route show
# 10.244.x.0/24 via 10.244.x.0 dev flannel.1 onlink
# (VXLAN overlay routes vs Calico's IPIP tunnel routes)
```

**Key differences:**

| Aspect | Calico | Flannel |
|--------|--------|---------|
| Overlay | IPIP tunnel (`tunl0`) or none (BGP) | VXLAN (`flannel.1`) |
| Interface per pod | `cali*` veth pairs | `veth*` via bridge |
| NetworkPolicy | ✅ Supported natively | ❌ Not supported |
| Routing | BGP or IPIP | VXLAN overlay |
| CNI config | `10-calico.conflist` | `10-flannel.conflist` |
| Complexity | More complex, more features | Simpler, fewer features |

### Cleanup

```bash
az group delete --name ckne-cni-lab --yes --no-wait
```

**References:**
- https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy
- https://www.cni.dev/docs/spec/

</details>
