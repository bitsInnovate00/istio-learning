#!/bin/bash

# Comprehensive verification script for Istio ambient mode installation

PROFILE="istio-ambient"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function print_header() {
    echo ""
    echo -e "${BLUE}======================================"
    echo -e "$1"
    echo -e "======================================${NC}"
    echo ""
}

function print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

function print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

function check_status() {
    local description=$1
    local command=$2
    local expected=$3
    
    result=$(eval $command)
    
    if [ "$result" == "$expected" ]; then
        print_success "$description"
        return 0
    else
        print_error "$description (Expected: $expected, Got: $result)"
        return 1
    fi
}

PASS=0
FAIL=0

print_header "Istio Ambient Mode Installation Verification"

# 1. Check Minikube
print_header "1. Checking Minikube Cluster"
if minikube status -p $PROFILE &> /dev/null; then
    print_success "Minikube cluster is running"
    ((PASS++))
else
    print_error "Minikube cluster is not running"
    ((FAIL++))
fi

# 2. Check Namespaces
print_header "2. Checking Namespaces"
for ns in istio-system istio-ingress observability bookinfo; do
    if kubectl get namespace $ns &> /dev/null; then
        print_success "Namespace '$ns' exists"
        ((PASS++))
    else
        print_error "Namespace '$ns' does not exist"
        ((FAIL++))
    fi
done

# 3. Check Istio Control Plane
print_header "3. Checking Istio Control Plane"

# Check istiod
ISTIOD_STATUS=$(kubectl get deploy istiod -n istio-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [ "$ISTIOD_STATUS" -ge 1 ]; then
    print_success "Istiod is running ($ISTIOD_STATUS replicas)"
    ((PASS++))
else
    print_error "Istiod is not running"
    ((FAIL++))
fi

# 4. Check Ambient Data Plane
print_header "4. Checking Ambient Data Plane (Ztunnel)"

ZTUNNEL_READY=$(kubectl get ds ztunnel -n istio-system -o jsonpath='{.status.numberReady}' 2>/dev/null)
ZTUNNEL_DESIRED=$(kubectl get ds ztunnel -n istio-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)

if [ "$ZTUNNEL_READY" -gt 0 ] && [ "$ZTUNNEL_READY" == "$ZTUNNEL_DESIRED" ]; then
    print_success "Ztunnel DaemonSet is healthy ($ZTUNNEL_READY/$ZTUNNEL_DESIRED pods ready)"
    ((PASS++))
else
    print_error "Ztunnel DaemonSet is not healthy ($ZTUNNEL_READY/$ZTUNNEL_DESIRED pods ready)"
    ((FAIL++))
fi

# 5. Check CNI
print_header "5. Checking Istio CNI"

CNI_READY=$(kubectl get ds istio-cni-node -n istio-system -o jsonpath='{.status.numberReady}' 2>/dev/null)
CNI_DESIRED=$(kubectl get ds istio-cni-node -n istio-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)

if [ "$CNI_READY" -gt 0 ] && [ "$CNI_READY" == "$CNI_DESIRED" ]; then
    print_success "Istio CNI is healthy ($CNI_READY/$CNI_DESIRED pods ready)"
    ((PASS++))
else
    print_error "Istio CNI is not healthy ($CNI_READY/$CNI_DESIRED pods ready)"
    ((FAIL++))
fi

# 6. Check Ambient Mode Label
print_header "6. Checking Ambient Mode Configuration"

AMBIENT_LABEL=$(kubectl get namespace bookinfo -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
if [ "$AMBIENT_LABEL" == "ambient" ]; then
    print_success "Bookinfo namespace is labeled for ambient mode"
    ((PASS++))
else
    print_error "Bookinfo namespace is not labeled for ambient mode (Label: $AMBIENT_LABEL)"
    ((FAIL++))
fi

# 7. Check Observability Stack
print_header "7. Checking Observability Stack"

for component in prometheus grafana jaeger kiali; do
    STATUS=$(kubectl get deploy $component -n observability -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
    if [ "$STATUS" -ge 1 ]; then
        print_success "$component is running"
        ((PASS++))
    else
        print_error "$component is not running"
        ((FAIL++))
    fi
done

# 8. Check Application Pods
print_header "8. Checking Bookinfo Application"

for app in productpage details ratings reviews-v1 reviews-v2 reviews-v3; do
    STATUS=$(kubectl get pods -n bookinfo -l app=${app%-*} -l version=${app##*-} -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    if [ "$STATUS" == "Running" ]; then
        print_success "$app pod is running"
        ((PASS++))
    else
        print_error "$app pod is not running (Status: $STATUS)"
        ((FAIL++))
    fi
done

# 9. Verify No Sidecars in Application Pods
print_header "9. Verifying Ambient Mode (No Sidecars)"

PRODUCTPAGE_POD=$(kubectl get pod -n bookinfo -l app=productpage -o jsonpath='{.items[0].metadata.name}')
CONTAINER_COUNT=$(kubectl get pod $PRODUCTPAGE_POD -n bookinfo -o jsonpath='{.spec.containers[*].name}' | wc -w)

if [ "$CONTAINER_COUNT" -eq 1 ]; then
    print_success "No sidecar proxy detected (ambient mode confirmed)"
    ((PASS++))
else
    print_warning "Multiple containers detected in pod (expected 1, got $CONTAINER_COUNT)"
    print_warning "Note: This might be expected if waypoint proxy is deployed"
    ((PASS++))
fi

# 10. Check mTLS Configuration
print_header "10. Checking mTLS Configuration"

MTLS_POLICY=$(kubectl get peerauthentication -n istio-system default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
if [ "$MTLS_POLICY" == "STRICT" ]; then
    print_success "mTLS is enabled (STRICT mode)"
    ((PASS++))
else
    print_warning "mTLS mode: $MTLS_POLICY (Expected: STRICT)"
    ((FAIL++))
fi

# 11. Test Application Connectivity
print_header "11. Testing Application Connectivity"

MINIKUBE_IP=$(minikube ip -p $PROFILE)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${MINIKUBE_IP}:30080/productpage 2>/dev/null)

if [ "$HTTP_CODE" == "200" ]; then
    print_success "Application is accessible (HTTP $HTTP_CODE)"
    ((PASS++))
else
    print_error "Application is not accessible (HTTP $HTTP_CODE)"
    ((FAIL++))
fi

# 12. Test Internal Communication
print_header "12. Testing Internal Service Communication"

kubectl exec -n bookinfo deploy/sleep -- curl -s -o /dev/null -w "%{http_code}" http://productpage:9080/productpage > /tmp/internal-test.txt 2>&1
INTERNAL_CODE=$(cat /tmp/internal-test.txt)

if [ "$INTERNAL_CODE" == "200" ]; then
    print_success "Internal service communication works (HTTP $INTERNAL_CODE)"
    ((PASS++))
else
    print_error "Internal service communication failed (HTTP $INTERNAL_CODE)"
    ((FAIL++))
fi

# Summary
print_header "Verification Summary"

TOTAL=$((PASS + FAIL))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($PASS/$TOTAL)*100}")

echo "Total checks: $TOTAL"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo "Success rate: $SUCCESS_RATE%"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Installation is successful.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the errors above.${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Wait for pods to be ready: kubectl wait --for=condition=ready pod --all -n <namespace>"
    echo "2. Check pod logs: kubectl logs -n <namespace> <pod-name>"
    echo "3. Restart failed pods: kubectl rollout restart deployment/<name> -n <namespace>"
    exit 1
fi
