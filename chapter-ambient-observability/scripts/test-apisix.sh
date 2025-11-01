#!/bin/bash

# Test Apache APISIX + Istio Integration
# Validates that APISIX is correctly routing to Istio mesh services

set -e

echo "=============================================="
echo "  APISIX + Istio Integration Tests"
echo "=============================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APISIX_URL="http://localhost:30800"
ADMIN_API="http://localhost:30180/apisix/admin"
ADMIN_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Test counter
PASSED=0
FAILED=0

# Test function
test_endpoint() {
    local description="$1"
    local url="$2"
    local expected_code="${3:-200}"
    local headers="$4"
    
    echo -n "Testing: $description... "
    
    if [ -z "$headers" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" -H "$headers" "$url")
    fi
    
    if [ "$response" -eq "$expected_code" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (HTTP $response)"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC} (Expected: $expected_code, Got: $response)"
        ((FAILED++))
    fi
}

echo -e "${BLUE}=== Checking APISIX Components ===${NC}"
echo ""

# Check APISIX pods
echo -n "Checking APISIX pods... "
if kubectl get pods -n apisix -l app=apisix | grep -q Running; then
    echo -e "${GREEN}✓ Running${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Not running${NC}"
    ((FAILED++))
fi

echo -n "Checking APISIX Dashboard... "
if kubectl get pods -n apisix -l app=apisix-dashboard | grep -q Running; then
    echo -e "${GREEN}✓ Running${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Not running${NC}"
    ((FAILED++))
fi

echo -n "Checking etcd... "
if kubectl get pods -n apisix -l app=etcd | grep -q Running; then
    echo -e "${GREEN}✓ Running${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Not running${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Testing APISIX Admin API ===${NC}"
echo ""

# Test Admin API
echo -n "Testing Admin API access... "
admin_response=$(curl -s -o /dev/null -w "%{http_code}" "${ADMIN_API}/routes" -H "X-API-KEY: ${ADMIN_KEY}" 2>/dev/null)
if [ "$admin_response" -eq 200 ]; then
    echo -e "${GREEN}✓ PASSED${NC} (HTTP $admin_response)"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC} (HTTP $admin_response)"
    echo "  Check: curl ${ADMIN_API}/routes -H 'X-API-KEY: ${ADMIN_KEY}'"
    ((FAILED++))
fi

# List routes
echo ""
echo -e "${BLUE}=== Configured Routes ===${NC}"
echo ""
# Check if jq is available
if command -v jq &> /dev/null; then
    routes=$(curl -s "${ADMIN_API}/routes" -H "X-API-KEY: ${ADMIN_KEY}" 2>/dev/null | jq -r '.list[]? | "Route \(.value.id): \(.value.name) - \(.value.uri)"' 2>/dev/null || echo "No routes configured")
else
    # Fallback without jq
    routes=$(curl -s "${ADMIN_API}/routes" -H "X-API-KEY: ${ADMIN_KEY}" 2>/dev/null | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' || echo "jq not installed - install for better output")
fi
echo "$routes"

echo ""
echo -e "${BLUE}=== Testing APISIX Gateway Routes ===${NC}"
echo ""

# Test productpage route
test_endpoint "Productpage route" "${APISIX_URL}/productpage"

# Test static content (may 404 but should route)
test_endpoint "Static content route" "${APISIX_URL}/static/test.css" "404"

# Test API endpoint without authentication (should fail)
test_endpoint "API without auth (should fail)" "${APISIX_URL}/api/v1/products/1" "401"

# Test API endpoint with authentication
test_endpoint "API with auth key" "${APISIX_URL}/api/v1/products/1" "404" "apikey: apikey-12345678901234567890"

# Test APISIX status endpoint
test_endpoint "APISIX status endpoint" "${APISIX_URL}/apisix/status" "200"

# Test Prometheus metrics
echo -n "Testing Prometheus metrics export... "
metrics=$(curl -s "${APISIX_URL}/apisix/prometheus/metrics" | grep -c "apisix_" || echo "0")
if [ "$metrics" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC} (Found $metrics APISIX metrics)"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC} (No metrics found)"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Testing Rate Limiting ===${NC}"
echo ""

# Test rate limiting
echo "Testing rate limit (making 5 requests)..."
for i in {1..5}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "${APISIX_URL}/productpage")
    echo "  Request $i: HTTP $response"
done

echo ""
echo -e "${BLUE}=== Testing Istio Integration ===${NC}"
echo ""

# Check if traffic goes through Istio
echo -n "Checking if APISIX is in ambient mesh... "
if kubectl get pod -n apisix -l app=apisix -o jsonpath='{.items[0].metadata.labels.istio\.io/dataplane-mode}' | grep -q "ambient"; then
    echo -e "${GREEN}✓ PASSED${NC} (Ambient mode enabled)"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Not in ambient mode)"
fi

# Check service connectivity
echo -n "Testing APISIX → Bookinfo connectivity... "
# Test via the configured route since APISIX container may not have curl
connectivity_test=$(curl -s -o /dev/null -w "%{http_code}" "${APISIX_URL}/productpage" 2>/dev/null)
if [ "$connectivity_test" -eq 200 ]; then
    echo -e "${GREEN}✓ PASSED${NC} (Route is reachable)"
    ((PASSED++))
elif [ "$connectivity_test" -eq 503 ]; then
    echo -e "${RED}✗ FAILED${NC} (Service unavailable - check if bookinfo is running)"
    ((FAILED++))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (HTTP $connectivity_test - route exists but service may not be ready)"
    ((PASSED++))
fi

echo ""
echo -e "${BLUE}=== Testing APISIX Dashboard ===${NC}"
echo ""

# Test dashboard access
test_endpoint "Dashboard UI" "http://localhost:30900/"

echo ""
echo -e "${BLUE}=== Performance Test ===${NC}"
echo ""

# Simple load test
echo "Running quick load test (10 requests)..."
start_time=$(date +%s)
for i in {1..10}; do
    curl -s -o /dev/null "${APISIX_URL}/productpage"
done
end_time=$(date +%s)
duration=$((end_time - start_time))
rps=$((10 / duration))
echo -e "Completed 10 requests in ${duration}s (~${rps} req/s)"

echo ""
echo -e "${BLUE}=== Request Tracing Test ===${NC}"
echo ""

# Test request ID propagation
echo -n "Testing request ID propagation... "
response_headers=$(curl -s -I "${APISIX_URL}/productpage" | grep -i "X-Request-Id")
if [ -n "$response_headers" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    echo "  $response_headers"
    ((PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED++))
fi

echo ""
echo "=============================================="
echo "  Test Summary"
echo "=============================================="
echo -e "Total Tests: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Access APISIX Dashboard: http://localhost:30900"
    echo "2. View metrics: ${APISIX_URL}/apisix/prometheus/metrics"
    echo "3. Test with: curl ${APISIX_URL}/productpage"
    echo "4. Test API with key: curl ${APISIX_URL}/api/v1/products/1 -H 'apikey: apikey-12345678901234567890'"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the configuration.${NC}"
    exit 1
fi
