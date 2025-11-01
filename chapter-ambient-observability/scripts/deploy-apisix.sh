#!/bin/bash

# Deploy Apache APISIX API Gateway with Istio Integration
# This script deploys APISIX alongside Istio Service Mesh

set -e

echo "=============================================="
echo "  Apache APISIX + Istio Integration Setup"
echo "=============================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"

# Step 1: Deploy APISIX core components
echo ""
echo "Step 1: Deploying APISIX core components..."
kubectl apply -f manifests/apisix-deployment.yaml
echo -e "${GREEN}✓ APISIX deployment created${NC}"

echo "  Note: Fixed etcd image to use quay.io/coreos/etcd:v3.5.9 with proper cluster config"

# Step 2: Deploy APISIX Dashboard
echo ""
echo "Step 2: Deploying APISIX Dashboard..."
kubectl apply -f manifests/apisix-dashboard.yaml
echo -e "${GREEN}✓ APISIX Dashboard created${NC}"

# Step 3: Deploy APISIX plugins and consumers
echo ""
echo "Step 3: Deploying APISIX plugins configuration..."
kubectl apply -f manifests/apisix-plugins.yaml
echo -e "${GREEN}✓ APISIX plugins configured${NC}"

# Wait for APISIX pods to be ready
echo ""
echo "Waiting for APISIX components to be ready..."

# Wait for etcd
if kubectl wait --for=condition=ready pod -l app=etcd -n apisix --timeout=300s 2>/dev/null; then
    echo -e "${GREEN}✓ etcd is ready${NC}"
else
    echo -e "${RED}✗ etcd failed to become ready${NC}"
    echo "  Run: kubectl get pods -n apisix"
    echo "  Run: kubectl describe pod -l app=etcd -n apisix"
    exit 1
fi

# Wait for APISIX
if kubectl wait --for=condition=ready pod -l app=apisix -n apisix --timeout=300s 2>/dev/null; then
    echo -e "${GREEN}✓ APISIX is ready${NC}"
else
    echo -e "${RED}✗ APISIX failed to become ready${NC}"
    echo "  Run: kubectl logs -l app=apisix -n apisix"
    exit 1
fi

# Wait for Dashboard
if kubectl wait --for=condition=ready pod -l app=apisix-dashboard -n apisix --timeout=300s 2>/dev/null; then
    echo -e "${GREEN}✓ APISIX Dashboard is ready${NC}"
else
    echo -e "${YELLOW}⚠ APISIX Dashboard not ready (continuing anyway)${NC}"
fi

# Step 4: Configure APISIX routes
echo ""
echo "Step 4: Configuring APISIX routes..."

# APISIX Admin API endpoint
ADMIN_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Use port-forward for Admin API access (more reliable than NodePort in WSL2/Docker)
echo "Setting up port-forward to APISIX Admin API (running in background)..."

# Kill any existing port-forward
pkill -f "kubectl port-forward.*apisix.*9180" 2>/dev/null || true
sleep 1

# Start port-forward in background
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 3  # Give it time to establish

ADMIN_API="http://localhost:9180/apisix/admin"

# Wait for Admin API to be accessible
echo "Waiting for APISIX Admin API to respond..."
MAX_RETRIES=20
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${ADMIN_API}/routes" -H "X-API-KEY: ${ADMIN_KEY}" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Admin API is accessible${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}✗ Admin API not accessible via port-forward${NC}"
        echo -e "${YELLOW}This might be a WSL2/Docker networking issue${NC}"
        echo ""
        echo "You can configure routes manually using:"
        echo "  kubectl port-forward -n apisix svc/apisix-gateway 9180:9180"
        echo "  Then run the curl commands in the README"
        kill $PF_PID 2>/dev/null
        exit 0  # Don't fail, just warn
    fi
    
    sleep 1
done

# Create route 1: Productpage with rate limiting
echo -n "Creating productpage route... "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/apisix_response.json -X PUT "${ADMIN_API}/routes/1" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/productpage",
    "name": "productpage-route",
    "methods": ["GET", "POST"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      },
      "timeout": {
        "connect": 6,
        "send": 6,
        "read": 6
      }
    },
    "plugins": {
      "limit-count": {
        "count": 100,
        "time_window": 60,
        "rejected_code": 429,
        "rejected_msg": "Too many requests"
      },
      "prometheus": {},
      "cors": {
        "allow_origins": "*",
        "allow_methods": "GET,POST",
        "allow_headers": "*"
      }
    }
  }')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
    cat /tmp/apisix_response.json 2>/dev/null || echo "No response body"
fi

# Create route 2: Static content
echo -n "Creating static content route... "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/apisix_response.json -X PUT "${ADMIN_API}/routes/2" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/static/*",
    "name": "static-content-route",
    "methods": ["GET"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "proxy-cache": {
        "cache_ttl": 3600,
        "cache_bypass": ["$arg_bypass"],
        "cache_method": ["GET"],
        "cache_http_status": [200, 301, 302]
      },
      "prometheus": {}
    }
  }')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
fi

# Create route 3: API endpoints with authentication
echo -n "Creating API route with authentication... "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/apisix_response.json -X PUT "${ADMIN_API}/routes/3" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/products/*",
    "name": "products-api-route",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "key-auth": {},
      "limit-count": {
        "count": 200,
        "time_window": 60
      },
      "prometheus": {},
      "request-id": {
        "header_name": "X-Request-Id",
        "include_in_response": true
      }
    }
  }')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
fi

# Create route 4: Login/Logout
echo -n "Creating auth routes... "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/apisix_response.json -X PUT "${ADMIN_API}/routes/4" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "uris": ["/login", "/logout"],
    "name": "auth-route",
    "methods": ["GET", "POST"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 20,
        "time_window": 60
      },
      "prometheus": {}
    }
  }')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
fi

# Create consumer for API authentication
echo -n "Creating API consumer... "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/apisix_response.json -X PUT "${ADMIN_API}/consumers" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "api_user",
    "plugins": {
      "key-auth": {
        "key": "apikey-12345678901234567890"
      },
      "limit-count": {
        "count": 1000,
        "time_window": 3600
      }
    }
  }')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
    echo -e "  Response: $(cat /tmp/apisix_response.json 2>/dev/null)"
fi

# Create global rule for all routes
echo -n "Creating global plugins... "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/apisix_response.json -X PUT "${ADMIN_API}/global_rules/1" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "prometheus": {
        "prefer_name": true
      },
      "request-id": {
        "header_name": "X-Request-Id",
        "include_in_response": true
      }
    }
  }')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
fi

# Cleanup temp file
rm -f /tmp/apisix_response.json

# Display deployment information
echo ""
echo "=============================================="
echo "  APISIX Deployment Complete!"
echo "=============================================="
echo ""
echo "Access Points:"
echo "--------------"
echo -e "${YELLOW}Note: NodePort may not work in WSL2/Docker environments${NC}"
echo -e "${YELLOW}Use 'minikube service' or 'kubectl port-forward' to access services${NC}"
echo ""
echo "APISIX Gateway:        kubectl port-forward -n apisix svc/apisix-gateway 9080:9080"
echo "APISIX Dashboard:      kubectl port-forward -n apisix svc/apisix-dashboard 9000:9000"
echo "  └─ Credentials:      admin / admin"
echo "  └─ URL:              http://localhost:9000"
echo "APISIX Admin API:      kubectl port-forward -n apisix svc/apisix-gateway 9180:9180"
echo "  └─ API Key:          ${ADMIN_KEY}"
echo "  └─ URL:              http://localhost:9180/apisix/admin"
echo ""
echo "Alternative (Minikube tunnel):"
echo "  minikube service apisix-gateway -n apisix -p istio-ambient"
echo ""
echo "Example Usage:"
echo "--------------"
echo "# Set up port-forward first:"
echo "kubectl port-forward -n apisix svc/apisix-gateway 9080:9080 &"
echo ""
echo "# Access bookinfo through APISIX"
echo "curl http://localhost:9080/productpage"
echo ""
echo "# Access with API key"
echo "curl http://localhost:9080/api/v1/products/1 -H 'apikey: apikey-12345678901234567890'"
echo ""
echo "# View APISIX metrics"
echo "curl http://localhost:9080/apisix/prometheus/metrics"
echo ""
echo "# List all routes (Admin API port-forward needed)"
echo "kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 &"
echo "curl http://localhost:9180/apisix/admin/routes -H 'X-API-KEY: ${ADMIN_KEY}'"
echo ""
echo "Architecture:"
echo "-------------"
echo "Client → APISIX (API Gateway) → Istio Mesh → Services"
echo "         ├─ Rate Limiting"
echo "         ├─ Authentication"
echo "         ├─ Caching"
echo "         └─ Request Transform"
echo ""
echo "Istio Mesh:"
echo "         ├─ mTLS (automatic)"
echo "         ├─ Observability"
echo "         ├─ Traffic Management"
echo "         └─ Service Discovery"
echo ""
echo -e "${GREEN}Setup complete! Access the dashboard to manage routes.${NC}"
echo ""

# Cleanup port-forward
if [ ! -z "$PF_PID" ]; then
    kill $PF_PID 2>/dev/null || true
fi
