# Apache APISIX + Istio Quick Start Guide

## Overview
This guide helps you deploy Apache APISIX as an API Gateway alongside Istio Service Mesh for comprehensive API management and service mesh capabilities.

## Architecture
```
External Traffic → APISIX (API Gateway) → Istio Mesh → Services
                   ├─ Rate Limiting          ├─ mTLS
                   ├─ Authentication         ├─ Observability
                   ├─ Caching                └─ Traffic Mgmt
                   └─ Transformation
```

## Quick Start

### 1. Deploy APISIX
```bash
cd /home/user/work/study/istio/Practical-Istio/chapter-ambient-observability
./scripts/deploy-apisix.sh
```

This script will:
- Create the `apisix` namespace with ambient mode
- Deploy etcd for configuration storage
- Deploy APISIX Gateway (2 replicas)
- Deploy APISIX Dashboard
- Configure initial routes and plugins
- Create API consumers for authentication

### 2. Verify Deployment
```bash
./scripts/test-apisix.sh
```

### 3. Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| APISIX Gateway | http://localhost:30800 | - |
| APISIX Dashboard | http://localhost:30900 | admin/admin |
| APISIX Admin API | http://localhost:30180/apisix/admin | X-API-KEY header |
| Istio Gateway | http://localhost:30080 | - |

## Example Usage

### Basic Request
```bash
# Access productpage through APISIX
curl http://localhost:30800/productpage
```

### Authenticated API Request
```bash
# Access API endpoint with authentication
curl http://localhost:30800/api/v1/products/1 \
  -H 'apikey: apikey-12345678901234567890'
```

### View Metrics
```bash
# APISIX metrics
curl http://localhost:30800/apisix/prometheus/metrics
```

### Manage Routes via Admin API
```bash
# List all routes
curl http://localhost:30180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# Create new route
curl -X PUT http://localhost:30180/apisix/admin/routes/10 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -H 'Content-Type: application/json' \
  -d '{
    "uri": "/new-api/*",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "myservice.namespace.svc.cluster.local:8080": 1
      }
    }
  }'
```

## Pre-configured Routes

1. **Productpage Route** (`/productpage`)
   - Rate limit: 100 req/min
   - CORS enabled
   - Prometheus metrics

2. **Static Content** (`/static/*`)
   - Response caching (1 hour TTL)
   - GET only

3. **API Endpoints** (`/api/v1/products/*`)
   - API key authentication required
   - Rate limit: 200 req/min
   - Request ID tracking

4. **Auth Routes** (`/login`, `/logout`)
   - Rate limit: 20 req/min

## API Gateway Features

### Rate Limiting
Automatically applied per route. Productpage limited to 100 requests/minute.

### Authentication
API key authentication for `/api/v1/*` endpoints.

**Test with valid key:**
```bash
curl http://localhost:30800/api/v1/products/1 \
  -H 'apikey: apikey-12345678901234567890'
```

### Caching
Static content cached for 1 hour, reducing load on backend services.

### Request Tracing
All requests get `X-Request-Id` header for end-to-end tracing.

## Managing via Dashboard

1. Open http://localhost:30900
2. Login with `admin` / `admin`
3. Navigate to **Routes** to view/edit routes
4. Use **Plugins** section to configure features
5. Check **Consumers** for API key management

## Integration with Istio

### How It Works
1. APISIX handles API management concerns
2. Traffic enters Istio ambient mesh
3. ztunnel provides automatic mTLS
4. Istio handles service-to-service communication
5. Both systems export metrics to Prometheus

### Complementary Features

**APISIX handles:**
- External API exposure
- Rate limiting per API
- API versioning
- Request/response transformation
- API key management

**Istio handles:**
- Service-to-service mTLS
- Internal traffic management
- Distributed tracing
- Service discovery
- Circuit breaking

## Monitoring

### APISIX Metrics
```bash
curl http://localhost:30800/apisix/prometheus/metrics | grep apisix_http_requests_total
```

### Check Route Performance
```bash
# View latency per route in Dashboard
# Or query Prometheus
curl http://localhost:30800/apisix/prometheus/metrics | grep apisix_http_latency
```

## Troubleshooting

### APISIX Can't Reach Services
```bash
# Test DNS resolution
kubectl exec -n apisix deploy/apisix -- \
  nslookup productpage.bookinfo.svc.cluster.local

# Test connectivity
kubectl exec -n apisix deploy/apisix -- \
  curl -v http://productpage.bookinfo.svc.cluster.local:9080/productpage
```

### Routes Not Working
```bash
# Check APISIX logs
kubectl logs -n apisix deploy/apisix -f

# Verify route configuration
curl http://localhost:30180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' | jq
```

### Authentication Failing
```bash
# List consumers
curl http://localhost:30180/apisix/admin/consumers \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# Check if consumer exists
curl http://localhost:30180/apisix/admin/consumers/api-user \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'
```

## Common Tasks

### Add New API Consumer
```bash
curl -X PUT http://localhost:30180/apisix/admin/consumers \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -d '{
    "username": "new-user",
    "plugins": {
      "key-auth": {
        "key": "user-api-key-here"
      }
    }
  }'
```

### Update Rate Limit
```bash
curl -X PATCH http://localhost:30180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -d '{
    "plugins": {
      "limit-count": {
        "count": 200,
        "time_window": 60
      }
    }
  }'
```

### Enable Circuit Breaking
Add to any route via Admin API or Dashboard:
```json
{
  "plugins": {
    "limit-count": {...},
    "api-breaker": {
      "break_response_code": 502,
      "unhealthy": {
        "http_statuses": [500, 503],
        "failures": 3
      },
      "healthy": {
        "http_statuses": [200],
        "successes": 3
      }
    }
  }
}
```

## Production Checklist

- [ ] Change APISIX admin API key
- [ ] Change dashboard password
- [ ] Enable HTTPS (port 30443)
- [ ] Configure proper rate limits
- [ ] Set up network policies
- [ ] Configure etcd backup
- [ ] Set resource limits appropriately
- [ ] Enable audit logging
- [ ] Configure alerting for rate limit hits
- [ ] Set up certificate management

## Files Reference

| File | Purpose |
|------|---------|
| `manifests/apisix-deployment.yaml` | Core APISIX components |
| `manifests/apisix-dashboard.yaml` | Management UI |
| `manifests/apisix-plugins.yaml` | Plugin configs & consumers |
| `manifests/apisix-routes.yaml` | Route examples (documentation) |
| `scripts/deploy-apisix.sh` | Automated deployment |
| `scripts/test-apisix.sh` | Integration tests |
| `APISIX_ISTIO_INTEGRATION.md` | Detailed architecture docs |

## Next Steps

1. Explore the Dashboard UI for visual management
2. Configure additional routes for your services
3. Set up authentication for production APIs
4. Enable distributed tracing integration
5. Configure alerting in Prometheus/Grafana
6. Review the comprehensive docs in `APISIX_ISTIO_INTEGRATION.md`

## Resources

- [APISIX Documentation](https://apisix.apache.org/docs/)
- [APISIX Plugins](https://apisix.apache.org/docs/apisix/plugins/prometheus/)
- [Istio Ambient Mesh](https://istio.io/latest/docs/ambient/)
- Project Docs: `APISIX_ISTIO_INTEGRATION.md`
