# Enterprise API Management Enhancement Guide

## Overview

This guide extends your existing **APISIX + Istio** integration to provide comprehensive **enterprise-grade API management** capabilities beyond basic routing and authentication.

**Current State:**
- ✅ Basic rate limiting
- ✅ Key-based authentication  
- ✅ Response caching
- ✅ Prometheus metrics

**What This Guide Adds:**
- 🚀 Developer Portal
- 📚 OpenAPI/Swagger Documentation
- 🔐 Advanced Authentication (OAuth2, JWT, OIDC)
- 📊 API Analytics & Monitoring
- 🎯 API Versioning Strategy
- 💰 Quota Management & Monetization
- 🧪 API Mocking & Testing
- 🔔 Webhook Support
- 🌐 Multi-tenancy

---

## Table of Contents

1. [API Documentation & Discovery](#1-api-documentation--discovery)
2. [Advanced Authentication](#2-advanced-authentication)
3. [API Versioning](#3-api-versioning)
4. [Developer Portal](#4-developer-portal)
5. [API Analytics](#5-api-analytics)
6. [Quota Management](#6-quota-management)
7. [API Lifecycle Management](#7-api-lifecycle-management)
8. [Testing & Mocking](#8-testing--mocking)
9. [Multi-tenancy](#9-multi-tenancy)
10. [Complete Example](#10-complete-example)

---

## 1. API Documentation & Discovery

### 1.1 OpenAPI Specification Integration

Create OpenAPI specs for your Bookinfo APIs:

```yaml
# filepath: manifests/openapi-bookinfo.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bookinfo-openapi-spec
  namespace: apisix
data:
  openapi.yaml: |
    openapi: 3.0.0
    info:
      title: Bookinfo API
      version: 1.0.0
      description: Book catalog and review management API
      contact:
        name: API Support
        email: api@bookinfo.com
    servers:
      - url: http://localhost:9080
        description: Development server
      - url: https://api.bookinfo.com
        description: Production server
    
    paths:
      /api/v1/products:
        get:
          summary: List all products
          operationId: listProducts
          tags:
            - Products
          security:
            - ApiKeyAuth: []
          responses:
            '200':
              description: Successful response
              content:
                application/json:
                  schema:
                    type: array
                    items:
                      $ref: '#/components/schemas/Product'
            '401':
              description: Unauthorized
            '429':
              description: Rate limit exceeded
      
      /api/v1/products/{id}:
        get:
          summary: Get product by ID
          operationId: getProduct
          tags:
            - Products
          security:
            - ApiKeyAuth: []
          parameters:
            - name: id
              in: path
              required: true
              schema:
                type: integer
          responses:
            '200':
              description: Product details
              content:
                application/json:
                  schema:
                    $ref: '#/components/schemas/Product'
            '404':
              description: Product not found
      
      /api/v1/products/{id}/reviews:
        get:
          summary: Get product reviews
          operationId: getProductReviews
          tags:
            - Reviews
          parameters:
            - name: id
              in: path
              required: true
              schema:
                type: integer
          responses:
            '200':
              description: Product reviews
              content:
                application/json:
                  schema:
                    type: array
                    items:
                      $ref: '#/components/schemas/Review'
    
    components:
      securitySchemes:
        ApiKeyAuth:
          type: apiKey
          in: header
          name: apikey
          description: API key for authentication
        OAuth2:
          type: oauth2
          flows:
            clientCredentials:
              tokenUrl: /oauth/token
              scopes:
                read:products: Read product information
                write:products: Modify products
                read:reviews: Read reviews
                write:reviews: Write reviews
        BearerAuth:
          type: http
          scheme: bearer
          bearerFormat: JWT
      
      schemas:
        Product:
          type: object
          properties:
            id:
              type: integer
              example: 1
            title:
              type: string
              example: "The Comedy of Errors"
            descriptionHtml:
              type: string
            isbn:
              type: string
              example: "1234567890"
            author:
              type: string
              example: "William Shakespeare"
            year:
              type: integer
              example: 1595
            type:
              type: string
              enum: [paperback, hardcover]
            pages:
              type: integer
            publisher:
              type: string
            language:
              type: string
            rating:
              type: number
              format: float
              minimum: 0
              maximum: 5
        
        Review:
          type: object
          properties:
            id:
              type: integer
            reviewer:
              type: string
            rating:
              type: integer
              minimum: 1
              maximum: 5
            text:
              type: string
            createdAt:
              type: string
              format: date-time
```

### 1.2 Deploy Swagger UI

```yaml
# filepath: manifests/swagger-ui.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: swagger-ui-config
  namespace: apisix
data:
  swagger-config.json: |
    {
      "urls": [
        {
          "url": "/openapi/bookinfo.yaml",
          "name": "Bookinfo API v1"
        }
      ],
      "deepLinking": true,
      "displayOperationId": true,
      "defaultModelsExpandDepth": 3,
      "defaultModelExpandDepth": 3,
      "displayRequestDuration": true,
      "filter": true,
      "showExtensions": true,
      "showCommonExtensions": true,
      "tryItOutEnabled": true
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: swagger-ui
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: swagger-ui
  template:
    metadata:
      labels:
        app: swagger-ui
    spec:
      containers:
      - name: swagger-ui
        image: swaggerapi/swagger-ui:v5.10.0
        ports:
        - containerPort: 8080
        env:
        - name: SWAGGER_JSON_URL
          value: /openapi/bookinfo.yaml
        - name: BASE_URL
          value: /api-docs
        volumeMounts:
        - name: openapi-spec
          mountPath: /usr/share/nginx/html/openapi
        - name: swagger-config
          mountPath: /usr/share/nginx/html/swagger-config.json
          subPath: swagger-config.json
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: openapi-spec
        configMap:
          name: bookinfo-openapi-spec
      - name: swagger-config
        configMap:
          name: swagger-ui-config
---
apiVersion: v1
kind: Service
metadata:
  name: swagger-ui
  namespace: apisix
spec:
  selector:
    app: swagger-ui
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP
```

### 1.3 Configure APISIX Route for API Docs

```bash
#!/bin/bash
# filepath: scripts/configure-api-docs.sh

kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 &
PF_PID=$!
sleep 3

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Route for Swagger UI
curl -i -X PUT "$ADMIN_API/routes/10" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api-docs/*",
    "name": "swagger-ui",
    "methods": ["GET"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "swagger-ui.apisix.svc.cluster.local:8080": 1
      }
    },
    "plugins": {
      "proxy-rewrite": {
        "regex_uri": ["^/api-docs/(.*)", "/$1"]
      },
      "cors": {
        "allow_origins": "*",
        "allow_methods": "GET,POST,PUT,DELETE,OPTIONS",
        "allow_headers": "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization",
        "expose_headers": "Content-Length,Content-Range",
        "max_age": 3600
      }
    }
  }'

# Route for OpenAPI spec
curl -i -X PUT "$ADMIN_API/routes/11" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/openapi/*",
    "name": "openapi-spec",
    "methods": ["GET"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "swagger-ui.apisix.svc.cluster.local:8080": 1
      }
    }
  }'

kill $PF_PID
echo "✅ API documentation routes configured"
echo "📚 Access Swagger UI: kubectl port-forward -n apisix svc/apisix-gateway 9080:9080"
echo "   Then open: http://localhost:9080/api-docs/"
```

---

## 2. Advanced Authentication

### 2.1 JWT Authentication

```bash
# Create JWT signing key
kubectl create secret generic jwt-secret \
  -n apisix \
  --from-literal=secret-key="your-256-bit-secret-key-here"
```

```bash
#!/bin/bash
# filepath: scripts/configure-jwt-auth.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Create JWT consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "jwt_user",
    "plugins": {
      "jwt-auth": {
        "key": "jwt-key-001",
        "secret": "your-256-bit-secret-key-here",
        "algorithm": "HS256",
        "exp": 86400
      }
    }
  }'

# Update API route with JWT auth
curl -i -X PATCH "$ADMIN_API/routes/3" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "jwt-auth": {
        "header": "Authorization",
        "query": "jwt"
      },
      "limit-count": {
        "count": 1000,
        "time_window": 60,
        "rejected_code": 429,
        "key_type": "consumer"
      }
    }
  }'

echo "✅ JWT authentication configured"
```

### 2.2 OAuth2 Integration

```yaml
# filepath: manifests/oauth2-provider.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-config
  namespace: apisix
data:
  oauth2.yaml: |
    providers:
      - name: keycloak
        issuer: https://keycloak.example.com/realms/bookinfo
        authorization_endpoint: /protocol/openid-connect/auth
        token_endpoint: /protocol/openid-connect/token
        userinfo_endpoint: /protocol/openid-connect/userinfo
        jwks_uri: /protocol/openid-connect/certs
        client_id: bookinfo-api
        client_secret: ${OAUTH2_CLIENT_SECRET}
        scopes:
          - openid
          - profile
          - email
          - read:products
          - write:products
```

```bash
#!/bin/bash
# filepath: scripts/configure-oauth2.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Configure OAuth2 plugin
curl -i -X PUT "$ADMIN_API/routes/12" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v2/*",
    "name": "api-v2-oauth",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "openid-connect": {
        "client_id": "bookinfo-api",
        "client_secret": "your-client-secret",
        "discovery": "https://keycloak.example.com/realms/bookinfo/.well-known/openid-configuration",
        "scope": "openid profile email",
        "bearer_only": true,
        "realm": "bookinfo",
        "introspection_endpoint_auth_method": "client_secret_post"
      }
    }
  }'
```

### 2.3 Multi-Auth Strategy

```bash
#!/bin/bash
# filepath: scripts/configure-multi-auth.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Route supporting multiple auth methods
curl -i -X PUT "$ADMIN_API/routes/13" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/products/*",
    "name": "api-multi-auth",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "consumer-restriction": {
        "type": "consumer_name"
      },
      "key-auth": {},
      "jwt-auth": {},
      "hmac-auth": {}
    }
  }'

echo "✅ Multi-authentication strategy configured"
echo "Supports: API Key, JWT, HMAC"
```

---

## 3. API Versioning

### 3.1 URL Path Versioning

```bash
#!/bin/bash
# filepath: scripts/configure-api-versioning.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# API v1 - Stable (current production)
curl -i -X PUT "$ADMIN_API/routes/20" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/*",
    "name": "api-v1-stable",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 100,
        "time_window": 60,
        "rejected_code": 429
      },
      "response-rewrite": {
        "headers": {
          "X-API-Version": "v1",
          "X-API-Status": "stable"
        }
      }
    }
  }'

# API v2 - Beta (new features)
curl -i -X PUT "$ADMIN_API/routes/21" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v2/*",
    "name": "api-v2-beta",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage-v2.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 50,
        "time_window": 60,
        "rejected_code": 429
      },
      "response-rewrite": {
        "headers": {
          "X-API-Version": "v2",
          "X-API-Status": "beta",
          "X-API-Deprecation": "This version is in beta. Production use at your own risk."
        }
      }
    }
  }'

# API v0 (legacy) - Deprecated
curl -i -X PUT "$ADMIN_API/routes/22" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v0/*",
    "name": "api-v0-deprecated",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage-legacy.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 10,
        "time_window": 60,
        "rejected_code": 429
      },
      "response-rewrite": {
        "headers": {
          "X-API-Version": "v0",
          "X-API-Status": "deprecated",
          "X-API-Deprecation": "This API version is deprecated. Please migrate to v1. Sunset date: 2025-12-31",
          "Sunset": "Sat, 31 Dec 2025 23:59:59 GMT"
        }
      }
    }
  }'

echo "✅ API versioning configured"
echo "  - /api/v0/* - Deprecated (10 req/min)"
echo "  - /api/v1/* - Stable (100 req/min)"
echo "  - /api/v2/* - Beta (50 req/min)"
```

### 3.2 Header-Based Versioning

```bash
# Alternative: Accept header versioning
curl -i -X PUT "$ADMIN_API/routes/23" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/products/*",
    "name": "api-header-versioning",
    "vars": [
      ["http_accept", "~~", "application/vnd.bookinfo.v2+json"]
    ],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage-v2.bookinfo.svc.cluster.local:9080": 1
      }
    }
  }'
```

---

## 4. Developer Portal

### 4.1 Deploy Developer Portal

```yaml
# filepath: manifests/developer-portal.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: portal-config
  namespace: apisix
data:
  config.json: |
    {
      "title": "Bookinfo API Developer Portal",
      "description": "Access Bookinfo APIs with comprehensive documentation",
      "apis": [
        {
          "name": "Products API",
          "version": "v1",
          "description": "Manage book catalog",
          "spec": "/openapi/bookinfo.yaml",
          "baseUrl": "http://localhost:9080/api/v1"
        }
      ],
      "authentication": {
        "methods": ["apiKey", "jwt", "oauth2"],
        "signupEnabled": true
      },
      "features": {
        "apiExplorer": true,
        "interactiveDocs": true,
        "codeGeneration": true,
        "analytics": true
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: developer-portal
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: developer-portal
  template:
    metadata:
      labels:
        app: developer-portal
    spec:
      containers:
      - name: portal
        image: stoplight/prism:latest
        ports:
        - containerPort: 4010
        env:
        - name: PORT
          value: "4010"
        volumeMounts:
        - name: openapi-spec
          mountPath: /specs
        - name: portal-config
          mountPath: /config
        command:
        - prism
        - mock
        - -h
        - "0.0.0.0"
        - /specs/openapi.yaml
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: openapi-spec
        configMap:
          name: bookinfo-openapi-spec
      - name: portal-config
        configMap:
          name: portal-config
---
apiVersion: v1
kind: Service
metadata:
  name: developer-portal
  namespace: apisix
spec:
  selector:
    app: developer-portal
  ports:
  - name: http
    port: 4010
    targetPort: 4010
  type: ClusterIP
```

### 4.2 Self-Service API Key Management

```yaml
# filepath: manifests/api-key-service.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-key-manager-config
  namespace: apisix
data:
  config.yaml: |
    server:
      port: 8080
    database:
      type: postgres
      host: postgres.apisix.svc.cluster.local
      port: 5432
      name: apikeys
    apisix:
      adminUrl: http://apisix-admin.apisix.svc.cluster.local:9180
      adminKey: edd1c9f034335f136f87ad84b625c8f1
    features:
      selfServiceSignup: true
      emailVerification: true
      quotaManagement: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-key-manager
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-key-manager
  template:
    metadata:
      labels:
        app: api-key-manager
    spec:
      containers:
      - name: manager
        image: your-registry/api-key-manager:1.0
        ports:
        - containerPort: 8080
        env:
        - name: APISIX_ADMIN_URL
          value: "http://apisix-gateway.apisix.svc.cluster.local:9180"
        - name: APISIX_ADMIN_KEY
          valueFrom:
            secretKeyRef:
              name: apisix-admin-key
              key: api-key
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: api-key-manager-config
```

---

## 5. API Analytics

### 5.1 Enhanced Logging Plugin

```bash
#!/bin/bash
# filepath: scripts/configure-analytics.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Configure logging to Kafka for analytics
curl -i -X PUT "$ADMIN_API/plugin_metadata/kafka-logger" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "broker_list": {
      "kafka.apisix.svc.cluster.local:9092": {}
    },
    "kafka_topic": "apisix-logs",
    "producer_type": "async",
    "required_acks": 1,
    "timeout": 3,
    "batch_max_size": 1000,
    "max_retry_count": 2,
    "retry_interval": 1
  }'

# Apply to all API routes
curl -i -X PUT "$ADMIN_API/global_rules/2" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "kafka-logger": {
        "meta_format": "origin",
        "include_req_body": false,
        "include_resp_body": false
      },
      "http-logger": {
        "uri": "http://log-collector.apisix.svc.cluster.local:8080/api/logs",
        "batch_max_size": 100,
        "max_retry_count": 3,
        "retry_delay": 1,
        "buffer_duration": 5,
        "inactive_timeout": 2
      }
    }
  }'

echo "✅ Analytics logging configured"
```

### 5.2 Grafana Dashboard for API Analytics

```yaml
# filepath: manifests/grafana-api-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-api-dashboard
  namespace: istio-system
data:
  api-analytics.json: |
    {
      "dashboard": {
        "title": "API Analytics Dashboard",
        "panels": [
          {
            "title": "API Requests per Second",
            "targets": [
              {
                "expr": "rate(apisix_http_requests_total[5m])"
              }
            ]
          },
          {
            "title": "API Response Times (P95)",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(apisix_http_latency_bucket[5m]))"
              }
            ]
          },
          {
            "title": "Top API Consumers",
            "targets": [
              {
                "expr": "topk(10, sum by (consumer) (rate(apisix_http_requests_total[1h])))"
              }
            ]
          },
          {
            "title": "API Error Rate by Route",
            "targets": [
              {
                "expr": "rate(apisix_http_requests_total{status=~\"4..|5..\"}[5m])"
              }
            ]
          },
          {
            "title": "Rate Limit Violations",
            "targets": [
              {
                "expr": "increase(apisix_http_requests_total{status=\"429\"}[1h])"
              }
            ]
          }
        ]
      }
    }
```

---

## 6. Quota Management

### 6.1 Tiered Pricing Plans

```bash
#!/bin/bash
# filepath: scripts/configure-quota-tiers.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Free Tier Consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "free_tier_user",
    "desc": "Free tier - 1000 requests/day",
    "plugins": {
      "key-auth": {
        "key": "free-tier-key-001"
      },
      "limit-count": {
        "count": 1000,
        "time_window": 86400,
        "rejected_code": 429,
        "rejected_msg": "Free tier quota exceeded. Upgrade to Pro for more requests.",
        "policy": "local"
      }
    },
    "labels": {
      "tier": "free",
      "max_requests_per_day": "1000"
    }
  }'

# Pro Tier Consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "pro_tier_user",
    "desc": "Pro tier - 100,000 requests/day",
    "plugins": {
      "key-auth": {
        "key": "pro-tier-key-001"
      },
      "limit-count": {
        "count": 100000,
        "time_window": 86400,
        "rejected_code": 429,
        "policy": "redis",
        "redis_host": "redis.apisix.svc.cluster.local",
        "redis_port": 6379,
        "redis_timeout": 1001
      }
    },
    "labels": {
      "tier": "pro",
      "max_requests_per_day": "100000"
    }
  }'

# Enterprise Tier Consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "enterprise_tier_user",
    "desc": "Enterprise tier - Unlimited requests",
    "plugins": {
      "key-auth": {
        "key": "enterprise-tier-key-001"
      }
    },
    "labels": {
      "tier": "enterprise",
      "max_requests_per_day": "unlimited"
    }
  }'

echo "✅ Quota tiers configured"
echo "  - Free: 1,000 req/day"
echo "  - Pro: 100,000 req/day"
echo "  - Enterprise: Unlimited"
```

### 6.2 Redis for Distributed Rate Limiting

```yaml
# filepath: manifests/redis-rate-limiting.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.2-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - --appendonly
        - "yes"
        - --maxmemory
        - "512mb"
        - --maxmemory-policy
        - "allkeys-lru"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: apisix
spec:
  selector:
    app: redis
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
  type: ClusterIP
```

---

## 7. API Lifecycle Management

### 7.1 Deprecation Policy

```bash
#!/bin/bash
# filepath: scripts/deprecate-api-version.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Mark API v0 as deprecated with sunset header
curl -i -X PATCH "$ADMIN_API/routes/22" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "response-rewrite": {
        "headers": {
          "X-API-Deprecated": "true",
          "X-API-Sunset-Date": "2025-12-31",
          "X-API-Migration-Guide": "https://docs.bookinfo.com/api/v0-to-v1-migration",
          "Sunset": "Sat, 31 Dec 2025 23:59:59 GMT",
          "Link": "<https://docs.bookinfo.com/api/v1>; rel=\"successor-version\""
        }
      },
      "limit-count": {
        "count": 10,
        "time_window": 60,
        "rejected_msg": "This API version is deprecated. Please upgrade to v1."
      }
    }
  }'

echo "✅ API v0 marked as deprecated"
echo "Sunset date: 2025-12-31"
echo "Migration guide: https://docs.bookinfo.com/api/v0-to-v1-migration"
```

### 7.2 Canary Release

```bash
#!/bin/bash
# filepath: scripts/configure-canary.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Canary route - 10% traffic to v2
curl -i -X PUT "$ADMIN_API/routes/30" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/products/*",
    "name": "canary-v2",
    "upstream": {
      "type": "roundrobin",
      "nodes": [
        {
          "host": "productpage.bookinfo.svc.cluster.local",
          "port": 9080,
          "weight": 90
        },
        {
          "host": "productpage-v2.bookinfo.svc.cluster.local",
          "port": 9080,
          "weight": 10
        }
      ]
    },
    "plugins": {
      "traffic-split": {
        "rules": [
          {
            "match": [
              {
                "vars": [
                  ["http_x_canary_user", "==", "true"]
                ]
              }
            ],
            "weighted_upstreams": [
              {
                "upstream": {
                  "name": "v2-canary",
                  "type": "roundrobin",
                  "nodes": {
                    "productpage-v2.bookinfo.svc.cluster.local:9080": 1
                  }
                },
                "weight": 1
              }
            ]
          }
        ]
      }
    }
  }'

echo "✅ Canary deployment configured"
echo "  - 90% traffic → v1"
echo "  - 10% traffic → v2"
echo "  - 100% traffic → v2 for users with header 'X-Canary-User: true'"
```

---

## 8. Testing & Mocking

### 8.1 API Mocking Server

```yaml
# filepath: manifests/api-mock-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-mock-server
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-mock
  template:
    metadata:
      labels:
        app: api-mock
    spec:
      containers:
      - name: prism
        image: stoplight/prism:latest
        args:
        - mock
        - -h
        - "0.0.0.0"
        - -p
        - "4010"
        - /specs/openapi.yaml
        ports:
        - containerPort: 4010
        volumeMounts:
        - name: openapi-spec
          mountPath: /specs
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: openapi-spec
        configMap:
          name: bookinfo-openapi-spec
---
apiVersion: v1
kind: Service
metadata:
  name: api-mock-server
  namespace: apisix
spec:
  selector:
    app: api-mock
  ports:
  - name: http
    port: 4010
    targetPort: 4010
```

### 8.2 Automated API Testing

```bash
#!/bin/bash
# filepath: scripts/test-api-endpoints.sh

BASE_URL="http://localhost:9080"
API_KEY="apikey-12345678901234567890"

echo "🧪 Running API Tests..."

# Test 1: List products (authenticated)
echo -n "Test 1: GET /api/v1/products ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: $API_KEY" \
  "$BASE_URL/api/v1/products")
[ "$STATUS" = "200" ] && echo "✅ PASS" || echo "❌ FAIL (HTTP $STATUS)"

# Test 2: Get product by ID
echo -n "Test 2: GET /api/v1/products/1 ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: $API_KEY" \
  "$BASE_URL/api/v1/products/1")
[ "$STATUS" = "200" ] && echo "✅ PASS" || echo "❌ FAIL (HTTP $STATUS)"

# Test 3: Unauthorized access (no API key)
echo -n "Test 3: GET /api/v1/products (no auth) ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "$BASE_URL/api/v1/products")
[ "$STATUS" = "401" ] && echo "✅ PASS" || echo "❌ FAIL (HTTP $STATUS)"

# Test 4: Rate limiting
echo -n "Test 4: Rate limiting (101 requests) ... "
for i in {1..101}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: $API_KEY" \
    "$BASE_URL/productpage")
  if [ "$STATUS" = "429" ]; then
    echo "✅ PASS (rate limit triggered at request $i)"
    break
  fi
done

# Test 5: CORS headers
echo -n "Test 5: CORS headers ... "
CORS=$(curl -s -I -X OPTIONS \
  -H "Origin: http://example.com" \
  -H "Access-Control-Request-Method: GET" \
  "$BASE_URL/api/v1/products" | grep -i "access-control-allow-origin")
[ -n "$CORS" ] && echo "✅ PASS" || echo "❌ FAIL"

# Test 6: API versioning
echo -n "Test 6: API version header ... "
VERSION=$(curl -s -I -H "apikey: $API_KEY" \
  "$BASE_URL/api/v1/products" | grep -i "x-api-version")
[ -n "$VERSION" ] && echo "✅ PASS" || echo "❌ FAIL"

echo ""
echo "✅ API testing complete"
```

---

## 9. Multi-tenancy

### 9.1 Tenant-based Routing

```bash
#!/bin/bash
# filepath: scripts/configure-multitenancy.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Tenant A - dedicated namespace
curl -i -X PUT "$ADMIN_API/routes/40" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/tenant-a/*",
    "name": "tenant-a-api",
    "vars": [
      ["http_x_tenant_id", "==", "tenant-a"]
    ],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.tenant-a.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 10000,
        "time_window": 3600,
        "key": "x-tenant-id",
        "key_type": "var",
        "rejected_code": 429
      }
    }
  }'

# Tenant B - dedicated namespace
curl -i -X PUT "$ADMIN_API/routes/41" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/tenant-b/*",
    "name": "tenant-b-api",
    "vars": [
      ["http_x_tenant_id", "==", "tenant-b"]
    ],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.tenant-b.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 5000,
        "time_window": 3600,
        "key": "x-tenant-id",
        "key_type": "var",
        "rejected_code": 429
      }
    }
  }'

echo "✅ Multi-tenancy configured"
echo "  - Tenant A: 10,000 req/hour"
echo "  - Tenant B: 5,000 req/hour"
```

---

## 10. Complete Example

### 10.1 Comprehensive Deployment Script

```bash
#!/bin/bash
# filepath: scripts/deploy-enterprise-api-management.sh

set -e

echo "========================================"
echo "Enterprise API Management Deployment"
echo "========================================"
echo ""

# Step 1: Deploy OpenAPI documentation
echo "📚 Step 1: Deploying API documentation..."
kubectl apply -f manifests/openapi-bookinfo.yaml
kubectl apply -f manifests/swagger-ui.yaml
kubectl wait --for=condition=ready pod -l app=swagger-ui -n apisix --timeout=120s
echo "✅ API documentation deployed"
echo ""

# Step 2: Configure advanced authentication
echo "🔐 Step 2: Configuring advanced authentication..."
./scripts/configure-jwt-auth.sh
./scripts/configure-multi-auth.sh
echo "✅ Advanced authentication configured"
echo ""

# Step 3: Set up API versioning
echo "🔢 Step 3: Setting up API versioning..."
./scripts/configure-api-versioning.sh
echo "✅ API versioning configured"
echo ""

# Step 4: Deploy developer portal
echo "👨‍💻 Step 4: Deploying developer portal..."
kubectl apply -f manifests/developer-portal.yaml
kubectl wait --for=condition=ready pod -l app=developer-portal -n apisix --timeout=120s
echo "✅ Developer portal deployed"
echo ""

# Step 5: Configure analytics
echo "📊 Step 5: Configuring analytics..."
kubectl apply -f manifests/grafana-api-dashboard.yaml
./scripts/configure-analytics.sh
echo "✅ Analytics configured"
echo ""

# Step 6: Set up quota management
echo "💰 Step 6: Setting up quota management..."
kubectl apply -f manifests/redis-rate-limiting.yaml
kubectl wait --for=condition=ready pod -l app=redis -n apisix --timeout=120s
./scripts/configure-quota-tiers.sh
echo "✅ Quota management configured"
echo ""

# Step 7: Deploy API mocking
echo "🧪 Step 7: Deploying API mocking server..."
kubectl apply -f manifests/api-mock-server.yaml
kubectl wait --for=condition=ready pod -l app=api-mock -n apisix --timeout=120s
echo "✅ API mocking deployed"
echo ""

# Step 8: Run tests
echo "🧪 Step 8: Running API tests..."
./scripts/test-api-endpoints.sh
echo ""

echo "========================================"
echo "✅ Enterprise API Management Deployed!"
echo "========================================"
echo ""
echo "📍 Access Points:"
echo "  • API Gateway:        kubectl port-forward -n apisix svc/apisix-gateway 9080:9080"
echo "  • API Documentation:  http://localhost:9080/api-docs/"
echo "  • Developer Portal:   kubectl port-forward -n apisix svc/developer-portal 4010:4010"
echo "  • API Mock Server:    kubectl port-forward -n apisix svc/api-mock-server 4010:4010"
echo "  • APISIX Dashboard:   kubectl port-forward -n apisix svc/apisix-dashboard 9000:9000"
echo "  • Grafana (Analytics): kubectl port-forward -n istio-system svc/grafana 3000:3000"
echo ""
echo "🔑 API Tiers:"
echo "  • Free:       1,000 requests/day"
echo "  • Pro:        100,000 requests/day"
echo "  • Enterprise: Unlimited"
echo ""
echo "📚 Next Steps:"
echo "  1. Access Swagger UI: http://localhost:9080/api-docs/"
echo "  2. Generate API key: kubectl port-forward -n apisix svc/api-key-manager 8080:8080"
echo "  3. View analytics: http://localhost:3000 (Grafana)"
echo "  4. Test endpoints: ./scripts/test-api-endpoints.sh"
echo ""
```

### 10.2 Verification Script

```bash
#!/bin/bash
# filepath: scripts/verify-enterprise-api-management.sh

echo "🔍 Verifying Enterprise API Management..."
echo ""

CHECKS=0
PASSED=0

# Check 1: Swagger UI
echo -n "✓ Checking Swagger UI ... "
if kubectl get pod -l app=swagger-ui -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 2: Developer Portal
echo -n "✓ Checking Developer Portal ... "
if kubectl get pod -l app=developer-portal -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 3: Redis (for rate limiting)
echo -n "✓ Checking Redis ... "
if kubectl get pod -l app=redis -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 4: API Mock Server
echo -n "✓ Checking API Mock Server ... "
if kubectl get pod -l app=api-mock -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 5: JWT consumers
echo -n "✓ Checking JWT consumers ... "
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://localhost:9180/apisix/admin/consumers | grep -q "jwt_user"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
kill $PF_PID 2>/dev/null
((CHECKS++))

# Check 6: API versioning routes
echo -n "✓ Checking API versioning routes ... "
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://localhost:9180/apisix/admin/routes | grep -q "api-v1-stable"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
kill $PF_PID 2>/dev/null
((CHECKS++))

# Check 7: Quota tiers
echo -n "✓ Checking quota tier consumers ... "
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://localhost:9180/apisix/admin/consumers | grep -q "free_tier_user"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
kill $PF_PID 2>/dev/null
((CHECKS++))

echo ""
echo "========================================"
echo "Verification Results: $PASSED/$CHECKS checks passed"
echo "========================================"

if [ $PASSED -eq $CHECKS ]; then
  echo "✅ All enterprise API management features verified!"
  exit 0
else
  echo "⚠️  Some checks failed. Please review the output above."
  exit 1
fi
```

---

## Summary

This enhancement guide provides:

✅ **API Documentation** - OpenAPI specs + Swagger UI
✅ **Advanced Authentication** - JWT, OAuth2, Multi-auth
✅ **API Versioning** - Path-based, header-based, canary releases
✅ **Developer Portal** - Self-service API key management
✅ **API Analytics** - Grafana dashboards, Kafka logging
✅ **Quota Management** - Tiered pricing (Free/Pro/Enterprise)
✅ **Lifecycle Management** - Deprecation policies, canary releases
✅ **Testing & Mocking** - Automated tests, mock servers
✅ **Multi-tenancy** - Tenant-based routing and quotas

### Deployment

```bash
# Deploy all enterprise features
./scripts/deploy-enterprise-api-management.sh

# Verify deployment
./scripts/verify-enterprise-api-management.sh

# Run API tests
./scripts/test-api-endpoints.sh
```

### Access Points

| Service | Command | URL |
|---------|---------|-----|
| Swagger UI | `kubectl port-forward -n apisix svc/apisix-gateway 9080:9080` | http://localhost:9080/api-docs/ |
| Developer Portal | `kubectl port-forward -n apisix svc/developer-portal 4010:4010` | http://localhost:4010 |
| API Mock | `kubectl port-forward -n apisix svc/api-mock-server 4010:4010` | http://localhost:4010 |
| Analytics | `kubectl port-forward -n istio-system svc/grafana 3000:3000` | http://localhost:3000 |

---

**Next:** Integrate with CI/CD pipelines, add monitoring alerts, implement SLA tracking.# Enterprise API Management Enhancement Guide

## Overview

This guide extends your existing **APISIX + Istio** integration to provide comprehensive **enterprise-grade API management** capabilities beyond basic routing and authentication.

**Current State:**
- ✅ Basic rate limiting
- ✅ Key-based authentication  
- ✅ Response caching
- ✅ Prometheus metrics

**What This Guide Adds:**
- 🚀 Developer Portal
- 📚 OpenAPI/Swagger Documentation
- 🔐 Advanced Authentication (OAuth2, JWT, OIDC)
- 📊 API Analytics & Monitoring
- 🎯 API Versioning Strategy
- 💰 Quota Management & Monetization
- 🧪 API Mocking & Testing
- 🔔 Webhook Support
- 🌐 Multi-tenancy

---

## Table of Contents

1. [API Documentation & Discovery](#1-api-documentation--discovery)
2. [Advanced Authentication](#2-advanced-authentication)
3. [API Versioning](#3-api-versioning)
4. [Developer Portal](#4-developer-portal)
5. [API Analytics](#5-api-analytics)
6. [Quota Management](#6-quota-management)
7. [API Lifecycle Management](#7-api-lifecycle-management)
8. [Testing & Mocking](#8-testing--mocking)
9. [Multi-tenancy](#9-multi-tenancy)
10. [Complete Example](#10-complete-example)

---

## 1. API Documentation & Discovery

### 1.1 OpenAPI Specification Integration

Create OpenAPI specs for your Bookinfo APIs:

```yaml
# filepath: manifests/openapi-bookinfo.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bookinfo-openapi-spec
  namespace: apisix
data:
  openapi.yaml: |
    openapi: 3.0.0
    info:
      title: Bookinfo API
      version: 1.0.0
      description: Book catalog and review management API
      contact:
        name: API Support
        email: api@bookinfo.com
    servers:
      - url: http://localhost:9080
        description: Development server
      - url: https://api.bookinfo.com
        description: Production server
    
    paths:
      /api/v1/products:
        get:
          summary: List all products
          operationId: listProducts
          tags:
            - Products
          security:
            - ApiKeyAuth: []
          responses:
            '200':
              description: Successful response
              content:
                application/json:
                  schema:
                    type: array
                    items:
                      $ref: '#/components/schemas/Product'
            '401':
              description: Unauthorized
            '429':
              description: Rate limit exceeded
      
      /api/v1/products/{id}:
        get:
          summary: Get product by ID
          operationId: getProduct
          tags:
            - Products
          security:
            - ApiKeyAuth: []
          parameters:
            - name: id
              in: path
              required: true
              schema:
                type: integer
          responses:
            '200':
              description: Product details
              content:
                application/json:
                  schema:
                    $ref: '#/components/schemas/Product'
            '404':
              description: Product not found
      
      /api/v1/products/{id}/reviews:
        get:
          summary: Get product reviews
          operationId: getProductReviews
          tags:
            - Reviews
          parameters:
            - name: id
              in: path
              required: true
              schema:
                type: integer
          responses:
            '200':
              description: Product reviews
              content:
                application/json:
                  schema:
                    type: array
                    items:
                      $ref: '#/components/schemas/Review'
    
    components:
      securitySchemes:
        ApiKeyAuth:
          type: apiKey
          in: header
          name: apikey
          description: API key for authentication
        OAuth2:
          type: oauth2
          flows:
            clientCredentials:
              tokenUrl: /oauth/token
              scopes:
                read:products: Read product information
                write:products: Modify products
                read:reviews: Read reviews
                write:reviews: Write reviews
        BearerAuth:
          type: http
          scheme: bearer
          bearerFormat: JWT
      
      schemas:
        Product:
          type: object
          properties:
            id:
              type: integer
              example: 1
            title:
              type: string
              example: "The Comedy of Errors"
            descriptionHtml:
              type: string
            isbn:
              type: string
              example: "1234567890"
            author:
              type: string
              example: "William Shakespeare"
            year:
              type: integer
              example: 1595
            type:
              type: string
              enum: [paperback, hardcover]
            pages:
              type: integer
            publisher:
              type: string
            language:
              type: string
            rating:
              type: number
              format: float
              minimum: 0
              maximum: 5
        
        Review:
          type: object
          properties:
            id:
              type: integer
            reviewer:
              type: string
            rating:
              type: integer
              minimum: 1
              maximum: 5
            text:
              type: string
            createdAt:
              type: string
              format: date-time
```

### 1.2 Deploy Swagger UI

```yaml
# filepath: manifests/swagger-ui.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: swagger-ui-config
  namespace: apisix
data:
  swagger-config.json: |
    {
      "urls": [
        {
          "url": "/openapi/bookinfo.yaml",
          "name": "Bookinfo API v1"
        }
      ],
      "deepLinking": true,
      "displayOperationId": true,
      "defaultModelsExpandDepth": 3,
      "defaultModelExpandDepth": 3,
      "displayRequestDuration": true,
      "filter": true,
      "showExtensions": true,
      "showCommonExtensions": true,
      "tryItOutEnabled": true
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: swagger-ui
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: swagger-ui
  template:
    metadata:
      labels:
        app: swagger-ui
    spec:
      containers:
      - name: swagger-ui
        image: swaggerapi/swagger-ui:v5.10.0
        ports:
        - containerPort: 8080
        env:
        - name: SWAGGER_JSON_URL
          value: /openapi/bookinfo.yaml
        - name: BASE_URL
          value: /api-docs
        volumeMounts:
        - name: openapi-spec
          mountPath: /usr/share/nginx/html/openapi
        - name: swagger-config
          mountPath: /usr/share/nginx/html/swagger-config.json
          subPath: swagger-config.json
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: openapi-spec
        configMap:
          name: bookinfo-openapi-spec
      - name: swagger-config
        configMap:
          name: swagger-ui-config
---
apiVersion: v1
kind: Service
metadata:
  name: swagger-ui
  namespace: apisix
spec:
  selector:
    app: swagger-ui
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP
```

### 1.3 Configure APISIX Route for API Docs

```bash
#!/bin/bash
# filepath: scripts/configure-api-docs.sh

kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 &
PF_PID=$!
sleep 3

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Route for Swagger UI
curl -i -X PUT "$ADMIN_API/routes/10" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api-docs/*",
    "name": "swagger-ui",
    "methods": ["GET"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "swagger-ui.apisix.svc.cluster.local:8080": 1
      }
    },
    "plugins": {
      "proxy-rewrite": {
        "regex_uri": ["^/api-docs/(.*)", "/$1"]
      },
      "cors": {
        "allow_origins": "*",
        "allow_methods": "GET,POST,PUT,DELETE,OPTIONS",
        "allow_headers": "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization",
        "expose_headers": "Content-Length,Content-Range",
        "max_age": 3600
      }
    }
  }'

# Route for OpenAPI spec
curl -i -X PUT "$ADMIN_API/routes/11" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/openapi/*",
    "name": "openapi-spec",
    "methods": ["GET"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "swagger-ui.apisix.svc.cluster.local:8080": 1
      }
    }
  }'

kill $PF_PID
echo "✅ API documentation routes configured"
echo "📚 Access Swagger UI: kubectl port-forward -n apisix svc/apisix-gateway 9080:9080"
echo "   Then open: http://localhost:9080/api-docs/"
```

---

## 2. Advanced Authentication

### 2.1 JWT Authentication

```bash
# Create JWT signing key
kubectl create secret generic jwt-secret \
  -n apisix \
  --from-literal=secret-key="your-256-bit-secret-key-here"
```

```bash
#!/bin/bash
# filepath: scripts/configure-jwt-auth.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Create JWT consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "jwt_user",
    "plugins": {
      "jwt-auth": {
        "key": "jwt-key-001",
        "secret": "your-256-bit-secret-key-here",
        "algorithm": "HS256",
        "exp": 86400
      }
    }
  }'

# Update API route with JWT auth
curl -i -X PATCH "$ADMIN_API/routes/3" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "jwt-auth": {
        "header": "Authorization",
        "query": "jwt"
      },
      "limit-count": {
        "count": 1000,
        "time_window": 60,
        "rejected_code": 429,
        "key_type": "consumer"
      }
    }
  }'

echo "✅ JWT authentication configured"
```

### 2.2 OAuth2 Integration

```yaml
# filepath: manifests/oauth2-provider.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-config
  namespace: apisix
data:
  oauth2.yaml: |
    providers:
      - name: keycloak
        issuer: https://keycloak.example.com/realms/bookinfo
        authorization_endpoint: /protocol/openid-connect/auth
        token_endpoint: /protocol/openid-connect/token
        userinfo_endpoint: /protocol/openid-connect/userinfo
        jwks_uri: /protocol/openid-connect/certs
        client_id: bookinfo-api
        client_secret: ${OAUTH2_CLIENT_SECRET}
        scopes:
          - openid
          - profile
          - email
          - read:products
          - write:products
```

```bash
#!/bin/bash
# filepath: scripts/configure-oauth2.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Configure OAuth2 plugin
curl -i -X PUT "$ADMIN_API/routes/12" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v2/*",
    "name": "api-v2-oauth",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "openid-connect": {
        "client_id": "bookinfo-api",
        "client_secret": "your-client-secret",
        "discovery": "https://keycloak.example.com/realms/bookinfo/.well-known/openid-configuration",
        "scope": "openid profile email",
        "bearer_only": true,
        "realm": "bookinfo",
        "introspection_endpoint_auth_method": "client_secret_post"
      }
    }
  }'
```

### 2.3 Multi-Auth Strategy

```bash
#!/bin/bash
# filepath: scripts/configure-multi-auth.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Route supporting multiple auth methods
curl -i -X PUT "$ADMIN_API/routes/13" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/products/*",
    "name": "api-multi-auth",
    "methods": ["GET", "POST", "PUT", "DELETE"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "consumer-restriction": {
        "type": "consumer_name"
      },
      "key-auth": {},
      "jwt-auth": {},
      "hmac-auth": {}
    }
  }'

echo "✅ Multi-authentication strategy configured"
echo "Supports: API Key, JWT, HMAC"
```

---

## 3. API Versioning

### 3.1 URL Path Versioning

```bash
#!/bin/bash
# filepath: scripts/configure-api-versioning.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# API v1 - Stable (current production)
curl -i -X PUT "$ADMIN_API/routes/20" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/*",
    "name": "api-v1-stable",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 100,
        "time_window": 60,
        "rejected_code": 429
      },
      "response-rewrite": {
        "headers": {
          "X-API-Version": "v1",
          "X-API-Status": "stable"
        }
      }
    }
  }'

# API v2 - Beta (new features)
curl -i -X PUT "$ADMIN_API/routes/21" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v2/*",
    "name": "api-v2-beta",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage-v2.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 50,
        "time_window": 60,
        "rejected_code": 429
      },
      "response-rewrite": {
        "headers": {
          "X-API-Version": "v2",
          "X-API-Status": "beta",
          "X-API-Deprecation": "This version is in beta. Production use at your own risk."
        }
      }
    }
  }'

# API v0 (legacy) - Deprecated
curl -i -X PUT "$ADMIN_API/routes/22" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v0/*",
    "name": "api-v0-deprecated",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage-legacy.bookinfo.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 10,
        "time_window": 60,
        "rejected_code": 429
      },
      "response-rewrite": {
        "headers": {
          "X-API-Version": "v0",
          "X-API-Status": "deprecated",
          "X-API-Deprecation": "This API version is deprecated. Please migrate to v1. Sunset date: 2025-12-31",
          "Sunset": "Sat, 31 Dec 2025 23:59:59 GMT"
        }
      }
    }
  }'

echo "✅ API versioning configured"
echo "  - /api/v0/* - Deprecated (10 req/min)"
echo "  - /api/v1/* - Stable (100 req/min)"
echo "  - /api/v2/* - Beta (50 req/min)"
```

### 3.2 Header-Based Versioning

```bash
# Alternative: Accept header versioning
curl -i -X PUT "$ADMIN_API/routes/23" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/products/*",
    "name": "api-header-versioning",
    "vars": [
      ["http_accept", "~~", "application/vnd.bookinfo.v2+json"]
    ],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage-v2.bookinfo.svc.cluster.local:9080": 1
      }
    }
  }'
```

---

## 4. Developer Portal

### 4.1 Deploy Developer Portal

```yaml
# filepath: manifests/developer-portal.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: portal-config
  namespace: apisix
data:
  config.json: |
    {
      "title": "Bookinfo API Developer Portal",
      "description": "Access Bookinfo APIs with comprehensive documentation",
      "apis": [
        {
          "name": "Products API",
          "version": "v1",
          "description": "Manage book catalog",
          "spec": "/openapi/bookinfo.yaml",
          "baseUrl": "http://localhost:9080/api/v1"
        }
      ],
      "authentication": {
        "methods": ["apiKey", "jwt", "oauth2"],
        "signupEnabled": true
      },
      "features": {
        "apiExplorer": true,
        "interactiveDocs": true,
        "codeGeneration": true,
        "analytics": true
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: developer-portal
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: developer-portal
  template:
    metadata:
      labels:
        app: developer-portal
    spec:
      containers:
      - name: portal
        image: stoplight/prism:latest
        ports:
        - containerPort: 4010
        env:
        - name: PORT
          value: "4010"
        volumeMounts:
        - name: openapi-spec
          mountPath: /specs
        - name: portal-config
          mountPath: /config
        command:
        - prism
        - mock
        - -h
        - "0.0.0.0"
        - /specs/openapi.yaml
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: openapi-spec
        configMap:
          name: bookinfo-openapi-spec
      - name: portal-config
        configMap:
          name: portal-config
---
apiVersion: v1
kind: Service
metadata:
  name: developer-portal
  namespace: apisix
spec:
  selector:
    app: developer-portal
  ports:
  - name: http
    port: 4010
    targetPort: 4010
  type: ClusterIP
```

### 4.2 Self-Service API Key Management

```yaml
# filepath: manifests/api-key-service.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-key-manager-config
  namespace: apisix
data:
  config.yaml: |
    server:
      port: 8080
    database:
      type: postgres
      host: postgres.apisix.svc.cluster.local
      port: 5432
      name: apikeys
    apisix:
      adminUrl: http://apisix-admin.apisix.svc.cluster.local:9180
      adminKey: edd1c9f034335f136f87ad84b625c8f1
    features:
      selfServiceSignup: true
      emailVerification: true
      quotaManagement: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-key-manager
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-key-manager
  template:
    metadata:
      labels:
        app: api-key-manager
    spec:
      containers:
      - name: manager
        image: your-registry/api-key-manager:1.0
        ports:
        - containerPort: 8080
        env:
        - name: APISIX_ADMIN_URL
          value: "http://apisix-gateway.apisix.svc.cluster.local:9180"
        - name: APISIX_ADMIN_KEY
          valueFrom:
            secretKeyRef:
              name: apisix-admin-key
              key: api-key
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: api-key-manager-config
```

---

## 5. API Analytics

### 5.1 Enhanced Logging Plugin

```bash
#!/bin/bash
# filepath: scripts/configure-analytics.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Configure logging to Kafka for analytics
curl -i -X PUT "$ADMIN_API/plugin_metadata/kafka-logger" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "broker_list": {
      "kafka.apisix.svc.cluster.local:9092": {}
    },
    "kafka_topic": "apisix-logs",
    "producer_type": "async",
    "required_acks": 1,
    "timeout": 3,
    "batch_max_size": 1000,
    "max_retry_count": 2,
    "retry_interval": 1
  }'

# Apply to all API routes
curl -i -X PUT "$ADMIN_API/global_rules/2" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "kafka-logger": {
        "meta_format": "origin",
        "include_req_body": false,
        "include_resp_body": false
      },
      "http-logger": {
        "uri": "http://log-collector.apisix.svc.cluster.local:8080/api/logs",
        "batch_max_size": 100,
        "max_retry_count": 3,
        "retry_delay": 1,
        "buffer_duration": 5,
        "inactive_timeout": 2
      }
    }
  }'

echo "✅ Analytics logging configured"
```

### 5.2 Grafana Dashboard for API Analytics

```yaml
# filepath: manifests/grafana-api-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-api-dashboard
  namespace: istio-system
data:
  api-analytics.json: |
    {
      "dashboard": {
        "title": "API Analytics Dashboard",
        "panels": [
          {
            "title": "API Requests per Second",
            "targets": [
              {
                "expr": "rate(apisix_http_requests_total[5m])"
              }
            ]
          },
          {
            "title": "API Response Times (P95)",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(apisix_http_latency_bucket[5m]))"
              }
            ]
          },
          {
            "title": "Top API Consumers",
            "targets": [
              {
                "expr": "topk(10, sum by (consumer) (rate(apisix_http_requests_total[1h])))"
              }
            ]
          },
          {
            "title": "API Error Rate by Route",
            "targets": [
              {
                "expr": "rate(apisix_http_requests_total{status=~\"4..|5..\"}[5m])"
              }
            ]
          },
          {
            "title": "Rate Limit Violations",
            "targets": [
              {
                "expr": "increase(apisix_http_requests_total{status=\"429\"}[1h])"
              }
            ]
          }
        ]
      }
    }
```

---

## 6. Quota Management

### 6.1 Tiered Pricing Plans

```bash
#!/bin/bash
# filepath: scripts/configure-quota-tiers.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Free Tier Consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "free_tier_user",
    "desc": "Free tier - 1000 requests/day",
    "plugins": {
      "key-auth": {
        "key": "free-tier-key-001"
      },
      "limit-count": {
        "count": 1000,
        "time_window": 86400,
        "rejected_code": 429,
        "rejected_msg": "Free tier quota exceeded. Upgrade to Pro for more requests.",
        "policy": "local"
      }
    },
    "labels": {
      "tier": "free",
      "max_requests_per_day": "1000"
    }
  }'

# Pro Tier Consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "pro_tier_user",
    "desc": "Pro tier - 100,000 requests/day",
    "plugins": {
      "key-auth": {
        "key": "pro-tier-key-001"
      },
      "limit-count": {
        "count": 100000,
        "time_window": 86400,
        "rejected_code": 429,
        "policy": "redis",
        "redis_host": "redis.apisix.svc.cluster.local",
        "redis_port": 6379,
        "redis_timeout": 1001
      }
    },
    "labels": {
      "tier": "pro",
      "max_requests_per_day": "100000"
    }
  }'

# Enterprise Tier Consumer
curl -i -X PUT "$ADMIN_API/consumers" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "enterprise_tier_user",
    "desc": "Enterprise tier - Unlimited requests",
    "plugins": {
      "key-auth": {
        "key": "enterprise-tier-key-001"
      }
    },
    "labels": {
      "tier": "enterprise",
      "max_requests_per_day": "unlimited"
    }
  }'

echo "✅ Quota tiers configured"
echo "  - Free: 1,000 req/day"
echo "  - Pro: 100,000 req/day"
echo "  - Enterprise: Unlimited"
```

### 6.2 Redis for Distributed Rate Limiting

```yaml
# filepath: manifests/redis-rate-limiting.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.2-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - --appendonly
        - "yes"
        - --maxmemory
        - "512mb"
        - --maxmemory-policy
        - "allkeys-lru"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: apisix
spec:
  selector:
    app: redis
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
  type: ClusterIP
```

---

## 7. API Lifecycle Management

### 7.1 Deprecation Policy

```bash
#!/bin/bash
# filepath: scripts/deprecate-api-version.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Mark API v0 as deprecated with sunset header
curl -i -X PATCH "$ADMIN_API/routes/22" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "plugins": {
      "response-rewrite": {
        "headers": {
          "X-API-Deprecated": "true",
          "X-API-Sunset-Date": "2025-12-31",
          "X-API-Migration-Guide": "https://docs.bookinfo.com/api/v0-to-v1-migration",
          "Sunset": "Sat, 31 Dec 2025 23:59:59 GMT",
          "Link": "<https://docs.bookinfo.com/api/v1>; rel=\"successor-version\""
        }
      },
      "limit-count": {
        "count": 10,
        "time_window": 60,
        "rejected_msg": "This API version is deprecated. Please upgrade to v1."
      }
    }
  }'

echo "✅ API v0 marked as deprecated"
echo "Sunset date: 2025-12-31"
echo "Migration guide: https://docs.bookinfo.com/api/v0-to-v1-migration"
```

### 7.2 Canary Release

```bash
#!/bin/bash
# filepath: scripts/configure-canary.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Canary route - 10% traffic to v2
curl -i -X PUT "$ADMIN_API/routes/30" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/api/v1/products/*",
    "name": "canary-v2",
    "upstream": {
      "type": "roundrobin",
      "nodes": [
        {
          "host": "productpage.bookinfo.svc.cluster.local",
          "port": 9080,
          "weight": 90
        },
        {
          "host": "productpage-v2.bookinfo.svc.cluster.local",
          "port": 9080,
          "weight": 10
        }
      ]
    },
    "plugins": {
      "traffic-split": {
        "rules": [
          {
            "match": [
              {
                "vars": [
                  ["http_x_canary_user", "==", "true"]
                ]
              }
            ],
            "weighted_upstreams": [
              {
                "upstream": {
                  "name": "v2-canary",
                  "type": "roundrobin",
                  "nodes": {
                    "productpage-v2.bookinfo.svc.cluster.local:9080": 1
                  }
                },
                "weight": 1
              }
            ]
          }
        ]
      }
    }
  }'

echo "✅ Canary deployment configured"
echo "  - 90% traffic → v1"
echo "  - 10% traffic → v2"
echo "  - 100% traffic → v2 for users with header 'X-Canary-User: true'"
```

---

## 8. Testing & Mocking

### 8.1 API Mocking Server

```yaml
# filepath: manifests/api-mock-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-mock-server
  namespace: apisix
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-mock
  template:
    metadata:
      labels:
        app: api-mock
    spec:
      containers:
      - name: prism
        image: stoplight/prism:latest
        args:
        - mock
        - -h
        - "0.0.0.0"
        - -p
        - "4010"
        - /specs/openapi.yaml
        ports:
        - containerPort: 4010
        volumeMounts:
        - name: openapi-spec
          mountPath: /specs
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: openapi-spec
        configMap:
          name: bookinfo-openapi-spec
---
apiVersion: v1
kind: Service
metadata:
  name: api-mock-server
  namespace: apisix
spec:
  selector:
    app: api-mock
  ports:
  - name: http
    port: 4010
    targetPort: 4010
```

### 8.2 Automated API Testing

```bash
#!/bin/bash
# filepath: scripts/test-api-endpoints.sh

BASE_URL="http://localhost:9080"
API_KEY="apikey-12345678901234567890"

echo "🧪 Running API Tests..."

# Test 1: List products (authenticated)
echo -n "Test 1: GET /api/v1/products ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: $API_KEY" \
  "$BASE_URL/api/v1/products")
[ "$STATUS" = "200" ] && echo "✅ PASS" || echo "❌ FAIL (HTTP $STATUS)"

# Test 2: Get product by ID
echo -n "Test 2: GET /api/v1/products/1 ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: $API_KEY" \
  "$BASE_URL/api/v1/products/1")
[ "$STATUS" = "200" ] && echo "✅ PASS" || echo "❌ FAIL (HTTP $STATUS)"

# Test 3: Unauthorized access (no API key)
echo -n "Test 3: GET /api/v1/products (no auth) ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "$BASE_URL/api/v1/products")
[ "$STATUS" = "401" ] && echo "✅ PASS" || echo "❌ FAIL (HTTP $STATUS)"

# Test 4: Rate limiting
echo -n "Test 4: Rate limiting (101 requests) ... "
for i in {1..101}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: $API_KEY" \
    "$BASE_URL/productpage")
  if [ "$STATUS" = "429" ]; then
    echo "✅ PASS (rate limit triggered at request $i)"
    break
  fi
done

# Test 5: CORS headers
echo -n "Test 5: CORS headers ... "
CORS=$(curl -s -I -X OPTIONS \
  -H "Origin: http://example.com" \
  -H "Access-Control-Request-Method: GET" \
  "$BASE_URL/api/v1/products" | grep -i "access-control-allow-origin")
[ -n "$CORS" ] && echo "✅ PASS" || echo "❌ FAIL"

# Test 6: API versioning
echo -n "Test 6: API version header ... "
VERSION=$(curl -s -I -H "apikey: $API_KEY" \
  "$BASE_URL/api/v1/products" | grep -i "x-api-version")
[ -n "$VERSION" ] && echo "✅ PASS" || echo "❌ FAIL"

echo ""
echo "✅ API testing complete"
```

---

## 9. Multi-tenancy

### 9.1 Tenant-based Routing

```bash
#!/bin/bash
# filepath: scripts/configure-multitenancy.sh

ADMIN_API="http://localhost:9180/apisix/admin"
API_KEY="edd1c9f034335f136f87ad84b625c8f1"

# Tenant A - dedicated namespace
curl -i -X PUT "$ADMIN_API/routes/40" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/tenant-a/*",
    "name": "tenant-a-api",
    "vars": [
      ["http_x_tenant_id", "==", "tenant-a"]
    ],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.tenant-a.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 10000,
        "time_window": 3600,
        "key": "x-tenant-id",
        "key_type": "var",
        "rejected_code": 429
      }
    }
  }'

# Tenant B - dedicated namespace
curl -i -X PUT "$ADMIN_API/routes/41" \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/tenant-b/*",
    "name": "tenant-b-api",
    "vars": [
      ["http_x_tenant_id", "==", "tenant-b"]
    ],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "productpage.tenant-b.svc.cluster.local:9080": 1
      }
    },
    "plugins": {
      "limit-count": {
        "count": 5000,
        "time_window": 3600,
        "key": "x-tenant-id",
        "key_type": "var",
        "rejected_code": 429
      }
    }
  }'

echo "✅ Multi-tenancy configured"
echo "  - Tenant A: 10,000 req/hour"
echo "  - Tenant B: 5,000 req/hour"
```

---

## 10. Complete Example

### 10.1 Comprehensive Deployment Script

```bash
#!/bin/bash
# filepath: scripts/deploy-enterprise-api-management.sh

set -e

echo "========================================"
echo "Enterprise API Management Deployment"
echo "========================================"
echo ""

# Step 1: Deploy OpenAPI documentation
echo "📚 Step 1: Deploying API documentation..."
kubectl apply -f manifests/openapi-bookinfo.yaml
kubectl apply -f manifests/swagger-ui.yaml
kubectl wait --for=condition=ready pod -l app=swagger-ui -n apisix --timeout=120s
echo "✅ API documentation deployed"
echo ""

# Step 2: Configure advanced authentication
echo "🔐 Step 2: Configuring advanced authentication..."
./scripts/configure-jwt-auth.sh
./scripts/configure-multi-auth.sh
echo "✅ Advanced authentication configured"
echo ""

# Step 3: Set up API versioning
echo "🔢 Step 3: Setting up API versioning..."
./scripts/configure-api-versioning.sh
echo "✅ API versioning configured"
echo ""

# Step 4: Deploy developer portal
echo "👨‍💻 Step 4: Deploying developer portal..."
kubectl apply -f manifests/developer-portal.yaml
kubectl wait --for=condition=ready pod -l app=developer-portal -n apisix --timeout=120s
echo "✅ Developer portal deployed"
echo ""

# Step 5: Configure analytics
echo "📊 Step 5: Configuring analytics..."
kubectl apply -f manifests/grafana-api-dashboard.yaml
./scripts/configure-analytics.sh
echo "✅ Analytics configured"
echo ""

# Step 6: Set up quota management
echo "💰 Step 6: Setting up quota management..."
kubectl apply -f manifests/redis-rate-limiting.yaml
kubectl wait --for=condition=ready pod -l app=redis -n apisix --timeout=120s
./scripts/configure-quota-tiers.sh
echo "✅ Quota management configured"
echo ""

# Step 7: Deploy API mocking
echo "🧪 Step 7: Deploying API mocking server..."
kubectl apply -f manifests/api-mock-server.yaml
kubectl wait --for=condition=ready pod -l app=api-mock -n apisix --timeout=120s
echo "✅ API mocking deployed"
echo ""

# Step 8: Run tests
echo "🧪 Step 8: Running API tests..."
./scripts/test-api-endpoints.sh
echo ""

echo "========================================"
echo "✅ Enterprise API Management Deployed!"
echo "========================================"
echo ""
echo "📍 Access Points:"
echo "  • API Gateway:        kubectl port-forward -n apisix svc/apisix-gateway 9080:9080"
echo "  • API Documentation:  http://localhost:9080/api-docs/"
echo "  • Developer Portal:   kubectl port-forward -n apisix svc/developer-portal 4010:4010"
echo "  • API Mock Server:    kubectl port-forward -n apisix svc/api-mock-server 4010:4010"
echo "  • APISIX Dashboard:   kubectl port-forward -n apisix svc/apisix-dashboard 9000:9000"
echo "  • Grafana (Analytics): kubectl port-forward -n istio-system svc/grafana 3000:3000"
echo ""
echo "🔑 API Tiers:"
echo "  • Free:       1,000 requests/day"
echo "  • Pro:        100,000 requests/day"
echo "  • Enterprise: Unlimited"
echo ""
echo "📚 Next Steps:"
echo "  1. Access Swagger UI: http://localhost:9080/api-docs/"
echo "  2. Generate API key: kubectl port-forward -n apisix svc/api-key-manager 8080:8080"
echo "  3. View analytics: http://localhost:3000 (Grafana)"
echo "  4. Test endpoints: ./scripts/test-api-endpoints.sh"
echo ""
```

### 10.2 Verification Script

```bash
#!/bin/bash
# filepath: scripts/verify-enterprise-api-management.sh

echo "🔍 Verifying Enterprise API Management..."
echo ""

CHECKS=0
PASSED=0

# Check 1: Swagger UI
echo -n "✓ Checking Swagger UI ... "
if kubectl get pod -l app=swagger-ui -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 2: Developer Portal
echo -n "✓ Checking Developer Portal ... "
if kubectl get pod -l app=developer-portal -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 3: Redis (for rate limiting)
echo -n "✓ Checking Redis ... "
if kubectl get pod -l app=redis -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 4: API Mock Server
echo -n "✓ Checking API Mock Server ... "
if kubectl get pod -l app=api-mock -n apisix | grep -q "Running"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
((CHECKS++))

# Check 5: JWT consumers
echo -n "✓ Checking JWT consumers ... "
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://localhost:9180/apisix/admin/consumers | grep -q "jwt_user"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
kill $PF_PID 2>/dev/null
((CHECKS++))

# Check 6: API versioning routes
echo -n "✓ Checking API versioning routes ... "
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://localhost:9180/apisix/admin/routes | grep -q "api-v1-stable"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
kill $PF_PID 2>/dev/null
((CHECKS++))

# Check 7: Quota tiers
echo -n "✓ Checking quota tier consumers ... "
kubectl port-forward -n apisix svc/apisix-gateway 9180:9180 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://localhost:9180/apisix/admin/consumers | grep -q "free_tier_user"; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
fi
kill $PF_PID 2>/dev/null
((CHECKS++))

echo ""
echo "========================================"
echo "Verification Results: $PASSED/$CHECKS checks passed"
echo "========================================"

if [ $PASSED -eq $CHECKS ]; then
  echo "✅ All enterprise API management features verified!"
  exit 0
else
  echo "⚠️  Some checks failed. Please review the output above."
  exit 1
fi
```

---

## Summary

This enhancement guide provides:

✅ **API Documentation** - OpenAPI specs + Swagger UI
✅ **Advanced Authentication** - JWT, OAuth2, Multi-auth
✅ **API Versioning** - Path-based, header-based, canary releases
✅ **Developer Portal** - Self-service API key management
✅ **API Analytics** - Grafana dashboards, Kafka logging
✅ **Quota Management** - Tiered pricing (Free/Pro/Enterprise)
✅ **Lifecycle Management** - Deprecation policies, canary releases
✅ **Testing & Mocking** - Automated tests, mock servers
✅ **Multi-tenancy** - Tenant-based routing and quotas

### Deployment

```bash
# Deploy all enterprise features
./scripts/deploy-enterprise-api-management.sh

# Verify deployment
./scripts/verify-enterprise-api-management.sh

# Run API tests
./scripts/test-api-endpoints.sh
```

### Access Points

| Service | Command | URL |
|---------|---------|-----|
| Swagger UI | `kubectl port-forward -n apisix svc/apisix-gateway 9080:9080` | http://localhost:9080/api-docs/ |
| Developer Portal | `kubectl port-forward -n apisix svc/developer-portal 4010:4010` | http://localhost:4010 |
| API Mock | `kubectl port-forward -n apisix svc/api-mock-server 4010:4010` | http://localhost:4010 |
| Analytics | `kubectl port-forward -n istio-system svc/grafana 3000:3000` | http://localhost:3000 |

---

**Next:** Integrate with CI/CD pipelines, add monitoring alerts, implement SLA tracking.