#!/bin/bash

# Quick start script for Istio Ambient Mode with Observability
# This script automates the entire installation process
# Usage: ./quick-start.sh [OPTIONS]
# Options:
#   --with-apisix    Deploy Apache APISIX API Gateway (optional)
#   --help           Show this help message

set -e

PROFILE="istio-ambient"
ISTIO_VERSION="1.24.0"
ENABLE_APISIX=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-apisix)
            ENABLE_APISIX=true
            shift
            ;;
        --help)
            echo "Usage: ./quick-start.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --with-apisix    Deploy Apache APISIX API Gateway alongside Istio"
            echo "                   (Adds API management, rate limiting, authentication)"
            echo "  --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./quick-start.sh                    # Deploy Istio only"
            echo "  ./quick-start.sh --with-apisix      # Deploy Istio + APISIX"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "======================================"
echo "Istio Ambient Mode Quick Start"
if [ "$ENABLE_APISIX" = true ]; then
    echo "  + Apache APISIX API Gateway"
fi
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

function print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

function print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# Step 1: Start Minikube
echo "Step 1: Starting Minikube..."
if minikube status -p $PROFILE &> /dev/null; then
    print_warning "Minikube profile '$PROFILE' already exists"
    
    # Check if cluster is actually healthy
    if kubectl cluster-info &> /dev/null; then
        print_status "Using existing Minikube cluster"
        
        # Clean up old failed pods if any
        print_info "Cleaning up any failed deployments..."
        kubectl delete namespace apisix bookinfo --ignore-not-found=true --wait=false 2>/dev/null || true
        
        # Wait a moment for cleanup
        sleep 3
    else
        print_warning "Cluster exists but not responding, restarting..."
        minikube stop -p $PROFILE 2>/dev/null || true
        sleep 2
        minikube start -p $PROFILE
        print_status "Minikube restarted successfully"
    fi
else
    print_info "Creating new Minikube cluster..."
    minikube start \
        --cpus=8 \
        --memory=14336 \
        --disk-size=50g \
        --driver=docker \
        --kubernetes-version=v1.28.0 \
        --profile=$PROFILE
    
    minikube addons enable metrics-server -p $PROFILE
    print_status "Minikube started successfully"
fi

# Verify cluster is accessible
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to cluster"
    exit 1
fi
print_status "Cluster is accessible"

# Step 2: Download Istio
echo ""
echo "Step 2: Downloading Istio..."
if [ ! -d "istio-$ISTIO_VERSION" ]; then
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    print_status "Istio downloaded"
else
    print_warning "Istio already downloaded"
fi

export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH

# Step 3: Create namespaces
echo ""
echo "Step 3: Creating namespaces..."
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-ingress --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace bookinfo --dry-run=client -o yaml | kubectl apply -f -
print_status "Namespaces created (observability addons will deploy to istio-system)"

# Step 4: Install Istio with ambient profile
echo ""
echo "Step 4: Installing Istio with ambient profile (including ingress gateway)..."
istioctl install --set profile=ambient \
    --set components.ingressGateways[0].name=istio-ingressgateway \
    --set components.ingressGateways[0].enabled=true \
    --set values.pilot.resources.requests.cpu=1000m \
    --set values.pilot.resources.requests.memory=2Gi \
    --set values.global.proxy.resources.requests.cpu=100m \
    --set values.global.proxy.resources.requests.memory=128Mi \
    --skip-confirmation

print_status "Istio installed with ingress gateway"

# Wait for Istio components
echo "Waiting for Istio components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system
print_status "Istio control plane ready"

# Step 5: Label namespace for ambient mode
echo ""
echo "Step 5: Configuring ambient mode for bookinfo namespace..."
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient --overwrite
print_status "Ambient mode enabled for bookinfo namespace"

# Step 6: Install observability stack
echo ""
echo "Step 6: Installing observability stack (to istio-system namespace)..."

# Install addons with retries (sometimes need to apply twice due to CRD timing)
echo "  - Installing Prometheus..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml || \
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n istio-system
print_status "Prometheus installed"

echo "  - Installing Grafana..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml || \
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n istio-system
print_status "Grafana installed"

echo "  - Installing Jaeger..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml || \
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n istio-system
print_status "Jaeger installed"

echo "  - Installing Kiali..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml || \
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml
kubectl wait --for=condition=available --timeout=300s deployment/kiali -n istio-system
print_status "Kiali installed"

# Step 7: Apply configurations
echo ""
echo "Step 7: Applying configurations..."
kubectl apply -f manifests/telemetry-config.yaml
kubectl apply -f manifests/peer-authentication.yaml
print_status "Configurations applied"

# Step 8: Deploy sample application
echo ""
echo "Step 8: Deploying Bookinfo application..."
kubectl apply -f manifests/bookinfo-app.yaml -n bookinfo
kubectl apply -f manifests/bookinfo-gateway.yaml -n bookinfo
kubectl apply -f manifests/sleep-test.yaml -n bookinfo

echo "Waiting for application pods to be ready..."
kubectl wait --for=condition=ready --timeout=300s pod --all -n bookinfo
print_status "Bookinfo application deployed"

# Step 9: Verify installation
echo ""
echo "Step 9: Verifying installation..."

echo "Checking Istio components..."
ISTIOD=$(kubectl get pods -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
ZTUNNEL=$(kubectl get ds -n istio-system ztunnel -o jsonpath='{.status.numberReady}')

if [ "$ISTIOD" = "Running" ]; then
    print_status "Istiod is running"
else
    print_error "Istiod is not running"
fi

if [ "$ZTUNNEL" -gt 0 ]; then
    print_status "Ztunnel DaemonSet is running ($ZTUNNEL pods)"
else
    print_error "Ztunnel is not running"
fi

echo ""
echo "Checking observability components..."
kubectl get pods -n istio-system | grep -E "prometheus|grafana|jaeger|kiali"

echo ""
echo "Checking ingress gateway..."
GATEWAY_READY=$(kubectl get deploy istio-ingressgateway -n istio-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
if [ "$GATEWAY_READY" -gt 0 ]; then
    print_status "Ingress gateway is running"
    GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
    MINIKUBE_IP=$(minikube ip -p $PROFILE)
    echo "   Gateway URL: http://${MINIKUBE_IP}:${GATEWAY_PORT}/productpage"
else
    print_error "Ingress gateway is not running"
fi

# Step 10: Deploy APISIX (optional)
if [ "$ENABLE_APISIX" = true ]; then
    echo ""
    echo "Step 10: Deploying Apache APISIX API Gateway..."
    print_info "APISIX will provide API management capabilities alongside Istio"
    
    if [ -x "./scripts/deploy-apisix.sh" ]; then
        ./scripts/deploy-apisix.sh
        print_status "APISIX deployed successfully"
    else
        print_error "deploy-apisix.sh not found or not executable"
    fi
fi

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "Architecture deployed:"
if [ "$ENABLE_APISIX" = true ]; then
    echo "  Client → APISIX (API Gateway) → Istio Mesh → Services"
    echo "           ├─ Rate Limiting"
    echo "           ├─ Authentication"
    echo "           └─ API Management"
    echo ""
    echo "  Istio provides:"
    echo "           ├─ mTLS (automatic)"
    echo "           ├─ Observability"
    echo "           └─ Traffic Management"
else
    echo "  Client → Istio Gateway → Istio Mesh → Services"
    echo "           ├─ mTLS (automatic)"
    echo "           ├─ Observability"
    echo "           └─ Traffic Management"
fi
echo ""
echo "Next steps:"
echo ""
echo "1. Access Grafana:"
echo "   kubectl port-forward -n istio-system svc/grafana 3000:3000"
echo "   Open: http://localhost:3000"
echo ""
echo "2. Access Kiali:"
echo "   kubectl port-forward -n istio-system svc/kiali 20001:20001"
echo "   Open: http://localhost:20001"
echo ""
echo "3. Access Jaeger:"
echo "   kubectl port-forward -n istio-system svc/tracing 16686:80"
echo "   Open: http://localhost:16686"
echo ""
echo "4. Access Prometheus:"
echo "   kubectl port-forward -n istio-system svc/prometheus 9090:9090"
echo "   Open: http://localhost:9090"
echo ""

if [ "$ENABLE_APISIX" = true ]; then
    echo "5. Access APISIX Dashboard:"
    echo "   kubectl port-forward -n apisix svc/apisix-dashboard 30900:9000"
    echo "   Open: http://localhost:30900"
    echo "   Login: admin / admin"
    echo ""
    echo "6. Test via APISIX (with API management):"
    echo "   kubectl port-forward -n apisix svc/apisix-gateway 30800:9080"
    echo "   curl http://localhost:30800/productpage"
    echo ""
    echo "7. Test API with authentication:"
    echo "   curl http://localhost:30800/api/v1/products/1 -H 'apikey: apikey-12345678901234567890'"
    echo ""
    echo "8. View APISIX metrics:"
    echo "   curl http://localhost:30800/apisix/prometheus/metrics"
    echo ""
    echo "9. Test via Istio Gateway (traditional):"
else
    echo "5. Test the application (command line):"
fi
echo "   MINIKUBE_IP=\$(minikube ip -p $PROFILE)"
echo "   GATEWAY_PORT=\$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name==\"http2\")].nodePort}')"
echo "   curl http://\${MINIKUBE_IP}:\${GATEWAY_PORT}/productpage"
echo ""

if [ "$ENABLE_APISIX" = false ]; then
    echo "6. Access application in browser (WSL2/Docker driver):"
    echo "   kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
    echo "   Open: http://localhost:8080/productpage"
    echo ""
    echo "7. Open all dashboards (in separate terminals):"
    echo "   ./scripts/open-dashboards.sh"
    echo ""
    echo "8. Generate traffic:"
    echo "   ./scripts/generate-traffic.sh 100 2"
    echo ""
    echo "9. Run verification tests:"
    echo "   ./scripts/verify-installation.sh"
    echo ""
else
    echo "10. Access application in browser (WSL2/Docker driver):"
    echo "    kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
    echo "    Open: http://localhost:8080/productpage"
    echo ""
    echo "11. Open all dashboards (in separate terminals):"
    echo "    ./scripts/open-dashboards.sh"
    echo ""
    echo "12. Generate traffic:"
    echo "    ./scripts/generate-traffic.sh 100 2"
    echo ""
    echo "13. Run verification tests:"
    echo "    ./scripts/verify-installation.sh --with-apisix"
    echo ""
    echo "14. Test APISIX integration:"
    echo "    ./scripts/test-apisix.sh"
    echo ""
fi

if [ "$ENABLE_APISIX" = true ]; then
    print_info "APISIX Documentation: ./APISIX_ISTIO_INTEGRATION.md"
    print_info "APISIX Quick Reference: ./APISIX_QUICKSTART.md"
fi
echo ""
