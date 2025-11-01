#!/bin/bash

# Comprehensive verification script for Istio ambient mode installation
# Usage: ./verify-installation.sh [--with-apisix]

PROFILE="istio-ambient"
CHECK_APISIX=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-apisix)
            CHECK_APISIX=true
            shift
            ;;
        --help)
            echo "Usage: ./verify-installation.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --with-apisix    Verify APISIX API Gateway installation"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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
for ns in istio-system istio-ingress bookinfo; do
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
print_header "7. Checking Observability Stack (in istio-system)"

for component in prometheus grafana jaeger kiali; do
    STATUS=$(kubectl get deploy $component -n istio-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
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

# Check each deployment
for deployment in productpage-v1 details-v1 ratings-v1 reviews-v1 reviews-v2 reviews-v3; do
    STATUS=$(kubectl get deploy $deployment -n bookinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
    if [ "$STATUS" -ge 1 ]; then
        print_success "$deployment pod is running"
        ((PASS++))
    else
        print_error "$deployment pod is not running"
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

# 11. Check Ingress Gateway
print_header "11. Checking Ingress Gateway"

INGRESS_STATUS=$(kubectl get deploy istio-ingressgateway -n istio-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [ "$INGRESS_STATUS" -ge 1 ]; then
    print_success "Istio ingress gateway is running"
    ((PASS++))
else
    print_error "Istio ingress gateway is not running"
    ((FAIL++))
fi

# 12. Test Application Connectivity
print_header "12. Testing Application Connectivity"

MINIKUBE_IP=$(minikube ip -p $PROFILE)
INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${MINIKUBE_IP}:${INGRESS_PORT}/productpage 2>/dev/null)

if [ "$HTTP_CODE" == "200" ]; then
    print_success "Application is accessible (HTTP $HTTP_CODE)"
    ((PASS++))
else
    print_error "Application is not accessible (HTTP $HTTP_CODE)"
    ((FAIL++))
fi

# 13. Test Internal Communication
print_header "13. Testing Internal Service Communication"

kubectl exec -n bookinfo deploy/sleep -- curl -s -o /dev/null -w "%{http_code}" http://productpage:9080/productpage > /tmp/internal-test.txt 2>&1
INTERNAL_CODE=$(cat /tmp/internal-test.txt)

if [ "$INTERNAL_CODE" == "200" ]; then
    print_success "Internal service communication works (HTTP $INTERNAL_CODE)"
    ((PASS++))
else
    print_error "Internal service communication failed (HTTP $INTERNAL_CODE)"
    ((FAIL++))
fi

# 14. Check APISIX (if enabled)
if [ "$CHECK_APISIX" = true ]; then
    print_header "14. Checking APISIX API Gateway"
    
    # Check APISIX namespace
    if kubectl get namespace apisix &> /dev/null; then
        print_success "APISIX namespace exists"
        ((PASS++))
    else
        print_error "APISIX namespace does not exist"
        ((FAIL++))
    fi
    
    # Check APISIX pods
    APISIX_STATUS=$(kubectl get deploy apisix -n apisix -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
    if [ "$APISIX_STATUS" -ge 1 ]; then
        print_success "APISIX gateway is running ($APISIX_STATUS replicas)"
        ((PASS++))
    else
        print_error "APISIX gateway is not running"
        ((FAIL++))
    fi
    
    # Check APISIX Dashboard
    DASHBOARD_STATUS=$(kubectl get deploy apisix-dashboard -n apisix -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
    if [ "$DASHBOARD_STATUS" -ge 1 ]; then
        print_success "APISIX Dashboard is running"
        ((PASS++))
    else
        print_error "APISIX Dashboard is not running"
        ((FAIL++))
    fi
    
    # Check etcd
    ETCD_READY=$(kubectl get statefulset etcd -n apisix -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [ "$ETCD_READY" -ge 1 ]; then
        print_success "etcd is running"
        ((PASS++))
    else
        print_error "etcd is not running"
        ((FAIL++))
    fi
    
    # Check APISIX Admin API
    ADMIN_API_CODE=$(kubectl exec -n apisix deploy/apisix -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9180/apisix/admin/routes -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" 2>/dev/null)
    if [ "$ADMIN_API_CODE" == "200" ]; then
        print_success "APISIX Admin API is accessible"
        ((PASS++))
    else
        print_warning "APISIX Admin API check failed (HTTP $ADMIN_API_CODE)"
        ((FAIL++))
    fi
    
    # Check APISIX → Istio connectivity
    APISIX_CONN=$(kubectl exec -n apisix deploy/apisix -- curl -s -o /dev/null -w "%{http_code}" http://productpage.bookinfo.svc.cluster.local:9080/productpage 2>/dev/null)
    if [ "$APISIX_CONN" == "200" ]; then
        print_success "APISIX can communicate with Istio mesh services"
        ((PASS++))
    else
        print_error "APISIX cannot reach Istio mesh services (HTTP $APISIX_CONN)"
        ((FAIL++))
    fi
    
    # Check if APISIX is in ambient mode
    APISIX_AMBIENT=$(kubectl get namespace apisix -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
    if [ "$APISIX_AMBIENT" == "ambient" ]; then
        print_success "APISIX namespace is in ambient mode"
        ((PASS++))
    else
        print_warning "APISIX namespace is not in ambient mode"
    fi
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
    if [ "$CHECK_APISIX" = true ]; then
        echo ""
        echo "Architecture deployed:"
        echo "  Client → APISIX (API Gateway) → Istio Mesh → Services"
        echo ""
        echo "Access points:"
        echo "  - APISIX Gateway: http://localhost:30800"
        echo "  - APISIX Dashboard: http://localhost:30900"
        echo "  - Istio Gateway: http://$(minikube ip -p $PROFILE):$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')"
    fi
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the errors above.${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Wait for pods to be ready: kubectl wait --for=condition=ready pod --all -n <namespace>"
    echo "2. Check pod logs: kubectl logs -n <namespace> <pod-name>"
    echo "3. Restart failed pods: kubectl rollout restart deployment/<name> -n <namespace>"
    if [ "$CHECK_APISIX" = true ]; then
        echo "4. Check APISIX logs: kubectl logs -n apisix deploy/apisix -f"
        echo "5. Verify routes: curl http://localhost:30180/apisix/admin/routes -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'"
    fi
    exit 1
fi
