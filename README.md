# Certified Kubernetes Network Engineer (CKNE) — Study Guide

This repository contains a **sample exam blueprint** and **hands-on challenge exercises** designed to help you prepare for the Certified Kubernetes Network Engineer certification.

> **Note:** The official CKNE exam blueprint has not been published yet. This material is an approximation based on the [Kubernetes official documentation](https://kubernetes.io/docs/concepts/services-networking/) and related networking topics.

## Structure

| Path | Description |
|------|-------------|
| [blueprint.md](blueprint.md) | Sample exam blueprint with weighted domains |
| [infra/](infra/) | Shared Azure Bicep templates and deployment scripts |
| [exercises/](exercises/) | 13 challenge-driven exercises with hints and solutions |

## Exercise Progression

Exercises 01–10 build on a **single shared AKS cluster** and follow a progressive storyline. Each exercise adds complexity to the environment **without tearing down** the resources from previous exercises. By exercise 10, you'll have a fully-featured environment with services, network policies, ingress, and Gateway API — and you'll need to debug it when things break.

Exercises 11–13 require **separate, specialized clusters** (multi-zone, dual-stack, or kubeadm on VMs) and are standalone.

### Track 1 — Progressive Build (shared cluster)

| # | Exercise | What Gets Added |
|---|----------|----------------|
| 01 | [Pod Networking](exercises/01-pod-networking/README.md) | Deploy `frontend` and `backend` pods, verify flat network |
| 02 | [ClusterIP Services](exercises/02-clusterip-services/README.md) | Add ClusterIP Services for frontend and backend |
| 03 | [External Services](exercises/03-external-services/README.md) | Expose frontend via LoadBalancer, add ExternalName |
| 04 | [Headless Services](exercises/04-headless-services/README.md) | Add a `database` tier with StatefulSet + headless Service |
| 05 | [DNS Resolution](exercises/05-dns-resolution/README.md) | Add `monitoring` namespace, explore cross-namespace DNS |
| 06 | [Network Policy — Ingress](exercises/06-network-policy-ingress/README.md) | Lock down inbound traffic: only frontend→backend→db |
| 07 | [Network Policy — Egress](exercises/07-network-policy-egress/README.md) | Lock down outbound traffic, allow DNS + external APIs |
| 08 | [Ingress Controllers](exercises/08-ingress-controllers/README.md) | Install NGINX Ingress, replace LoadBalancer with Ingress |
| 09 | [Gateway API](exercises/09-gateway-api/README.md) | Add Gateway API as next-gen alternative to Ingress |
| 10 | [Service Debugging](exercises/10-service-debugging/README.md) | Diagnose and fix breakages in the accumulated environment |

### Track 2 — Standalone (separate clusters)

| # | Exercise | Key Topics |
|---|----------|------------|
| 11 | [Topology-Aware Routing](exercises/11-topology-aware-routing/README.md) | Zone-aware traffic, EndpointSlice hints |
| 12 | [Dual-Stack Networking](exercises/12-dual-stack/README.md) | IPv4/IPv6, ipFamilyPolicy, dual-stack services |
| 13 | [CNI Deep Dive](exercises/13-cni-deep-dive/README.md) | kubeadm cluster, install/compare CNI plugins, inspect network plumbing |

## Prerequisites

- An Azure subscription (for deploying lab infrastructure)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed (for exercises 08–09)
- Basic familiarity with Kubernetes concepts (Pods, Deployments, Namespaces)

## Getting Started

1. Review the [blueprint](blueprint.md) to understand the exam domains
2. Deploy the shared AKS infrastructure using the scripts in [infra/](infra/)
3. Work through exercises 01–10 **in order** — each builds on the previous one
4. **Do not clean up** between exercises 01–10 (cleanup is optional at the end of each)
5. Exercises 11–13 can be done in any order — they use separate clusters
6. Use the hints and solutions only when stuck — the challenge format is intentional!
