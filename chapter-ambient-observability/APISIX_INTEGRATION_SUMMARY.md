# APISIX Integration - Opt-in Feature Summary

## Overview

Apache APISIX has been integrated as an **optional feature** that can be deployed alongside Istio Service Mesh. This provides a complete API management layer while preserving all Istio service mesh capabilities.

## How to Enable

### Simple Command Line Flag

```bash
# Standard installation (Istio only)
./scripts/quick-start.sh

# With APISIX API Gateway
./scripts/quick-start.sh --with-apisix
```

### Configuration File (Advanced)

Edit `config.env` to set feature flags:
```bash
# Enable/disable APISIX
ENABLE_APISIX=true

# Configure APISIX settings
APISIX_REPLICAS=2
DEFAULT_RATE_LIMIT=100
API_KEY_AUTH_ENABLED=true
```

## Architecture Options

### Option 1: Istio Only (Default)
```
Client → Istio Gateway → Istio Mesh → Services
         ├─ mTLS
         ├─ Observability
         └─ Traffic Management
```

**Use when:**
- Simple service-to-service communication needed
- mTLS and observability are primary requirements
- No external API management needed

### Option 2: APISIX + Istio (Opt-in)
```
Client → APISIX (API Gateway) → Istio Mesh → Services
         ├─ Rate Limiting            ├─ mTLS
         ├─ Authentication           ├─ Observability
         ├─ Caching                  └─ Traffic Mgmt
         └─ API Management
```

**Use when:**
- Exposing services as public APIs
- Need rate limiting, API keys, quotas
- Require request/response transformation
- Want API versioning and documentation
- Need response caching at the edge

## Updated Scripts

All core scripts now support the `--with-apisix` flag:

### 1. Installation
```bash
./scripts/quick-start.sh --with-apisix
```
- Deploys Istio + observability + APISIX
- Configures pre-defined routes
- Sets up API key authentication
- Enables rate limiting

### 2. Verification
```bash
./scripts/verify-installation.sh --with-apisix
```
- Runs 23 standard Istio checks
- Adds 7 APISIX-specific checks
- Validates APISIX ↔ Istio connectivity
- Checks API Gateway functionality

### 3. Cleanup
```bash
./scripts/cleanup.sh --with-apisix
```
- Auto-detects APISIX installation
- Removes APISIX components
- Cleans up Istio and applications

### 4. APISIX-Specific Scripts
```bash
# Deploy only APISIX (assumes Istio is installed)
./scripts/deploy-apisix.sh

# Test APISIX integration
./scripts/test-apisix.sh
```

## Files Added

### Manifests
- `manifests/apisix-deployment.yaml` - Core APISIX components
- `manifests/apisix-dashboard.yaml` - Management UI
- `manifests/apisix-plugins.yaml` - Global plugins and consumers
- `manifests/apisix-routes.yaml` - Route configuration examples

### Documentation
- `APISIX_ISTIO_INTEGRATION.md` - Complete architecture guide
- `APISIX_QUICKSTART.md` - Quick reference
- `config.env` - Feature flags and configuration

### Scripts
- `scripts/deploy-apisix.sh` - APISIX deployment automation
- `scripts/test-apisix.sh` - Integration testing

## Access Points (When APISIX Enabled)

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| APISIX Gateway | `http://localhost:30800` | 30800 | API Gateway (NodePort) |
| APISIX Dashboard | `http://localhost:30900` | 30900 | Management UI |
| APISIX Admin API | `http://localhost:30180` | 30180 | Configuration API |
| Istio Gateway | `http://<MINIKUBE_IP>:30080` | 30080 | Service Mesh Gateway |

## Pre-configured Features

When APISIX is enabled, you get:

### 1. Rate Limited Routes
```bash
# Productpage: 100 req/min
curl http://localhost:30800/productpage
```

### 2. API Key Authentication
```bash
# Protected API endpoints
curl http://localhost:30800/api/v1/products/1 \
  -H 'apikey: apikey-12345678901234567890'
```

### 3. Response Caching
```bash
# Static content cached for 1 hour
curl http://localhost:30800/static/bootstrap.min.css
```

### 4. Request Tracing
```bash
# All requests get X-Request-Id for end-to-end tracking
curl -I http://localhost:30800/productpage | grep X-Request-Id
```

### 5. Prometheus Metrics
```bash
# APISIX exports metrics alongside Istio
curl http://localhost:30800/apisix/prometheus/metrics
```

## Feature Comparison

| Feature | Istio Only | APISIX + Istio |
|---------|-----------|----------------|
| mTLS (service-to-service) | ✅ Automatic | ✅ Automatic |
| Distributed Tracing | ✅ Yes | ✅ Yes (enhanced) |
| Traffic Management | ✅ Yes | ✅ Yes |
| Rate Limiting | ❌ No | ✅ Per route |
| API Key Auth | ❌ No | ✅ Built-in |
| Response Caching | ❌ No | ✅ Configurable |
| API Versioning | Manual | ✅ Built-in |
| API Documentation | Manual | ✅ OpenAPI support |
| Request Transform | Limited | ✅ Full support |
| Dashboard | Kiali (mesh) | ✅ APISIX Dashboard |

## Migration Path

### Start with Istio Only
```bash
./scripts/quick-start.sh
# Test and validate
./scripts/verify-installation.sh
```

### Add APISIX Later
```bash
# APISIX can be deployed to existing Istio installation
./scripts/deploy-apisix.sh
./scripts/test-apisix.sh
```

### Remove APISIX
```bash
kubectl delete namespace apisix
# Istio continues to work independently
```

## Production Considerations

### When to Enable APISIX

**Enable APISIX if you need:**
- Public API exposure with rate limiting
- API key or OAuth authentication
- Response caching to reduce backend load
- API analytics and monitoring
- API documentation portal
- Complex request/response transformations

**Skip APISIX if you only need:**
- Internal service-to-service communication
- Basic mTLS and observability
- Simple traffic routing
- Minimal resource footprint

### Resource Requirements

**Istio Only:**
- Control Plane: ~2 GB RAM
- ztunnel: ~100 MB per node
- Total: ~4-6 GB for test environment

**APISIX + Istio:**
- Additional: ~2 GB RAM for APISIX stack
- Total: ~6-8 GB for test environment

## Quick Reference Commands

```bash
# Installation
./scripts/quick-start.sh --with-apisix

# Verification
./scripts/verify-installation.sh --with-apisix

# Test APISIX
./scripts/test-apisix.sh

# Cleanup
./scripts/cleanup.sh --with-apisix

# Access Dashboard
kubectl port-forward -n apisix svc/apisix-dashboard 30900:9000
# Open http://localhost:30900 (admin/admin)

# View Routes
curl http://localhost:30180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'
```

## Documentation Links

- **Architecture Details**: [APISIX_ISTIO_INTEGRATION.md](APISIX_ISTIO_INTEGRATION.md)
- **Quick Start Guide**: [APISIX_QUICKSTART.md](APISIX_QUICKSTART.md)
- **Main README**: [README.md](README.md)
- **Configuration**: [config.env](config.env)

## Summary

APISIX integration is designed as a **true opt-in feature**:
- ✅ Zero impact when not enabled
- ✅ Simple command line flag to enable
- ✅ Comprehensive documentation
- ✅ Automated deployment and testing
- ✅ Easy to add or remove
- ✅ Complements Istio without interference

**Default behavior**: Standard Istio installation (backward compatible)  
**Opt-in behavior**: Full-featured API Gateway + Service Mesh
