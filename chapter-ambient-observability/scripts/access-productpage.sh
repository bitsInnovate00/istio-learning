#!/bin/bash

# Script to access the Bookinfo product page in browser
# For WSL2/Docker driver environments where Minikube IP is not directly accessible

echo "======================================"
echo "Bookinfo Product Page Browser Access"
echo "======================================"
echo ""

# Check if running on WSL2
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Detected WSL2 environment"
    echo ""
    echo "Starting port-forward to make product page accessible from Windows browser..."
    echo ""
    echo "Once started, open in your browser:"
    echo ""
    echo "  🌐 http://localhost:8080/productpage"
    echo ""
    echo "Press Ctrl+C to stop the port-forward"
    echo ""
    kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
else
    # Not WSL2, provide direct URL
    MINIKUBE_IP=$(minikube ip -p istio-ambient 2>/dev/null)
    GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system \
                   -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null)
    
    if [ -n "$MINIKUBE_IP" ] && [ -n "$GATEWAY_PORT" ]; then
        echo "Direct access available at:"
        echo ""
        echo "  🌐 http://${MINIKUBE_IP}:${GATEWAY_PORT}/productpage"
        echo ""
        echo "Copy and paste the URL above into your browser"
    else
        echo "❌ Could not determine gateway URL"
        echo ""
        echo "Alternative: Use port-forward"
        echo ""
        echo "  kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
        echo "  Then open: http://localhost:8080/productpage"
    fi
fi
