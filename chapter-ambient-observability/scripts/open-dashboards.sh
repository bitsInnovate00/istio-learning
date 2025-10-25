#!/bin/bash

# Script to open all observability dashboards at once

PROFILE="istio-ambient"

echo "======================================"
echo "Opening Observability Dashboards"
echo "======================================"
echo ""

# Check if Minikube is running
if ! minikube status -p $PROFILE &> /dev/null; then
    echo "Error: Minikube cluster is not running"
    exit 1
fi

# Function to start port-forward in background
start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local name=$5
    
    # Kill existing port-forward if any
    pkill -f "port-forward.*$service" 2>/dev/null
    
    echo "Starting port-forward for $name..."
    kubectl port-forward -n $namespace svc/$service $local_port:$remote_port &
    
    # Wait a bit for port-forward to establish
    sleep 2
}

# Start all port-forwards
start_port_forward "grafana" "istio-system" "3000" "3000" "Grafana"
start_port_forward "kiali" "istio-system" "20001" "20001" "Kiali"
start_port_forward "tracing" "istio-system" "16686" "80" "Jaeger"
start_port_forward "prometheus" "istio-system" "9090" "9090" "Prometheus"

echo ""
echo "======================================"
echo "Dashboards Ready!"
echo "======================================"
echo ""
echo "Grafana:    http://localhost:3000"
echo "            (Username: admin, Password: admin)"
echo ""
echo "Kiali:      http://localhost:20001"
echo "            (Username: admin, Password: admin)"
echo ""
echo "Jaeger:     http://localhost:16686"
echo ""
echo "Prometheus: http://localhost:9090"
echo ""
echo "======================================"
echo ""
echo "Press Ctrl+C to stop all port-forwards"
echo ""

# Wait for user to press Ctrl+C
trap "echo ''; echo 'Stopping all port-forwards...'; pkill -f 'port-forward'; exit 0" INT

# Keep script running
while true; do
    sleep 1
done
