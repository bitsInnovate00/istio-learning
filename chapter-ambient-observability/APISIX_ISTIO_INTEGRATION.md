# Apache APISIX + Istio Service Mesh Integration

## Architecture Overview

This integration combines **Apache APISIX** as the API Gateway with **Istio Service Mesh** to provide comprehensive API management and service mesh capabilities.

```
┌─────────────────────────────────────────────────────────────────┐
│                        External Traffic                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                ┌────────────────────────┐
                │   Apache APISIX        │
                │   API Gateway          │
                │   (NodePort 30800)     │
                │                        │
                │  • Rate Limiting       │
                │  • Authentication      │
                │  • API Versioning      │
                │  • Caching             │
                │  • Request Transform   │
                └────────┬───────────────┘
                         │
                         ▼
                ┌────────────────────────┐
                │  Istio Service Mesh    │
                │  (Ambient Mode)        │
                │                        │
                │  • mTLS (ztunnel)      │
                │  • Observability       │
                │  • Traffic Management  │
                │  • Service Discovery   │
                └────────┬───────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │Product  │    │Reviews  │    │Ratings  │
    │Page     │    │Service  │    │Service  │
    └─────────┘    └─────────┘    └─────────┘
```

## Separation of Concerns

### Apache APISIX Responsibilities (API Gateway Layer)
- **API Management**: Rate limiting, quotas, API keys
- **Authentication/Authorization**: OAuth2, JWT, Key-Auth, Basic Auth
- **Request/Response Transformation**: Header manipulation, body transformation
- **Caching**: Response caching for improved performance
- **API Documentation**: OpenAPI/Swagger integration
- **API Analytics**: Request tracking, usage metrics
- **Traffic Control**: A/B testing at API level, canary releases
- **Protocol Translation**: REST to gRPC, GraphQL proxying

### Istio Responsibilities (Service Mesh Layer)
- **Security**: Automatic mTLS between services, zero-trust networking
- **Traffic Management**: Load balancing, retries, timeouts, circuit breaking
- **Observability**: Distributed tracing, metrics, access logs
- **Service Discovery**: Automatic service registration
- **Resilience**: Fault injection, outlier detection
- **Multi-cluster**: Cross-cluster communication

## Key Benefits of This Architecture

1. **Best-of-Breed**: Use specialized tools for their strengths
2. **Defense in Depth**: Multiple layers of security
3. **Flexibility**: Change API Gateway without affecting mesh
4. **Scalability**: Scale components independently
5. **Observability**: End-to-end visibility from edge to services

## Components Deployed

### 1. APISIX Gateway
- **Namespace**: `apisix`
- **Service**: `apisix-gateway` (NodePort 30800)
- **Admin API**: Port 30180
- **Prometheus Metrics**: Port 9091
- **Replicas**: 2

### 2. APISIX Dashboard
- **Service**: `apisix-dashboard` (NodePort 30900)
- **Default Credentials**: admin/admin
- **Features**: Visual route management, plugin configuration

### 3. etcd
- **Purpose**: APISIX configuration storage
- **Type**: StatefulSet with persistent storage

### 4. Integration Points
- APISIX routes traffic to Istio mesh services
- Both systems export metrics to Prometheus
- Distributed tracing integration (Zipkin/Jaeger)
- APISIX operates in ambient mode for mesh participation

## Access Points

```bash
# APISIX Gateway (API traffic)
http://localhost:30800

# APISIX Dashboard (Management UI)
http://localhost:30900
# Login: admin / admin

# APISIX Admin API
http://localhost:30180/apisix/admin

# Istio Ingress Gateway
http://localhost:30080
```

## Configuration Examples

### API Gateway Features (APISIX)

#### 1. Rate Limiting
```json
{
  "plugins": {
    "limit-count": {
      "count": 100,
      "time_window": 60,
      "rejected_code": 429
    }
  }
}
```

#### 2. API Key Authentication
```json
{
  "plugins": {
    "key-auth": {}
  }
}
```

#### 3. Response Caching
```json
{
  "plugins": {
    "proxy-cache": {
      "cache_ttl": 3600,
      "cache_method": ["GET"]
    }
  }
}
```

### Service Mesh Features (Istio)

#### 1. Automatic mTLS
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
```

#### 2. Circuit Breaking
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
    outlierDetection:
      consecutiveErrors: 5
```

## Request Flow Example

### Scenario: User requests product page with rate limiting and mTLS

1. **Client** → APISIX Gateway (port 30800)
   - APISIX checks rate limit (100 req/min)
   - Validates API key if required
   - Logs request with X-Request-Id
   
2. **APISIX** → Istio ztunnel
   - Traffic enters ambient mesh
   - ztunnel establishes mTLS tunnel
   
3. **ztunnel** → ProductPage Service
   - Encrypted communication
   - Istio collects telemetry
   - Load balanced to pod
   
4. **ProductPage** → Reviews Service
   - Internal mesh communication
   - mTLS automatic
   - Istio applies retry policy
   
5. **Response Path**
   - Istio adds tracing headers
   - APISIX may cache response
   - Metrics exported to Prometheus

## Monitoring & Observability

### APISIX Metrics
- Available at: `http://apisix-gateway:9091/apisix/prometheus/metrics`
- Includes: Request rates, latencies, error rates per route

### Istio Metrics
- Available at: `http://prometheus.istio-system:9090`
- Includes: Service-to-service traffic, mTLS status, success rates

### Distributed Tracing
- APISIX exports to Jaeger/Zipkin
- Istio automatically propagates trace context
- End-to-end visibility from gateway to backend

## Use Cases

### Use APISIX When:
- Exposing internal services as public APIs
- Need API versioning (`/v1/products`, `/v2/products`)
- Require complex rate limiting per consumer
- Need request/response transformation
- Want to cache responses at the edge
- Need OAuth2/JWT validation
- Require API documentation portal

### Use Istio When:
- Service-to-service communication
- Need automatic mTLS without code changes
- Require traffic shifting between versions
- Need fine-grained observability
- Want fault injection for testing
- Require multi-cluster communication
- Need security policies between services

## Migration Strategy

### Phase 1: APISIX as Frontend (Current)
- APISIX handles external traffic
- Routes to Istio mesh services
- Minimal changes to existing setup

### Phase 2: Gradual Feature Migration
- Move rate limiting to APISIX for external APIs
- Keep Istio for internal service mesh
- Use APISIX Dashboard for API management

### Phase 3: Full Integration
- APISIX for all external-facing APIs
- Istio for all internal service communication
- Unified observability with Prometheus + Grafana

## Troubleshooting

### APISIX Cannot Reach Istio Services
```bash
# Check APISIX can resolve service
kubectl exec -n apisix deploy/apisix -- nslookup productpage.bookinfo.svc.cluster.local

# Check APISIX logs
kubectl logs -n apisix deploy/apisix -f
```

### Routes Not Working
```bash
# List all routes via Admin API
curl http://localhost:30180/apisix/admin/routes -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# Check APISIX configuration
kubectl get cm -n apisix apisix-config -o yaml
```

### Performance Issues
```bash
# Check APISIX metrics
curl http://localhost:30800/apisix/prometheus/metrics

# Check Istio metrics
kubectl exec -n istio-system deploy/istiod -- pilot-agent request GET stats/prometheus
```

## Security Considerations

1. **Change Default Credentials**
   - APISIX Admin API key
   - Dashboard admin password

2. **Network Policies**
   - Restrict access to APISIX Admin API
   - Limit etcd access to APISIX only

3. **TLS Configuration**
   - Enable HTTPS on APISIX (port 9443)
   - Use cert-manager for certificate management

4. **Audit Logging**
   - Enable APISIX access logs
   - Forward to centralized logging system

## Next Steps

1. Deploy the manifests (see `deploy-apisix.sh`)
2. Configure routes via Dashboard or Admin API
3. Set up authentication for production
4. Enable HTTPS with proper certificates
5. Configure monitoring and alerting
6. Implement backup strategy for etcd

## References

- [Apache APISIX Documentation](https://apisix.apache.org/docs/)
- [Istio Ambient Mesh](https://istio.io/latest/docs/ambient/)
- [Integration Best Practices](https://apisix.apache.org/blog/)
