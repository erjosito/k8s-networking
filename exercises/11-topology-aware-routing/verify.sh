#!/bin/bash
# ============================================================================
# Exercise 11 — Topology-Aware Routing: Verification Script
# ============================================================================
set -uo pipefail

PASS=0; FAIL=0; BONUS_PASS=0; BONUS_FAIL=0

check() {
  local desc="$1"; shift
  if eval "$@" &>/dev/null; then
    echo "  ✅ $desc"; ((PASS++))
  else
    echo "  ❌ $desc"; ((FAIL++))
  fi
}

bonus() {
  local desc="$1"; shift
  if eval "$@" &>/dev/null; then
    echo "  🌟 (bonus) $desc"; ((BONUS_PASS++))
  else
    echo "  ⬜ (bonus) $desc — skipped or not yet done"; ((BONUS_FAIL++))
  fi
}

echo "=== Exercise 11: Topology-Aware Routing ==="
echo ""

echo "— Challenge 1: Multi-zone cluster —"
ZONE_COUNT=$(kubectl get nodes -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' 2>/dev/null | tr ' ' '\n' | sort -u | wc -l)
check "Cluster has nodes in multiple zones ($ZONE_COUNT zones)" \
  "[[ $ZONE_COUNT -ge 2 ]]"

echo ""
echo "— Challenge 2: Zone-app deployment —"
check "Deployment 'zone-app' exists" \
  "kubectl get deployment zone-app"
REPLICAS=$(kubectl get deployment zone-app -o jsonpath='{.spec.replicas}' 2>/dev/null)
check "zone-app has 6 replicas" \
  "[[ '$REPLICAS' == '6' ]]"

echo ""
echo "— Challenge 3: Service with topology-aware routing —"
check "Service 'zone-app' exists" \
  "kubectl get svc zone-app"
TOPO_MODE=$(kubectl get svc zone-app -o jsonpath='{.metadata.annotations.service\.kubernetes\.io/topology-mode}' 2>/dev/null)
check "Service has topology-mode=Auto annotation" \
  "[[ '$TOPO_MODE' == 'Auto' ]]"

echo ""
echo "— Challenge 4: EndpointSlice hints —"
check "EndpointSlices have zone hints" \
  "kubectl get endpointslices -l kubernetes.io/service-name=zone-app -o json 2>/dev/null | grep -q forZones"

echo ""
echo "— Bonus: trafficDistribution —"
bonus "Service 'zone-app-td' exists with trafficDistribution" \
  "kubectl get svc zone-app-td -o jsonpath='{.spec.trafficDistribution}' 2>/dev/null | grep -q PreferSameZone"

echo ""
echo "========================================"
echo "Core:  $PASS passed, $FAIL failed"
echo "Bonus: $BONUS_PASS passed, $BONUS_FAIL skipped"
echo "========================================"
