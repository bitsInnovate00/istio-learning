#!/bin/bash

# Cleanup script to remove Istio and all components

PROFILE="istio-ambient"

echo "======================================"
echo "Istio Ambient Mode Cleanup"
echo "======================================"
echo ""
echo "This will delete:"
echo "  - Bookinfo application"
echo "  - Observability stack"
echo "  - Istio control plane"
echo "  - All configurations"
echo "  - Minikube cluster (optional)"
echo ""

read -p "Continue with cleanup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
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
kubectl delete namespace observability --ignore-not-found=true
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
echo "  ./scripts/quick-start.sh"
echo ""
