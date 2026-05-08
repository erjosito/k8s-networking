#!/bin/bash
# ============================================================================
# Exercise 05 — DNS Resolution in Kubernetes: Verification Script
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

echo "=== Exercise 05: DNS Resolution in Kubernetes ==="
echo ""

echo "— Challenge 1: monitoring namespace and resources —"
check "Namespace 'monitoring' exists" \
  "kubectl get namespace monitoring"
check "Deployment or Pod 'monitor' exists in monitoring" \
  "kubectl get deployment monitor -n monitoring 2>/dev/null || kubectl get pod -l app=monitor -n monitoring 2>/dev/null | grep -q Running"
check "Service 'monitor-svc' exists in monitoring" \
  "kubectl get svc monitor-svc -n monitoring"

echo ""
echo "— Challenge 2: Cross-namespace DNS resolution —"
check "Can resolve backend-svc (short name from default ns)" \
  "kubectl run verify-short --rm -i --restart=Never --image=busybox -- nslookup backend-svc 2>/dev/null | grep -q Address"
check "Can resolve monitor-svc.monitoring (cross-namespace)" \
  "kubectl run verify-cross --rm -i --restart=Never --image=busybox -- nslookup monitor-svc.monitoring 2>/dev/null | grep -q Address"

echo ""
echo "— Challenge 3: SRV records (named port) —"
NAMED_PORT=$(kubectl get svc backend-svc -o jsonpath='{.spec.ports[0].name}' 2>/dev/null)
check "backend-svc has a named port defined" \
  "[[ -n '$NAMED_PORT' ]]"

echo ""
echo "— Challenge 4: Custom DNS pod —"
if kubectl get pod custom-dns &>/dev/null; then
  DNS_POLICY=$(kubectl get pod custom-dns -o jsonpath='{.spec.dnsPolicy}' 2>/dev/null)
  check "Pod 'custom-dns' exists" "true"
  check "custom-dns has dnsPolicy=None" \
    "[[ '$DNS_POLICY' == 'None' ]]"
else
  echo "  ❌ Pod 'custom-dns' not found"; ((FAIL++))
fi

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
