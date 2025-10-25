# Fresh Installation Validation Guide

This document provides a comprehensive checklist to validate that all fixes have been properly applied and a fresh installation will work correctly.

## Pre-Installation Requirements

### System Requirements
- [ ] Operating System: Linux, macOS, or Windows with WSL2
- [ ] CPU: Minimum 8 cores available
- [ ] RAM: Minimum 14GB available
- [ ] Disk: Minimum 50GB free space

### Software Requirements
- [ ] Docker installed and running
- [ ] kubectl installed (v1.28.0 or compatible)
- [ ] Minikube installed (latest stable)
- [ ] curl installed (for testing)

## Automated Fresh Installation Test

### Step 1: Clean Environment
```bash
# Delete any existing Minikube cluster
minikube delete -p istio-ambient

# Verify cleanup
minikube status -p istio-ambient
# Expected: "Profile 'istio-ambient' not found"
```

### Step 2: Navigate to Project Directory
```bash
cd /path/to/Practical-Istio/chapter-ambient-observability
```

### Step 3: Run Quick Start Script
```bash
./scripts/quick-start.sh
```

**Expected Output**: Script should complete without errors and show:
- ✓ Minikube started successfully
- ✓ Istio downloaded
- ✓ Namespaces created
- ✓ Istio installed with ingress gateway
- ✓ Ambient mode enabled
- ✓ Prometheus installed
- ✓ Grafana installed
- ✓ Jaeger installed
- ✓ Kiali installed
- ✓ Configurations applied
- ✓ Bookinfo application deployed
- ✓ Istiod is running
- ✓ Ztunnel DaemonSet is running (N pods)
- ✓ Ingress gateway is running

### Step 4: Run Verification Script
```bash
./scripts/verify-installation.sh
```

**Expected Output**:
```
✓ All checks passed! Installation is successful.

Total checks: 23
Passed: 23
Failed: 0
Success rate: 100.00%
```

### Step 5: Test External Connectivity
```bash
MINIKUBE_IP=$(minikube ip -p istio-ambient)
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
curl -I http://${MINIKUBE_IP}:${GATEWAY_PORT}/productpage
```

**Expected Output**:
```
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
...
```

### Step 6: Generate Traffic
```bash
./scripts/generate-traffic.sh 20 1
```

**Expected Output**:
```
Traffic generation complete!
Total requests: 20
Successful: 20
Failed: 0
Success rate: 100.00%
```

### Step 7: Verify Dashboard Access

Open dashboards in separate terminal windows:

```bash
# Terminal 1: Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000

# Terminal 2: Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001

# Terminal 3: Jaeger (CRITICAL FIX: Note the port mapping)
kubectl port-forward -n istio-system svc/tracing 16686:80

# Terminal 4: Prometheus
kubectl port-forward -n istio-system svc/prometheus 9090:9090
```

**Access in Browser**:
- [ ] Grafana: http://localhost:3000 (should load dashboard)
- [ ] Kiali: http://localhost:20001 (should show service graph)
- [ ] Jaeger: http://localhost:16686 (should show traces) ⚠️ **Critical fix: 16686:80 mapping**
- [ ] Prometheus: http://localhost:9090 (should show metrics)

**Alternative**: Use the automated script:
```bash
./scripts/open-dashboards.sh
```

## Critical Fixes Validation Checklist

Verify each fix has been properly applied:

### ✅ Fix 1: Observability Namespace
```bash
# Verify all observability pods are in istio-system
kubectl get pods -n istio-system | grep -E "prometheus|grafana|jaeger|kiali"
```
**Expected**: All 4 services running in istio-system (not in observability namespace)

### ✅ Fix 2: Ingress Gateway Installation
```bash
# Verify ingress gateway is installed and running
kubectl get deploy istio-ingressgateway -n istio-system
```
**Expected**: `istio-ingressgateway   1/1     1            1`

### ✅ Fix 3: DestinationRule TLS Configuration
```bash
# Check that DestinationRules don't have ISTIO_MUTUAL
grep -A 10 "kind: DestinationRule" manifests/bookinfo-gateway.yaml | grep -i "istio_mutual"
```
**Expected**: No output (ISTIO_MUTUAL should not be present)

### ✅ Fix 4: Directory Navigation
```bash
# Verify manifests directory exists and contains files
ls manifests/
```
**Expected**: List of YAML files including bookinfo-gateway.yaml, telemetry-config.yaml, etc.

### ✅ Fix 5: Verification Script Pod Checks
```bash
# Run verification and check deployment-based validation
./scripts/verify-installation.sh | grep "deployment"
```
**Expected**: Should show checks for deployments (not pod label queries)

### ✅ Fix 6: Dynamic NodePort Discovery
```bash
# Verify scripts use dynamic port discovery
grep "jsonpath='{.spec.ports" scripts/generate-traffic.sh
grep "jsonpath='{.spec.ports" scripts/verify-installation.sh
```
**Expected**: Both scripts should contain jsonpath queries for dynamic port discovery

### ✅ Fix 7: Ingress Gateway Verification
```bash
# Check verification script includes ingress gateway check
grep -A 5 "Ingress Gateway" scripts/verify-installation.sh
```
**Expected**: Should find ingress gateway availability check

### ✅ Fix 8: Jaeger Port-Forward Mapping
```bash
# Verify correct Jaeger port mapping in scripts
grep "tracing.*16686" scripts/open-dashboards.sh
grep "tracing.*16686" scripts/quick-start.sh
grep "tracing.*16686" QUICK_REFERENCE.md
```
**Expected**: All occurrences should be `16686:80` (NOT `16686:16686`)

**Manual Verification**:
```bash
# Check actual Jaeger service port configuration
kubectl get svc tracing -n istio-system -o yaml | grep -A 5 "ports:"
```
**Expected Output**:
```yaml
ports:
- name: http-query
  port: 80          # ← Service port
  protocol: TCP
  targetPort: 16686  # ← Container port
```

## Ambient Mode Validation

### Verify No Sidecar Proxies
```bash
# Check that pods only have one container (no istio-proxy sidecar)
kubectl get pods -n bookinfo -o jsonpath='{range .items[*]}{.metadata.name}{" containers: "}{.spec.containers[*].name}{"\n"}{end}'
```
**Expected**: Each pod should show only its application container (e.g., `productpage-v1-xxx containers: productpage`)

### Verify Ztunnel is Running
```bash
# Check ztunnel DaemonSet
kubectl get ds ztunnel -n istio-system
```
**Expected**: `DESIRED = READY` (one pod per node)

### Verify Ambient Label
```bash
# Check namespace label
kubectl get namespace bookinfo --show-labels | grep "istio.io/dataplane-mode=ambient"
```
**Expected**: Label should be present

### Verify mTLS Status
```bash
# Check PeerAuthentication
kubectl get peerauthentication -n istio-system
```
**Expected**: Should show `default-mtls` with STRICT mode

## Performance Validation

### Generate Load and Monitor
```bash
# Generate sustained traffic
./scripts/generate-traffic.sh 100 2 &

# Monitor in Kiali (open http://localhost:20001)
# Should see:
# - Service graph with all bookinfo services
# - Traffic flowing between services
# - Green health indicators

# Monitor in Grafana (open http://localhost:3000)
# Should see:
# - Istio Control Plane Dashboard showing istiod metrics
# - Istio Service Dashboard showing traffic metrics
# - No error spikes

# Monitor in Jaeger (open http://localhost:16686)
# Should see:
# - Traces for productpage service
# - Distributed traces showing calls to details, reviews, ratings
# - Latency information

# Monitor in Prometheus (open http://localhost:9090)
# Query: istio_requests_total
# Should see metrics being collected
```

## Troubleshooting Common Issues

### Issue: Script Fails at Addon Installation
**Symptom**: `kubectl apply -f` fails for observability addons

**Solution**: The script includes retry logic. If it still fails:
```bash
# Apply manually with retry
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
sleep 5
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
```

### Issue: Ingress Gateway Not Running
**Symptom**: No ingress gateway pod found

**Solution**: Verify installation command includes ingress gateway flags:
```bash
istioctl install --set profile=ambient \
    --set components.ingressGateways[0].name=istio-ingressgateway \
    --set components.ingressGateways[0].enabled=true \
    --skip-confirmation
```

### Issue: Jaeger Dashboard Shows 404
**Symptom**: http://localhost:16686 shows "page not found"

**Solution**: Verify correct port-forward mapping:
```bash
# Stop any existing port-forward
pkill -f "port-forward.*tracing"

# Start with correct mapping
kubectl port-forward -n istio-system svc/tracing 16686:80
```

### Issue: Application Returns 503
**Symptom**: `curl http://<MINIKUBE_IP>:<PORT>/productpage` returns 503

**Possible Causes**:
1. DestinationRules have ISTIO_MUTUAL (should be removed)
2. Pods not ready (wait for all pods to be Running)
3. Ingress gateway not configured correctly

**Solution**:
```bash
# Check pod status
kubectl get pods -n bookinfo

# Check ingress gateway logs
kubectl logs -n istio-system -l app=istio-ingressgateway --tail=50

# Verify DestinationRules don't have TLS config
kubectl get destinationrules -n bookinfo -o yaml | grep -i "istio_mutual"
# Should return nothing
```

## Success Criteria

A successful fresh installation should meet ALL of the following:

### Infrastructure
- [ ] Minikube cluster running with 8 CPUs and 14GB RAM
- [ ] Kubernetes version 1.28.0
- [ ] All required namespaces created (istio-system, istio-ingress, bookinfo)

### Istio Components
- [ ] istiod deployment running (1/1 ready)
- [ ] ztunnel DaemonSet running (1 pod per node, all ready)
- [ ] istio-cni DaemonSet running (1 pod per node, all ready)
- [ ] istio-ingressgateway deployment running (1/1 ready)

### Observability Stack
- [ ] Prometheus deployment running in istio-system
- [ ] Grafana deployment running in istio-system
- [ ] Jaeger deployment running in istio-system
- [ ] Kiali deployment running in istio-system

### Application
- [ ] All 7 bookinfo deployments ready (productpage-v1, details-v1, ratings-v1, reviews-v1/v2/v3, sleep)
- [ ] No sidecar containers (ambient mode confirmed)
- [ ] Namespace labeled with istio.io/dataplane-mode=ambient

### Connectivity
- [ ] External access working (curl returns HTTP 200)
- [ ] Internal service communication working (sleep → productpage returns 200)
- [ ] Traffic generation successful (100% success rate)

### Observability
- [ ] Grafana accessible and showing Istio dashboards
- [ ] Kiali accessible and showing service graph
- [ ] Jaeger accessible at localhost:16686 and showing traces
- [ ] Prometheus accessible and scraping metrics

### Verification
- [ ] 23/23 verification checks passing
- [ ] No errors in istiod logs
- [ ] No errors in ztunnel logs
- [ ] No TLS handshake errors in ingress gateway logs

## Final Validation Command

Run this comprehensive test:

```bash
#!/bin/bash
echo "=== COMPREHENSIVE VALIDATION ==="
echo ""

# 1. Verification Script
echo "1. Running verification script..."
./scripts/verify-installation.sh
echo ""

# 2. External Access
echo "2. Testing external access..."
MINIKUBE_IP=$(minikube ip -p istio-ambient)
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${MINIKUBE_IP}:${GATEWAY_PORT}/productpage)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ External access working (HTTP $HTTP_CODE)"
else
    echo "✗ External access failed (HTTP $HTTP_CODE)"
fi
echo ""

# 3. Internal Communication
echo "3. Testing internal communication..."
INTERNAL_CODE=$(kubectl exec -n bookinfo deploy/sleep -- curl -s -o /dev/null -w "%{http_code}" http://productpage:9080/productpage)
if [ "$INTERNAL_CODE" = "200" ]; then
    echo "✓ Internal communication working (HTTP $INTERNAL_CODE)"
else
    echo "✗ Internal communication failed (HTTP $INTERNAL_CODE)"
fi
echo ""

# 4. Ambient Mode
echo "4. Verifying ambient mode..."
SIDECAR_COUNT=$(kubectl get pods -n bookinfo -o json | jq '[.items[].spec.containers[] | select(.name=="istio-proxy")] | length')
if [ "$SIDECAR_COUNT" = "0" ]; then
    echo "✓ No sidecars detected (ambient mode confirmed)"
else
    echo "✗ Sidecars detected ($SIDECAR_COUNT) - not in ambient mode"
fi
echo ""

# 5. Jaeger Service
echo "5. Verifying Jaeger service configuration..."
JAEGER_PORT=$(kubectl get svc tracing -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http-query")].port}')
JAEGER_TARGET=$(kubectl get svc tracing -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http-query")].targetPort}')
if [ "$JAEGER_PORT" = "80" ] && [ "$JAEGER_TARGET" = "16686" ]; then
    echo "✓ Jaeger service correctly configured (port:$JAEGER_PORT → targetPort:$JAEGER_TARGET)"
else
    echo "✗ Jaeger service misconfigured (port:$JAEGER_PORT → targetPort:$JAEGER_TARGET)"
fi
echo ""

# 6. Traffic Generation
echo "6. Running traffic generation test..."
./scripts/generate-traffic.sh 10 1 | tail -5

echo ""
echo "=== VALIDATION COMPLETE ==="
```

Save this as `comprehensive-test.sh`, make it executable, and run:
```bash
chmod +x comprehensive-test.sh
./comprehensive-test.sh
```

## Cleanup and Retest

To cleanup and test fresh installation:

```bash
# 1. Full cleanup
./scripts/cleanup.sh

# 2. Delete Minikube cluster
minikube delete -p istio-ambient

# 3. Fresh installation
./scripts/quick-start.sh

# 4. Comprehensive validation
./scripts/verify-installation.sh
./comprehensive-test.sh
```

---

**Document Version**: 1.0  
**Last Updated**: October 25, 2025  
**Status**: All 8 fixes validated and production-ready

**Next Steps After Successful Validation**:
1. Generate sustained traffic for 5-10 minutes
2. Explore all observability dashboards
3. Review distributed traces in Jaeger
4. Examine service topology in Kiali
5. Check resource utilization in Grafana
6. Practice troubleshooting scenarios
7. Document any environment-specific notes
