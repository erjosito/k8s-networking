#!/bin/bash
# ============================================================================
# Exercise 04 — Headless Services & StatefulSet DNS: Verification Script
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

echo "=== Exercise 04: Headless Services & StatefulSet DNS ==="
echo ""

echo "— Challenge 1: Headless Service —"
check "Service 'database-svc' exists" \
  "kubectl get svc database-svc"
CLUSTER_IP=$(kubectl get svc database-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
check "database-svc is headless (clusterIP=None)" \
  "[[ '$CLUSTER_IP' == 'None' ]]"

echo ""
echo "— Challenge 2: StatefulSet —"
check "StatefulSet 'database' exists" \
  "kubectl get statefulset database"
REPLICAS=$(kubectl get statefulset database -o jsonpath='{.spec.replicas}' 2>/dev/null)
check "StatefulSet has 3 replicas" \
  "[[ '$REPLICAS' == '3' ]]"
READY=$(kubectl get statefulset database -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
check "All 3 StatefulSet replicas are ready" \
  "[[ '$READY' == '3' ]]"

echo ""
echo "— Challenge 3: DNS resolution —"
check "DNS resolves database-svc to multiple pod IPs" \
  "kubectl run verify-headless-dns --rm -i --restart=Never --image=busybox -- nslookup database-svc 2>/dev/null | grep -c 'Address' | grep -q '[2-9]'"

echo ""
echo "— Challenge 4: Individual pod DNS —"
check "Pod 'database-0' exists" "kubectl get pod database-0"
check "Pod 'database-1' exists" "kubectl get pod database-1"
check "Pod 'database-2' exists" "kubectl get pod database-2"
check "DNS resolves database-0.database-svc" \
  "kubectl run verify-pod-dns --rm -i --restart=Never --image=busybox -- nslookup database-0.database-svc 2>/dev/null | grep -q Address"

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
