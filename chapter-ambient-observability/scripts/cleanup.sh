#!/bin/bash

# Cleanup script to remove Istio and all components
# Usage: ./cleanup.sh [--with-apisix]

PROFILE="istio-ambient"
CLEANUP_APISIX=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-apisix)
            CLEANUP_APISIX=true
            shift
            ;;
        --help)
            echo "Usage: ./cleanup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --with-apisix    Also cleanup APISIX components"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect APISIX if namespace exists
if kubectl get namespace apisix &> /dev/null; then
    if [ "$CLEANUP_APISIX" = false ]; then
        echo "APISIX namespace detected!"
        read -p "Also cleanup APISIX? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEANUP_APISIX=true
        fi
    fi
fi

echo "======================================"
echo "Istio Ambient Mode Cleanup"
if [ "$CLEANUP_APISIX" = true ]; then
    echo "  + Apache APISIX"
fi
echo "======================================"
echo ""
echo "This will delete:"
echo "  - Bookinfo application"
echo "  - Observability stack (from istio-system)"
echo "  - Istio control plane"
echo "  - All configurations"
if [ "$CLEANUP_APISIX" = true ]; then
    echo "  - APISIX API Gateway"
    echo "  - APISIX Dashboard"
    echo "  - etcd (APISIX config storage)"
fi
echo "  - Minikube cluster (optional)"
echo ""

read -p "Continue with cleanup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Cleanup APISIX (if enabled)
if [ "$CLEANUP_APISIX" = true ]; then
    echo ""
    echo "Step 0: Deleting APISIX components..."
    kubectl delete -f manifests/apisix-plugins.yaml --ignore-not-found=true
    kubectl delete -f manifests/apisix-dashboard.yaml --ignore-not-found=true
    kubectl delete -f manifests/apisix-deployment.yaml --ignore-not-found=true
    kubectl delete namespace apisix --ignore-not-found=true
    echo "✓ APISIX components deleted"
    echo "  Waiting for namespace to be fully removed..."
    kubectl wait --for=delete namespace/apisix --timeout=60s 2>/dev/null || echo "  (namespace cleanup may still be in progress)"
fi

echo ""
echo "Step 1: Deleting Bookinfo application..."
kubectl delete -f manifests/bookinfo-gateway.yaml -n bookinfo --ignore-not-found=true
kubectl delete -f manifests/bookinfo-app.yaml -n bookinfo --ignore-not-found=true
kubectl delete -f manifests/sleep-test.yaml -n bookinfo --ignore-not-found=true
echo "✓ Bookinfo application deleted"

echo ""
echo "Step 2: Deleting configurations..."
kubectl delete -f manifests/telemetry-config.yaml --ignore-not-found=true
kubectl delete -f manifests/peer-authentication.yaml --ignore-not-found=true
echo "✓ Configurations deleted"

echo ""
echo "Step 3: Deleting observability stack..."
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml --ignore-not-found=true
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml --ignore-not-found=true
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml --ignore-not-found=true
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml --ignore-not-found=true
echo "✓ Observability stack deleted"

echo ""
echo "Step 4: Uninstalling Istio..."
istioctl uninstall --purge -y 2>/dev/null || echo "Note: istioctl uninstall had warnings"
echo "✓ Istio uninstalled"

echo ""
echo "Step 5: Deleting namespaces..."
kubectl delete namespace bookinfo --ignore-not-found=true
kubectl delete namespace istio-ingress --ignore-not-found=true
kubectl delete namespace istio-system --ignore-not-found=true
echo "✓ Namespaces deleted"

echo ""
read -p "Delete Minikube cluster? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting Minikube cluster..."
    minikube delete -p $PROFILE
    echo "✓ Minikube cluster deleted"
else
    echo "Minikube cluster preserved"
fi

echo ""
echo "======================================"
echo "Cleanup Complete!"
echo "======================================"
echo ""
echo "To start fresh, run:"
if [ "$CLEANUP_APISIX" = true ]; then
    echo "  ./scripts/quick-start.sh --with-apisix"
else
    echo "  ./scripts/quick-start.sh"
fi
echo ""
