# Istio Ambient Mode with Observability Stack - Implementation Guide

## Story Overview
Deploy Istio service mesh in **ambient mode** with complete observability stack on Minikube, including Prometheus, Grafana, Jaeger, and Kiali.

## Prerequisites
- Minikube installed (v1.31+)
- kubectl installed (v1.28+)
- Docker Desktop or compatible container runtime
- Minimum 16GB RAM, 8 CPU cores available for Minikube
- 50GB free disk space

---

## Phase 1: Environment Setup (Day 1 - Morning)

### Step 1.1: Configure and Start Minikube

```bash
# Start Minikube with sufficient resources for Istio ambient mode + observability
minikube start \
  --cpus=8 \
  --memory=14336 \
  --disk-size=50g \
  --driver=docker \
  --kubernetes-version=v1.28.0 \
  --profile=istio-ambient

# Enable required addons
minikube addons enable metrics-server -p istio-ambient
minikube addons enable ingress -p istio-ambient

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

**Expected Output:**
- Minikube cluster running with 8 CPUs, ~14GB RAM
- Node in Ready state
- Metrics-server and ingress-nginx running

### Step 1.2: Download and Install Istio CLI

```bash
# Download latest Istio (1.24.0 or later for ambient support)
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.0 sh -

# Add istioctl to PATH
cd istio-1.24.0
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version

# Make PATH permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH=$HOME/istio-1.24.0/bin:$PATH' >> ~/.bashrc
```

**Expected Output:**
```
no running Istio pods in "istio-system"
1.24.0
```

---

## Phase 2: Istio Ambient Mode Installation (Day 1 - Afternoon)

### Step 2.1: Install Istio with Ambient Profile

```bash
# Create namespaces
kubectl create namespace istio-system
kubectl create namespace istio-ingress
kubectl create namespace observability

# Install Istio with ambient profile
istioctl install --set profile=ambient \
  --set values.pilot.resources.requests.cpu=1000m \
  --set values.pilot.resources.requests.memory=2Gi \
  --set values.global.proxy.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.memory=128Mi \
  --skip-confirmation

# Verify Istio installation
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

# Check Istio components
istioctl verify-install
```

**Expected Components:**
- `istiod` pod in istio-system (control plane)
- `ztunnel` DaemonSet in istio-system (ambient data plane)
- `istio-cni` DaemonSet in istio-system (CNI plugin)

### Step 2.2: Configure Ambient Mode for Namespaces

```bash
# Create application namespace
kubectl create namespace bookinfo

# Label namespace for ambient mode (no sidecars!)
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient

# Verify label
kubectl get namespace bookinfo --show-labels
```

**Key Difference:** Ambient mode uses `istio.io/dataplane-mode=ambient` instead of `istio-injection=enabled`

---

## Phase 3: Observability Stack Installation (Day 1 - Evening & Day 2)

### Step 3.1: Install Prometheus

```bash
# Apply Prometheus for Istio
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml -n observability

# Wait for Prometheus to be ready
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n observability

# Verify Prometheus
kubectl get pods -n observability -l app=prometheus
```

### Step 3.2: Install Grafana with Istio Dashboards

```bash
# Apply Grafana
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml -n observability

# Wait for Grafana to be ready
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n observability

# Verify Grafana
kubectl get pods -n observability -l app=grafana
```

### Step 3.3: Install Jaeger for Distributed Tracing

```bash
# Apply Jaeger
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml -n observability

# Wait for Jaeger to be ready
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n observability

# Verify Jaeger
kubectl get pods -n observability -l app=jaeger
```

### Step 3.4: Install Kiali for Service Mesh Visualization

```bash
# Apply Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml -n observability

# Wait for Kiali to be ready
kubectl wait --for=condition=available --timeout=300s deployment/kiali -n observability

# Verify Kiali
kubectl get pods -n observability -l app=kiali
```

### Step 3.5: Verify All Observability Components

```bash
# Check all pods in observability namespace
kubectl get pods -n observability

# Check services
kubectl get svc -n observability
```

**Expected Output:** All pods Running, Services created for each component

---

## Phase 4: Configure Telemetry and mTLS (Day 2 - Morning)

### Step 4.1: Configure Telemetry Settings

Create telemetry configuration file:

```bash
# See telemetry-config.yaml in manifests directory
kubectl apply -f manifests/telemetry-config.yaml
```

### Step 4.2: Enable Strict mTLS

```bash
# See peer-authentication.yaml in manifests directory
kubectl apply -f manifests/peer-authentication.yaml

# Verify mTLS configuration
kubectl get peerauthentication --all-namespaces
```

### Step 4.3: Configure Ingress Gateway

```bash
# See gateway-config.yaml in manifests directory
kubectl apply -f manifests/gateway-config.yaml

# Verify gateway
kubectl get gateway -n istio-ingress
```

---

## Phase 5: Deploy Sample Application (Day 2 - Afternoon)

### Step 5.1: Deploy Bookinfo Application

```bash
# Deploy sample application
kubectl apply -f manifests/bookinfo-app.yaml -n bookinfo

# Wait for pods to be ready
kubectl wait --for=condition=ready --timeout=300s pod --all -n bookinfo

# Verify deployment
kubectl get pods -n bookinfo
kubectl get svc -n bookinfo
```

### Step 5.2: Configure Traffic Management

```bash
# Apply Gateway and VirtualService
kubectl apply -f manifests/bookinfo-gateway.yaml -n bookinfo

# Verify configuration
kubectl get gateway,virtualservice -n bookinfo
```

### Step 5.3: Generate Test Traffic

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip -p istio-ambient)

# Get Gateway port
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-ingress -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

# Test application
curl -I http://${MINIKUBE_IP}:${GATEWAY_PORT}/productpage

# Generate continuous traffic for observability
for i in {1..100}; do
  curl -s -o /dev/null http://${MINIKUBE_IP}:${GATEWAY_PORT}/productpage
  sleep 2
done
```

---

## Phase 6: Access Observability Dashboards (Day 2 - Evening)

### Step 6.1: Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n observability svc/grafana 3000:3000 &

# Access in browser: http://localhost:3000
# Default credentials: admin/admin
```

**Dashboards to Check:**
- Istio Mesh Dashboard
- Istio Service Dashboard
- Istio Workload Dashboard
- Istio Performance Dashboard

### Step 6.2: Access Kiali

```bash
# Port-forward Kiali
kubectl port-forward -n observability svc/kiali 20001:20001 &

# Access in browser: http://localhost:20001
# Default credentials: admin/admin
```

**What to Verify:**
- Service graph showing bookinfo services
- Ambient mode indicators (no sidecar icons)
- Traffic flow visualization
- Health status

### Step 6.3: Access Jaeger

```bash
# Port-forward Jaeger
kubectl port-forward -n observability svc/tracing 16686:16686 &

# Access in browser: http://localhost:16686
```

**What to Verify:**
- Traces from productpage service
- Distributed trace spans across services
- Latency breakdown

### Step 6.4: Access Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward -n observability svc/prometheus 9090:9090 &

# Access in browser: http://localhost:9090
```

**Sample Queries:**
```promql
# Request rate
rate(istio_requests_total[5m])

# Error rate
rate(istio_requests_total{response_code=~"5.."}[5m])

# P95 latency
histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m]))
```

---

## Phase 7: Validation and Testing (Day 3)

### Step 7.1: Verify Ambient Mode

```bash
# Check ztunnel pods (ambient data plane)
kubectl get pods -n istio-system -l app=ztunnel

# Verify no sidecars in application pods
kubectl get pods -n bookinfo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Should only see application containers, no istio-proxy
```

### Step 7.2: Verify mTLS

```bash
# Check mTLS status
istioctl experimental authz check $(kubectl get pod -n bookinfo -l app=productpage -o jsonpath='{.items[0].metadata.name}') -n bookinfo

# Verify peer authentication
kubectl get peerauthentication -A

# Use test script
kubectl apply -f manifests/mtls-test.yaml -n bookinfo
```

### Step 7.3: Test Service Communication

```bash
# Deploy sleep pod for testing
kubectl apply -f manifests/sleep-test.yaml -n bookinfo

# Test internal communication
kubectl exec -n bookinfo deploy/sleep -- curl -s http://productpage:9080/productpage | grep -o "<title>.*</title>"

# Should return: <title>Simple Bookstore App</title>
```

### Step 7.4: Verify Observability End-to-End

**Checklist:**
- [ ] Grafana showing metrics for all services
- [ ] Kiali displaying service topology with ambient mode
- [ ] Jaeger showing distributed traces
- [ ] Prometheus scraping Istio metrics
- [ ] mTLS enabled and verified
- [ ] No sidecar containers in application pods

---

## Phase 8: Advanced Configuration (Optional)

### Step 8.1: Layer 7 Authorization Policies

```bash
# Apply L7 policies (requires waypoint proxy in ambient)
kubectl apply -f manifests/waypoint-proxy.yaml -n bookinfo
kubectl apply -f manifests/authorization-policy.yaml -n bookinfo
```

### Step 8.2: Configure Certificate Management

```bash
# Install cert-manager (if needed)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configure Istio to use cert-manager
kubectl apply -f manifests/cert-manager-integration.yaml
```

### Step 8.3: Performance Tuning

```bash
# Apply resource optimizations
kubectl apply -f manifests/resource-tuning.yaml

# Configure HPA for istiod
kubectl apply -f manifests/istiod-hpa.yaml
```

---

## Troubleshooting Guide

### Issue 1: Pods Not Starting (OOMKilled)
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Solution: Increase Minikube memory
minikube delete -p istio-ambient
minikube start --cpus=8 --memory=16384 -p istio-ambient
```

### Issue 2: Ambient Mode Not Working
```bash
# Verify ztunnel is running
kubectl get ds -n istio-system ztunnel

# Check CNI installation
kubectl get pods -n istio-system -l k8s-app=istio-cni-node

# Verify namespace label
kubectl get namespace bookinfo -o yaml | grep dataplane-mode
```

### Issue 3: Observability Not Showing Data
```bash
# Verify Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check Istio telemetry config
kubectl get telemetry -A

# Restart istiod if needed
kubectl rollout restart deployment/istiod -n istio-system
```

### Issue 4: mTLS Not Enforced
```bash
# Check peer authentication
kubectl get peerauthentication -A -o yaml

# Verify destination rules
kubectl get destinationrules -A

# Test with curl from sleep pod
kubectl exec -n bookinfo deploy/sleep -- curl -v http://productpage:9080/productpage
```

---

## Validation Checklist

- [ ] Minikube cluster running with sufficient resources (8 CPU, 14GB RAM)
- [ ] Istio control plane healthy (istiod)
- [ ] Ambient data plane running (ztunnel DaemonSet)
- [ ] CNI plugin installed and running
- [ ] Prometheus collecting metrics
- [ ] Grafana dashboards accessible and showing data
- [ ] Jaeger UI accessible with traces
- [ ] Kiali showing service mesh topology
- [ ] Bookinfo application deployed in ambient mode
- [ ] No sidecar proxies in application pods
- [ ] mTLS enabled (STRICT mode)
- [ ] Test traffic generating observability data
- [ ] All services communicating successfully

---

## Resource Requirements Summary

**Minikube Configuration:**
- CPUs: 8 cores
- Memory: 14-16 GB
- Disk: 50 GB

**Actual Usage (Expected):**
- Istio control plane: ~500MB RAM, 0.5 CPU
- Ztunnel (per node): ~100MB RAM, 0.1 CPU
- Observability stack: ~2GB RAM, 1 CPU
- Sample application: ~500MB RAM, 0.5 CPU
- **Total: ~3-4GB RAM, 2-3 CPUs**

---

## Key Differences: Ambient Mode vs Sidecar Mode

| Aspect | Sidecar Mode | Ambient Mode |
|--------|--------------|--------------|
| Data Plane | Envoy sidecar per pod | Shared ztunnel per node |
| Injection | `istio-injection=enabled` | `istio.io/dataplane-mode=ambient` |
| Resource Overhead | ~120MB per pod | ~100MB per node |
| L7 Processing | Always available | Requires waypoint proxy |
| Pod Restart | Required for injection | Not required |
| Complexity | Higher | Lower |

---

## Next Steps After Implementation

1. **Day 4-5: Training**
   - Team walkthrough of Istio ambient concepts
   - Hands-on with observability dashboards
   - mTLS and security policies training

2. **Production Considerations**
   - Multi-cluster setup
   - High availability configuration
   - Backup and disaster recovery
   - Monitoring and alerting rules
   - Performance benchmarking

3. **Documentation**
   - Architecture diagrams
   - Runbooks for common operations
   - Incident response procedures
   - Cost analysis and optimization

---

## References

- [Istio Ambient Mesh Documentation](https://istio.io/latest/docs/ambient/)
- [Istio Observability](https://istio.io/latest/docs/tasks/observability/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Prometheus Queries for Istio](https://istio.io/latest/docs/reference/config/metrics/)

---

## Support and Issues

For issues specific to this implementation:
1. Check the Troubleshooting Guide above
2. Review Istio logs: `kubectl logs -n istio-system -l app=istiod`
3. Check ztunnel logs: `kubectl logs -n istio-system -l app=ztunnel`
4. Consult Istio community Slack or GitHub issues
