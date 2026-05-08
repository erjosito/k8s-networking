#!/bin/bash
# ============================================================================
# Exercise 02 — ClusterIP Services: Verification Script
# ============================================================================
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if eval "$@" &>/dev/null; then
    echo "  ✅ $desc"; ((PASS++))
  else
    echo "  ❌ $desc"; ((FAIL++))
  fi
}

echo "=== Exercise 02: ClusterIP Services ==="
echo ""

echo "— Challenge 1: Replace pods with Deployments —"
check "Deployment 'frontend' exists" \
  "kubectl get deployment frontend"
check "Deployment 'backend' exists" \
  "kubectl get deployment backend"

echo ""
echo "— Challenge 2: Create ClusterIP Services —"
check "Service 'frontend-svc' exists with type ClusterIP" \
  "kubectl get svc frontend-svc -o jsonpath='{.spec.type}' | grep -qE '^ClusterIP$|^$'"
check "Service 'backend-svc' exists with type ClusterIP" \
  "kubectl get svc backend-svc -o jsonpath='{.spec.type}' | grep -qE '^ClusterIP$|^$'"

echo ""
echo "— Challenge 3: Service connectivity and DNS —"
BACKEND_SVC_IP=$(kubectl get svc backend-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
BACKEND_SVC_PORT=$(kubectl get svc backend-svc -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
if [[ -n "$BACKEND_SVC_IP" && -n "$BACKEND_SVC_PORT" ]]; then
  check "Can reach backend-svc via ClusterIP ($BACKEND_SVC_IP:$BACKEND_SVC_PORT)" \
    "kubectl run verify-svc --rm -i --restart=Never --image=busybox -- wget -qO- --timeout=5 http://$BACKEND_SVC_IP:$BACKEND_SVC_PORT 2>/dev/null"
fi
check "Can resolve backend-svc via DNS" \
  "kubectl run verify-dns --rm -i --restart=Never --image=busybox -- nslookup backend-svc.default.svc.cluster.local 2>/dev/null"

echo ""
echo "— Challenge 4: EndpointSlices —"
check "EndpointSlice exists for backend-svc" \
  "kubectl get endpointslices -l kubernetes.io/service-name=backend-svc"

echo ""
echo "— Challenge 5: Scale backend to 5 replicas —"
REPLICAS=$(kubectl get deployment backend -o jsonpath='{.spec.replicas}' 2>/dev/null)
check "Backend deployment has 5 replicas" \
  "[[ '$REPLICAS' == '5' ]]"
READY=$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
check "All 5 backend replicas are ready" \
  "[[ '$READY' == '5' ]]"

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
