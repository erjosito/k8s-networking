# CKNE Sample Exam Blueprint

> **Disclaimer:** This is a community-sourced approximation. The official CKNE blueprint has not been published by the CNCF/Linux Foundation at the time of writing. This blueprint is derived from the [Kubernetes official networking documentation](https://kubernetes.io/docs/concepts/services-networking/) and related topics.

## Exam Overview

| Property | Value |
|----------|-------|
| Format | Performance-based (hands-on) |
| Duration | 2 hours (estimated) |
| Passing Score | 66% (estimated) |
| Kubernetes Version | Latest stable |
| Allowed Resources | kubernetes.io/docs, kubernetes.io/blog, helm.sh/docs |

---

## Domain 1 — Kubernetes Network Model Fundamentals (12%)

Understanding the foundational networking model that all Kubernetes clusters implement.

- **1.1** Understand the Kubernetes network model requirements (flat pod network, no NAT between pods)
- **1.2** Understand pod network namespaces and container-to-container communication via localhost
- **1.3** Understand pod-to-pod communication across nodes
- **1.4** Understand the role of the Container Networking Interface (CNI) and CNI plugins
- **1.5** Understand IP address allocation for Pods, Services, and Nodes
- **1.6** Understand `hostNetwork` and `hostPort` for pods that use the node's network namespace

**References:**
- https://kubernetes.io/docs/concepts/services-networking/
- https://kubernetes.io/docs/concepts/cluster-administration/networking/
- https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/

---

## Domain 2 — Services & Service Discovery (18%)

Configuring and managing Kubernetes Services to expose workloads.

- **2.1** Define and configure ClusterIP Services
- **2.2** Define and configure NodePort Services
- **2.3** Define and configure LoadBalancer Services
- **2.4** Understand ExternalName Services
- **2.5** Configure Services without selectors and manual EndpointSlices
- **2.6** Understand Headless Services and their DNS behavior
- **2.7** Understand EndpointSlices and their role in service proxying
- **2.8** Configure `sessionAffinity` on Services
- **2.9** Understand `externalTrafficPolicy` and `internalTrafficPolicy`

**References:**
- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/

---

## Domain 3 — DNS for Services and Pods (10%)

Understanding how Kubernetes DNS works for service discovery.

- **3.1** Understand the DNS naming convention for Services (`<svc>.<ns>.svc.cluster.local`)
- **3.2** Understand DNS records for headless Services (A/AAAA records per Pod)
- **3.3** Understand SRV records for named ports
- **3.4** Understand Pod DNS policies (`ClusterFirst`, `Default`, `None`, `ClusterFirstWithHostNet`)
- **3.5** Configure custom DNS settings using `dnsConfig` on Pods
- **3.6** Understand CoreDNS configuration and customization
- **3.7** Troubleshoot DNS resolution issues

**References:**
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/

---

## Domain 4 — Network Policies (15%)

Controlling traffic flow between pods and external networks.

- **4.1** Understand default pod communication behavior (non-isolated)
- **4.2** Define ingress NetworkPolicies using podSelector, namespaceSelector, and ipBlock
- **4.3** Define egress NetworkPolicies
- **4.4** Understand the additive nature of NetworkPolicies
- **4.5** Implement default-deny ingress and egress policies
- **4.6** Understand the difference between single-selector and multi-selector `from`/`to` rules
- **4.7** Understand NetworkPolicy prerequisites (CNI plugin support)

**References:**
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/

---

## Domain 5 — Ingress (12%)

Configuring HTTP/HTTPS routing into the cluster using Ingress resources.

- **5.1** Understand the Ingress resource and its relationship to Ingress Controllers
- **5.2** Configure path-based routing (Prefix, Exact, ImplementationSpecific)
- **5.3** Configure name-based virtual hosting
- **5.4** Configure TLS termination on Ingress resources
- **5.5** Understand IngressClass and default IngressClass
- **5.6** Understand the difference between Ingress and Services of type LoadBalancer

**References:**
- https://kubernetes.io/docs/concepts/services-networking/ingress/
- https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/

---

## Domain 6 — Gateway API (10%)

Using the next-generation traffic routing API for Kubernetes.

- **6.1** Understand the Gateway API resource model (GatewayClass, Gateway, HTTPRoute, GRPCRoute)
- **6.2** Understand the role-oriented design (Infrastructure Provider, Cluster Operator, App Developer)
- **6.3** Configure HTTPRoute for path-based and header-based routing
- **6.4** Configure traffic splitting and weighted routing
- **6.5** Understand cross-namespace route attachment and ReferenceGrants
- **6.6** Configure GRPCRoute for gRPC traffic routing

**References:**
- https://kubernetes.io/docs/concepts/services-networking/gateway/
- https://gateway-api.sigs.k8s.io/

---

## Domain 7 — Service Proxying & kube-proxy (8%)

Understanding how service traffic is routed at the node level.

- **7.1** Understand the role of kube-proxy in implementing Services
- **7.2** Understand kube-proxy modes (iptables, IPVS, nftables)
- **7.3** Understand how EndpointSlices are consumed by kube-proxy
- **7.4** Understand alternatives to kube-proxy (e.g., Cilium, Calico's eBPF dataplane)

**References:**
- https://kubernetes.io/docs/reference/networking/virtual-ips/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/

---

## Domain 8 — IPv4/IPv6 Dual-Stack (5%)

Configuring clusters and services for dual-stack networking.

- **8.1** Understand dual-stack prerequisites and configuration
- **8.2** Configure Services with `ipFamilyPolicy` (`SingleStack`, `PreferDualStack`, `RequireDualStack`)
- **8.3** Understand `ipFamilies` ordering and its effect on `clusterIP`

**References:**
- https://kubernetes.io/docs/concepts/services-networking/dual-stack/

---

## Domain 9 — Topology-Aware Routing (5%)

Optimizing traffic routing based on network topology.

- **9.1** Understand Topology Aware Routing and the `service.kubernetes.io/topology-mode` annotation
- **9.2** Understand zone-based endpoint allocation in EndpointSlices
- **9.3** Understand safeguards and constraints of topology-aware routing
- **9.4** Understand the `trafficDistribution` Service field (PreferSameZone, PreferSameNode)

**References:**
- https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/

---

## Domain 10 — Network Troubleshooting (5%)

Diagnosing and resolving network-related issues in Kubernetes.

- **10.1** Debug Services using `kubectl describe`, `kubectl get endpoints`, and DNS lookups
- **10.2** Verify pod-to-pod connectivity
- **10.3** Diagnose DNS resolution failures
- **10.4** Identify and resolve NetworkPolicy conflicts
- **10.5** Use tools like `curl`, `wget`, `nslookup`, `dig`, and `tcpdump` from within pods
- **10.6** Use ephemeral containers (`kubectl debug`) to troubleshoot running pods

**References:**
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

---

## Coverage Analysis

### Exercise Mapping

The table below maps each blueprint sub-topic to the exercise(s) where it is practiced, or marks it as theory-only (📖) if no exercise covers it.

| Topic | Exercise(s) | Notes |
|-------|-------------|-------|
| **Domain 1 — Network Model (12%)** | | |
| 1.1 Flat pod network, no NAT | Ex 01 | Core of the exercise |
| 1.2 Pod network namespaces, localhost | Ex 01 | Multi-container pod challenge |
| 1.3 Pod-to-pod across nodes | Ex 01 | Anti-affinity forces cross-node |
| 1.4 CNI and CNI plugins | 📖 | Cluster uses Azure CNI; students don't install/configure CNI directly |
| 1.5 IP allocation for Pods/Services/Nodes | Ex 01, Ex 02 | Observed via `kubectl get pods -o wide` and `kubectl get svc` |
| 1.6 hostNetwork and hostPort | Ex 01 | Bonus challenge: deploy hostNetwork pod, compare IPs |
| **Domain 2 — Services (18%)** | | |
| 2.1 ClusterIP Services | Ex 02 | Core of the exercise |
| 2.2 NodePort Services | Ex 03 | Created and tested |
| 2.3 LoadBalancer Services | Ex 03 | Created with AKS Azure LB |
| 2.4 ExternalName Services | Ex 03 | `external-api` → httpbin.org |
| 2.5 Services without selectors / manual EndpointSlices | Ex 03 | `legacy-db` Service with manual EndpointSlice |
| 2.6 Headless Services | Ex 04 | Core of the exercise |
| 2.7 EndpointSlices | Ex 02, Ex 04 | Inspected and observed |
| 2.8 sessionAffinity | ❌ **Not covered** | Minor topic; could be a bonus challenge |
| 2.9 externalTrafficPolicy / internalTrafficPolicy | Ex 03 | externalTrafficPolicy practiced; internalTrafficPolicy theory only |
| **Domain 3 — DNS (10%)** | | |
| 3.1 DNS naming convention | Ex 02, Ex 05 | Used throughout |
| 3.2 Headless DNS (A/AAAA per pod) | Ex 04 | Individual pod DNS lookups |
| 3.3 SRV records for named ports | Ex 05 | Named port + SRV lookup |
| 3.4 Pod DNS policies | Ex 05 | ClusterFirst and None compared |
| 3.5 Custom dnsConfig | Ex 05 | Custom nameserver tested |
| 3.6 CoreDNS configuration | 📖 | Not directly modified in exercises |
| 3.7 DNS troubleshooting | Ex 05, Ex 10 | Debugging exercise touches DNS |
| **Domain 4 — Network Policies (15%)** | | |
| 4.1 Default non-isolated behavior | Ex 06 | Verified before policies |
| 4.2 Ingress policies (podSelector, namespaceSelector, ipBlock) | Ex 06 | All selector types used |
| 4.3 Egress policies | Ex 07 | Core of the exercise |
| 4.4 Additive nature of policies | Ex 06, Ex 07 | Multiple policies stacked |
| 4.5 Default-deny ingress/egress | Ex 06, Ex 07 | Both created |
| 4.6 Single vs multi-selector rules | Ex 06 | Explained in hints |
| 4.7 CNI plugin support prerequisites | 📖 | Mentioned (Calico required) but not hands-on |
| **Domain 5 — Ingress (12%)** | | |
| 5.1 Ingress resource + controllers | Ex 08 | NGINX Ingress installed |
| 5.2 Path-based routing | Ex 08 | `/` and `/api` paths |
| 5.3 Host-based virtual hosting | Ex 08 | `bookstore.example.com` etc. |
| 5.4 TLS termination | Ex 08 | Self-signed cert + Secret |
| 5.5 IngressClass | Ex 08 | `ingressClassName: nginx` used |
| 5.6 Ingress vs LoadBalancer | Ex 03, Ex 08 | Both used, can compare |
| **Domain 6 — Gateway API (10%)** | | |
| 6.1 Resource model (GatewayClass, Gateway, HTTPRoute) | Ex 09 | All three created |
| 6.2 Role-oriented design | 📖 | Conceptual; explained in hints |
| 6.3 Path + header-based routing | Ex 09 | Both implemented |
| 6.4 Traffic splitting / weighted routing | Ex 09 | 80/20 canary |
| 6.5 Cross-namespace routes / ReferenceGrants | ❌ **Not covered** | Could be a bonus; requires multi-namespace Gateway |
| 6.6 GRPCRoute | Ex 09 | Bonus: create GRPCRoute for gRPC backend |
| **Domain 7 — kube-proxy (8%)** | | |
| 7.1 Role of kube-proxy | 📖 | Implicitly used but not directly examined |
| 7.2 Proxy modes (iptables, IPVS, nftables) | 📖 | AKS uses iptables by default; not switched between modes |
| 7.3 EndpointSlices consumed by kube-proxy | Ex 02 | EndpointSlices observed |
| 7.4 Alternatives (Cilium, eBPF) | 📖 | Mentioned conceptually only |
| **Domain 8 — Dual-Stack (5%)** | | |
| 8.1 Dual-stack prerequisites | Ex 12 | Standalone cluster exercise |
| 8.2 ipFamilyPolicy configuration | Ex 12 | SingleStack, PreferDualStack, RequireDualStack |
| 8.3 ipFamilies ordering | Ex 12 | Tested |
| **Domain 9 — Topology-Aware (5%)** | | |
| 9.1 topology-mode annotation | Ex 11 | Core of the exercise |
| 9.2 Zone-based EndpointSlice allocation | Ex 11 | Observed |
| 9.3 Safeguards and constraints | Ex 11 | Discussed in hints |
| 9.4 trafficDistribution field | Ex 11 | Bonus: PreferSameZone compared with annotation approach |
| **Domain 10 — Troubleshooting (5%)** | | |
| 10.1 Debug Services (describe, endpoints, DNS) | Ex 10 | Core debugging exercise |
| 10.2 Pod-to-pod connectivity | Ex 01, Ex 10 | Verified throughout |
| 10.3 DNS resolution failures | Ex 05, Ex 10 | Tested |
| 10.4 NetworkPolicy conflicts | Ex 10 | Bug 3 is a NetworkPolicy issue |
| 10.5 Debugging tools | Ex 01–Ex 10 | `curl`, `wget`, `nslookup` used throughout |
| 10.6 Ephemeral containers (kubectl debug) | Ex 10 | Attach netshoot to running pod |

### Summary

| Status | Count | Topics |
|--------|-------|--------|
| ✅ Covered by exercises | 40 | Most sub-topics |
| 📖 Theory only (no hands-on) | 7 | 1.4, 3.6, 4.7, 6.2, 7.1, 7.2, 7.4 |
| ❌ Not covered at all | 2 | 2.8, 6.5 |

---

### Kubernetes Networking Topics NOT in the Blueprint

The following networking topics exist in the Kubernetes documentation but were **deliberately excluded or underrepresented** in this blueprint. Each is evaluated below.

#### Included as minor points (no dedicated domain)

| Topic | Status | Reasoning |
|-------|--------|-----------|
| **Service `trafficDistribution`** (PreferSameZone, PreferSameNode) | Closely related to Domain 9 | New in v1.31+. Overlaps with Topology-Aware Routing but uses a different mechanism (Service field vs annotation). **Consider adding to Domain 9** as topic 9.4. |
| **Service discovery via environment variables** | Omitted | Legacy mechanism (`{SVCNAME}_SERVICE_HOST`). DNS-based discovery (Domain 3) is the modern approach. Low exam relevance. |
| **`appProtocol` field on Service ports** | Omitted | Stable since v1.20. Useful for protocol-aware implementations (h2c, WebSocket) but niche. Could be a sub-point under Domain 2. |
| **Multi-port Services** (naming requirements) | Implicitly covered | Named ports are touched in Ex 05 (SRV records). No dedicated topic needed. |
| **ClusterIP allocation** (static vs dynamic bands) | Omitted | Documented at kubernetes.io/docs/concepts/services-networking/cluster-ip-allocation/. Relevant for cluster admins but unlikely exam material. |
| **`kubectl port-forward`** | Omitted | Useful debugging tool but not a networking concept per se. Could be mentioned under Domain 10. |

#### Deliberately excluded — deprecated or obsolete

| Topic | Status | Reasoning |
|-------|--------|-----------|
| **Service `externalIPs`** | **Deprecated in v1.36** | Users should migrate to LoadBalancer or Gateway API. Not appropriate for a forward-looking exam. |
| **Endpoints API** (legacy, replaced by EndpointSlices) | Omitted | EndpointSlices (Domain 2.7) are the modern replacement. Endpoints still exist for backward compatibility but are limited to 1000 entries. |
| **Service Topology** (`topologyKeys` field) | **Removed in v1.22** | Replaced by Topology Aware Routing (Domain 9). |

#### Deliberately excluded — ecosystem/third-party

| Topic | Status | Reasoning |
|-------|--------|-----------|
| **Service Mesh** (Istio, Linkerd, Consul) | Excluded | These are CNCF ecosystem projects, not core Kubernetes APIs. A CKNE exam would focus on native K8s APIs. Service mesh concepts could appear as a bonus domain if the exam scope includes ecosystem tools. |
| **eBPF deep dive** (Cilium dataplane) | Excluded | Mentioned briefly in 7.4 as an alternative to kube-proxy. Deep eBPF knowledge is Cilium-specific, not Kubernetes-native. |
| **Multus / multi-network** (NetworkAttachmentDefinition) | Excluded | CRD-based multi-network support. Not a core K8s API. May be relevant if the exam covers advanced CNI scenarios. |
| **CNI plugin installation/configuration** | Excluded | Varies by distribution (Calico, Cilium, Flannel, Weave, Azure CNI). Exam would test concepts (Domain 1.4), not specific plugin setup. |

#### Deliberately excluded — niche or out-of-scope

| Topic | Status | Reasoning |
|-------|--------|-----------|
| **SCTP protocol support** | Excluded | Niche protocol. Services support TCP/UDP/SCTP but SCTP is rarely used and requires kernel support. |
| **Windows networking** | Excluded | Windows nodes have different networking semantics (no hostNetwork pod-to-pod). Important for mixed clusters but unlikely primary exam material. |
| **`hostNetwork` / `hostPort`** | Underrepresented | These are valid networking primitives (Pod uses node's network namespace). **Consider adding to Domain 1** as topic 1.6. Commonly needed for DaemonSets (monitoring, ingress controllers). |
| **GRPCRoute / TLSRoute / TCPRoute** (Gateway API) | Excluded | HTTPRoute is the primary route type. GRPCRoute is GA in Gateway API v1.2.0. **Consider adding GRPCRoute to Domain 6** as topic 6.6 if the exam covers Gateway API broadly. |
| **Internal load balancers** (cloud annotations) | Excluded | Cloud-provider-specific annotations (`service.beta.kubernetes.io/azure-load-balancer-internal`). Implementation-specific, not portable Kubernetes knowledge. |
| **LoadBalancer IP mode** (VIP vs Proxy) | Excluded | Cloud-provider implementation detail. |
| **Ephemeral containers** for debugging | Underrepresented | `kubectl debug` with ephemeral containers is increasingly important for troubleshooting. **Consider adding to Domain 10** as topic 10.6. |

### Recommendations

Based on this analysis, the following topics were added to strengthen the blueprint:

1. ✅ **Domain 1 — Added 1.6: `hostNetwork` and `hostPort`** — Bonus challenge in Exercise 01. Referenced at https://kubernetes.io/docs/concepts/services-networking/
2. ✅ **Domain 2 — Added exercise for 2.5: Services without selectors** — `legacy-db` Service with manual EndpointSlice in Exercise 03.
3. ✅ **Domain 6 — Added 6.6: GRPCRoute** — Bonus challenge in Exercise 09. GA since Gateway API v1.2.0.
4. ✅ **Domain 9 — Added 9.4: `trafficDistribution` field** — Bonus challenge in Exercise 11 comparing with annotation approach.
5. ✅ **Domain 10 — Added 10.6: Ephemeral containers (`kubectl debug`)** — Added to Exercise 10 debugging workflow.

**Remaining gap:** Topic 2.8 (sessionAffinity) and 6.5 (cross-namespace ReferenceGrants) are minor topics that could be added as bonus challenges in future iterations.
