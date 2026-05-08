#!/bin/bash
# ============================================================================
# Exercise 12 — IPv4/IPv6 Dual-Stack: Verification Script
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

echo "=== Exercise 12: IPv4/IPv6 Dual-Stack Networking ==="
echo ""

echo "— Challenge 1: Dual-stack cluster —"
# Check if pods have both IPv4 and IPv6
POD_IPS=$(kubectl get pods -l app=web -o jsonpath='{.items[0].status.podIPs[*].ip}' 2>/dev/null)
IPV4=$(echo "$POD_IPS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
IPV6=$(echo "$POD_IPS" | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}')
check "Deployment 'web' exists" \
  "kubectl get deployment web"
if [[ -n "$IPV4" && -n "$IPV6" ]]; then
  echo "  ✅ Pods have both IPv4 ($IPV4) and IPv6 addresses"; ((PASS++))
elif [[ -n "$IPV4" ]]; then
  echo "  ❌ Pods only have IPv4 — cluster may not be dual-stack"; ((FAIL++))
else
  echo "  ❌ Cannot determine pod IPs"; ((FAIL++))
fi

echo ""
echo "— Challenge 2: PreferDualStack service —"
check "Service 'web-dualstack' exists" \
  "kubectl get svc web-dualstack"
POLICY=$(kubectl get svc web-dualstack -o jsonpath='{.spec.ipFamilyPolicy}' 2>/dev/null)
check "web-dualstack has ipFamilyPolicy=PreferDualStack" \
  "[[ '$POLICY' == 'PreferDualStack' ]]"
SVC_IPS=$(kubectl get svc web-dualstack -o jsonpath='{.spec.clusterIPs[*]}' 2>/dev/null)
SVC_IP_COUNT=$(echo "$SVC_IPS" | wc -w)
check "web-dualstack has 2 ClusterIPs (IPv4 + IPv6)" \
  "[[ $SVC_IP_COUNT -ge 2 ]]"

echo ""
echo "— Challenge 3: RequireDualStack (IPv6 primary) service —"
check "Service 'web-ipv6-primary' exists" \
  "kubectl get svc web-ipv6-primary"
POLICY6=$(kubectl get svc web-ipv6-primary -o jsonpath='{.spec.ipFamilyPolicy}' 2>/dev/null)
check "web-ipv6-primary has ipFamilyPolicy=RequireDualStack" \
  "[[ '$POLICY6' == 'RequireDualStack' ]]"
FIRST_FAMILY=$(kubectl get svc web-ipv6-primary -o jsonpath='{.spec.ipFamilies[0]}' 2>/dev/null)
check "web-ipv6-primary has IPv6 as primary family" \
  "[[ '$FIRST_FAMILY' == 'IPv6' ]]"

echo ""
echo "— Challenge 4: SingleStack (IPv4 only) service —"
check "Service 'web-ipv4-only' exists" \
  "kubectl get svc web-ipv4-only"
POLICY4=$(kubectl get svc web-ipv4-only -o jsonpath='{.spec.ipFamilyPolicy}' 2>/dev/null)
check "web-ipv4-only has ipFamilyPolicy=SingleStack" \
  "[[ '$POLICY4' == 'SingleStack' ]]"
FAMILY4=$(kubectl get svc web-ipv4-only -o jsonpath='{.spec.ipFamilies[0]}' 2>/dev/null)
check "web-ipv4-only uses IPv4" \
  "[[ '$FAMILY4' == 'IPv4' ]]"

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
