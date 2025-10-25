# Istio Ambient Mode with Complete Observability Stack

This directory contains a complete implementation guide and all necessary files to deploy Istio in **ambient mode** with full observability stack (Prometheus, Grafana, Jaeger, Kiali) on Minikube.

## 📋 What's Included

### Documentation
- `IMPLEMENTATION_GUIDE.md` - Comprehensive step-by-step implementation guide

### Manifests
All Kubernetes manifests are in the `manifests/` directory:
- `telemetry-config.yaml` - Telemetry configuration for tracing and metrics
- `peer-authentication.yaml` - mTLS configuration (STRICT mode)
- `gateway-config.yaml` - Istio ingress gateway configuration
- `bookinfo-app.yaml` - Sample Bookinfo application
- `bookinfo-gateway.yaml` - Gateway and VirtualService for Bookinfo
- `sleep-test.yaml` - Test pod for internal connectivity
- `mtls-test.yaml` - mTLS verification job
- `waypoint-proxy.yaml` - Waypoint proxy for L7 processing (optional)
- `authorization-policy.yaml` - L7 authorization policies (optional)
- `cert-manager-integration.yaml` - Certificate management setup (optional)
- `resource-tuning.yaml` - Resource optimization configurations
- `istiod-hpa.yaml` - Horizontal Pod Autoscaler for istiod

### Scripts
All automation scripts are in the `scripts/` directory:
- `quick-start.sh` - One-command installation of everything
- `verify-installation.sh` - Comprehensive verification of all components
- `generate-traffic.sh` - Generate test traffic for observability
- `open-dashboards.sh` - Open all observability dashboards at once
- `cleanup.sh` - Clean removal of all components

## 🚀 Quick Start

### Prerequisites
- Minikube v1.31+ installed
- kubectl v1.28+ installed
- Docker Desktop or compatible container runtime
- Minimum 16GB RAM, 8 CPU cores available
- 50GB free disk space

### Option 1: Automated Installation (Recommended)

```bash
# Navigate to the directory
cd chapter-ambient-observability

# Make scripts executable
chmod +x scripts/*.sh

# Run the quick start script
./scripts/quick-start.sh
```

This will:
1. Start Minikube with proper resources
2. Download and install Istio 1.24.0+
3. Install Istio with ambient profile
4. Deploy observability stack (Prometheus, Grafana, Jaeger, Kiali)
5. Configure telemetry and mTLS
6. Deploy sample Bookinfo application
7. Verify the installation

### Option 2: Manual Installation

Follow the detailed guide in `IMPLEMENTATION_GUIDE.md` for step-by-step instructions.

## 🔍 Verification

After installation, verify everything is working:

```bash
./scripts/verify-installation.sh
```

This script checks:
- ✅ Minikube cluster health
- ✅ All namespaces created
- ✅ Istio control plane (istiod)
- ✅ Ambient data plane (ztunnel)
- ✅ CNI plugin
- ✅ Observability stack (Prometheus, Grafana, Jaeger, Kiali)
- ✅ Bookinfo application
- ✅ No sidecar proxies (ambient mode)
- ✅ mTLS enabled
- ✅ Application connectivity

## 📊 Access Observability Dashboards

### Option 1: All at Once
```bash
./scripts/open-dashboards.sh
```

### Option 2: Individual Dashboards

**Grafana:**
```bash
kubectl port-forward -n observability svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
```

**Kiali:**
```bash
kubectl port-forward -n observability svc/kiali 20001:20001
# Open http://localhost:20001 (admin/admin)
```

**Jaeger:**
```bash
kubectl port-forward -n observability svc/tracing 16686:16686
# Open http://localhost:16686
```

**Prometheus:**
```bash
kubectl port-forward -n observability svc/prometheus 9090:9090
# Open http://localhost:9090
```

## 🧪 Testing

### Generate Traffic
```bash
# Generate 100 requests with 2s delay
./scripts/generate-traffic.sh 100 2

# Or access the application directly
MINIKUBE_IP=$(minikube ip -p istio-ambient)
curl http://${MINIKUBE_IP}:30080/productpage
```

### Test Internal Communication
```bash
kubectl exec -n bookinfo deploy/sleep -- curl -s http://productpage:9080/productpage
```

### Verify mTLS
```bash
kubectl apply -f manifests/mtls-test.yaml -n bookinfo
kubectl logs -n bookinfo job/mtls-verification
```

## 🎯 Key Features

### Ambient Mode Benefits
- **No Sidecar Containers**: Reduced resource overhead (~100MB per node vs ~120MB per pod)
- **Simplified Operations**: No pod restarts required for mesh enrollment
- **Transparent L4 Processing**: Automatic mTLS and telemetry at node level
- **Optional L7 Processing**: Deploy waypoint proxies only when needed

### Observability Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Pre-configured Istio dashboards for visualization
- **Jaeger**: Distributed tracing with 100% sampling
- **Kiali**: Service mesh topology and health visualization

### Security
- **mTLS STRICT Mode**: Enforced mutual TLS for all service-to-service communication
- **Authorization Policies**: Fine-grained access control (with waypoint proxy)
- **Certificate Management**: Optional cert-manager integration

## 📁 Project Structure

```
chapter-ambient-observability/
├── IMPLEMENTATION_GUIDE.md          # Detailed implementation guide
├── README.md                         # This file
├── manifests/                        # All Kubernetes manifests
│   ├── bookinfo-app.yaml
│   ├── bookinfo-gateway.yaml
│   ├── peer-authentication.yaml
│   ├── telemetry-config.yaml
│   ├── gateway-config.yaml
│   ├── sleep-test.yaml
│   ├── mtls-test.yaml
│   ├── waypoint-proxy.yaml
│   ├── authorization-policy.yaml
│   ├── cert-manager-integration.yaml
│   ├── resource-tuning.yaml
│   └── istiod-hpa.yaml
└── scripts/                          # Automation scripts
    ├── quick-start.sh
    ├── verify-installation.sh
    ├── generate-traffic.sh
    ├── open-dashboards.sh
    └── cleanup.sh
```

## 🔧 Troubleshooting

### Pods Not Starting (OOMKilled)
```bash
# Increase Minikube memory
minikube delete -p istio-ambient
minikube start --cpus=8 --memory=16384 -p istio-ambient
```

### Ambient Mode Not Working
```bash
# Verify ztunnel is running
kubectl get ds -n istio-system ztunnel

# Check namespace label
kubectl get namespace bookinfo -o yaml | grep dataplane-mode
```

### Observability Not Showing Data
```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Restart istiod
kubectl rollout restart deployment/istiod -n istio-system
```

### mTLS Not Enforced
```bash
# Check peer authentication
kubectl get peerauthentication -A

# Test with curl
kubectl exec -n bookinfo deploy/sleep -- curl -v http://productpage:9080/productpage
```

## 🧹 Cleanup

To remove everything:

```bash
./scripts/cleanup.sh
```

This will remove:
- Bookinfo application
- Observability stack
- Istio control plane
- All configurations
- Optionally: Minikube cluster

## 📖 Resources

- [Istio Ambient Mesh Documentation](https://istio.io/latest/docs/ambient/)
- [Istio Observability](https://istio.io/latest/docs/tasks/observability/)
- [Implementation Guide](./IMPLEMENTATION_GUIDE.md)

## 🎓 Learning Path

1. **Day 1**: Environment setup and Istio installation
2. **Day 2**: Observability stack and application deployment
3. **Day 3**: Testing, validation, and exploration

Estimated time: **2-3 days** for complete implementation and validation

## 📋 Acceptance Criteria Status

- ✅ Istio control plane running (istiod, ingress gateway)
- ✅ Prometheus scraping metrics from Istio components
- ✅ Grafana accessible with pre-configured Istio dashboards
- ✅ Jaeger UI accessible and collecting traces
- ✅ Kiali UI accessible showing service mesh topology
- ✅ Ambient mode working (no sidecars in application pods)
- ✅ mTLS enabled and verified between services
- ✅ Sample application deployed with observability working end-to-end

## 💡 Tips

1. **Resource Management**: Monitor cluster resources with `kubectl top nodes` and `kubectl top pods -A`
2. **Dashboard Exploration**: Start with Kiali for service topology, then dive into Grafana for metrics
3. **Tracing**: Generate traffic first, then explore traces in Jaeger
4. **Performance**: Ambient mode uses significantly less resources than sidecar mode
5. **L7 Features**: Deploy waypoint proxy only when you need L7 authorization policies

## 🤝 Contributing

This implementation is based on the story requirements for deploying Istio with complete observability stack in ambient mode. For improvements or issues, please refer to the main repository documentation.

---

**Note**: This implementation uses Istio 1.24.0+ which includes stable ambient mode support. Make sure to check for the latest Istio version for production deployments.
