#!/bin/bash

# Script to generate continuous traffic to test observability

PROFILE="istio-ambient"
REQUESTS=${1:-100}
DELAY=${2:-2}

echo "Generating $REQUESTS requests with ${DELAY}s delay..."

# Get Minikube IP
MINIKUBE_IP=$(minikube ip -p $PROFILE)

# Check if Minikube is running
if [ -z "$MINIKUBE_IP" ]; then
    echo "Error: Minikube is not running"
    exit 1
fi

# Use NodePort 30080 (defined in bookinfo-gateway.yaml)
URL="http://${MINIKUBE_IP}:30080/productpage"

echo "Target URL: $URL"
echo ""

# Test if the application is accessible
echo "Testing connectivity..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL)

if [ "$HTTP_CODE" != "200" ]; then
    echo "Error: Application not accessible (HTTP $HTTP_CODE)"
    echo "Make sure the application is deployed and the gateway is configured"
    exit 1
fi

echo "✓ Application is accessible"
echo ""
echo "Generating traffic..."

SUCCESS=0
FAILED=0

for i in $(seq 1 $REQUESTS); do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $URL)
    
    if [ "$RESPONSE" = "200" ]; then
        echo "[$i/$REQUESTS] ✓ HTTP $RESPONSE"
        ((SUCCESS++))
    else
        echo "[$i/$REQUESTS] ✗ HTTP $RESPONSE"
        ((FAILED++))
    fi
    
    sleep $DELAY
done

echo ""
echo "======================================"
echo "Traffic Generation Complete"
echo "======================================"
echo "Successful requests: $SUCCESS"
echo "Failed requests: $FAILED"
echo "Success rate: $(awk "BEGIN {printf \"%.2f\", ($SUCCESS/$REQUESTS)*100}")%"
echo ""
echo "Check observability dashboards:"
echo "  - Grafana: kubectl port-forward -n observability svc/grafana 3000:3000"
echo "  - Kiali: kubectl port-forward -n observability svc/kiali 20001:20001"
echo "  - Jaeger: kubectl port-forward -n observability svc/tracing 16686:16686"
