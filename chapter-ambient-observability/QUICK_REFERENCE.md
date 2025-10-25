# Quick Reference Guide - Istio Ambient Mode

## 🚀 Installation Commands

### Quick Start (Automated)
```bash
cd chapter-ambient-observability
chmod +x scripts/*.sh
./scripts/quick-start.sh
```

### Manual Installation (Step by Step)
```bash
# 1. Start Minikube
minikube start --cpus=8 --memory=14336 --disk-size=50g --driver=docker --kubernetes-version=v1.28.0 --profile=istio-ambient

# 2. Download Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.0 sh -
cd istio-1.24.0
export PATH=$PWD/bin:$PATH

# 3. Create namespaces
kubectl create namespace istio-system
kubectl create namespace istio-ingress
kubectl create namespace observability
kubectl create namespace bookinfo

# 4. Install Istio (Ambient Mode)
istioctl install --set profile=ambient --skip-confirmation

# 5. Label namespace for ambient mode
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient

# 6. Install observability (from chapter-ambient-observability directory)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml -n observability
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml -n observability
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml -n observability
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml -n observability

# 7. Apply configurations
kubectl apply -f manifests/telemetry-config.yaml
kubectl apply -f manifests/peer-authentication.yaml

# 8. Deploy sample app
kubectl apply -f manifests/bookinfo-app.yaml -n bookinfo
kubectl apply -f manifests/bookinfo-gateway.yaml -n bookinfo
kubectl apply -f manifests/sleep-test.yaml -n bookinfo
```

## 🔍 Verification Commands

### Check All Components
```bash
./scripts/verify-installation.sh
```

### Check Individual Components
```bash
# Minikube status
minikube status -p istio-ambient

# Istio control plane
kubectl get pods -n istio-system
kubectl get deploy istiod -n istio-system

# Ambient data plane (ztunnel)
kubectl get ds -n istio-system ztunnel

# CNI plugin
kubectl get ds -n istio-system istio-cni-node

# Observability stack
kubectl get pods -n observability

# Application
kubectl get pods -n bookinfo
```

### Verify Ambient Mode
```bash
# Check namespace label
kubectl get namespace bookinfo --show-labels

# Verify no sidecars (should see only 1 container per pod)
kubectl get pods -n bookinfo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

### Verify mTLS
```bash
# Check peer authentication
kubectl get peerauthentication -A

# Run mTLS test
kubectl apply -f manifests/mtls-test.yaml -n bookinfo
kubectl logs -n bookinfo job/mtls-verification
```

## 📊 Access Dashboards

### All Dashboards at Once
```bash
./scripts/open-dashboards.sh
```

### Individual Dashboards
```bash
# Grafana (http://localhost:3000, admin/admin)
kubectl port-forward -n observability svc/grafana 3000:3000

# Kiali (http://localhost:20001, admin/admin)
kubectl port-forward -n observability svc/kiali 20001:20001

# Jaeger (http://localhost:16686)
kubectl port-forward -n observability svc/tracing 16686:16686

# Prometheus (http://localhost:9090)
kubectl port-forward -n observability svc/prometheus 9090:9090
```

## 🧪 Testing

### Generate Traffic
```bash
# Using script
./scripts/generate-traffic.sh 100 2

# Manual
MINIKUBE_IP=$(minikube ip -p istio-ambient)
curl http://${MINIKUBE_IP}:30080/productpage

# Continuous traffic
for i in {1..100}; do curl -s http://${MINIKUBE_IP}:30080/productpage; sleep 2; done
```

### Test Internal Communication
```bash
kubectl exec -n bookinfo deploy/sleep -- curl -s http://productpage:9080/productpage
```

## 🎯 Useful kubectl Commands

### Logs
```bash
# Istiod logs
kubectl logs -n istio-system -l app=istiod

# Ztunnel logs
kubectl logs -n istio-system -l app=ztunnel

# Application logs
kubectl logs -n bookinfo -l app=productpage
```

### Describe Resources
```bash
# Describe pod
kubectl describe pod -n bookinfo <pod-name>

# Describe service
kubectl describe svc -n bookinfo productpage

# Describe gateway
kubectl describe gateway -n bookinfo bookinfo-gateway
```

### Resource Usage
```bash
# Node resources
kubectl top nodes

# All pods
kubectl top pods -A

# Bookinfo pods
kubectl top pods -n bookinfo

# Istio system pods
kubectl top pods -n istio-system
```

## 🔧 Troubleshooting

### Restart Components
```bash
# Restart istiod
kubectl rollout restart deployment/istiod -n istio-system

# Restart ztunnel
kubectl rollout restart ds/ztunnel -n istio-system

# Restart application
kubectl rollout restart deployment/productpage-v1 -n bookinfo
```

### Clean and Redeploy
```bash
# Delete and recreate application
kubectl delete -f manifests/bookinfo-app.yaml -n bookinfo
kubectl apply -f manifests/bookinfo-app.yaml -n bookinfo

# Wait for pods
kubectl wait --for=condition=ready --timeout=300s pod --all -n bookinfo
```

### Check Events
```bash
# Namespace events
kubectl get events -n bookinfo --sort-by='.lastTimestamp'

# All events
kubectl get events -A --sort-by='.lastTimestamp'
```

## 🧹 Cleanup

### Remove Everything
```bash
./scripts/cleanup.sh
```

### Manual Cleanup
```bash
# Delete application
kubectl delete namespace bookinfo

# Delete observability
kubectl delete namespace observability

# Uninstall Istio
istioctl uninstall --purge -y

# Delete namespaces
kubectl delete namespace istio-system
kubectl delete namespace istio-ingress

# Delete Minikube (optional)
minikube delete -p istio-ambient
```

## 📝 Important Notes

### Ambient Mode vs Sidecar Mode
| Feature | Sidecar Mode | Ambient Mode |
|---------|--------------|--------------|
| Label | `istio-injection=enabled` | `istio.io/dataplane-mode=ambient` |
| Data Plane | Envoy sidecar per pod | Ztunnel per node |
| Pod Restart | Required | Not required |
| Resource | ~120MB per pod | ~100MB per node |
| L7 Features | Always available | Requires waypoint |

### Key Components
- **istiod**: Control plane
- **ztunnel**: Ambient data plane (DaemonSet)
- **istio-cni**: CNI plugin for traffic interception
- **waypoint**: Optional L7 proxy for advanced features

### Prometheus Queries
```promql
# Request rate
rate(istio_requests_total[5m])

# Error rate
rate(istio_requests_total{response_code=~"5.."}[5m])

# P95 latency
histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m]))

# Success rate
sum(rate(istio_requests_total{response_code!~"5.."}[5m])) / sum(rate(istio_requests_total[5m]))
```

## 🎓 Learning Resources

### Grafana Dashboards
- Istio Mesh Dashboard
- Istio Service Dashboard
- Istio Workload Dashboard
- Istio Performance Dashboard

### Kiali Features
- Service topology graph
- Traffic flow visualization
- Health status monitoring
- Configuration validation
- Distributed tracing integration

### Jaeger Features
- Distributed trace visualization
- Service dependency analysis
- Latency breakdown
- Error tracking

## 📋 Checklist

### Pre-Installation
- [ ] Minikube installed (v1.31+)
- [ ] kubectl installed (v1.28+)
- [ ] Docker running
- [ ] 16GB RAM available
- [ ] 8 CPU cores available
- [ ] 50GB disk space

### Post-Installation
- [ ] Istiod running
- [ ] Ztunnel DaemonSet healthy
- [ ] CNI plugin installed
- [ ] Prometheus collecting metrics
- [ ] Grafana dashboards accessible
- [ ] Jaeger showing traces
- [ ] Kiali showing topology
- [ ] Bookinfo app deployed
- [ ] No sidecars in app pods
- [ ] mTLS enabled (STRICT)
- [ ] Application accessible

## 🆘 Common Issues

### Issue: OOMKilled Pods
```bash
# Solution: Increase Minikube memory
minikube delete -p istio-ambient
minikube start --cpus=8 --memory=16384 -p istio-ambient
```

### Issue: Pods Not Starting
```bash
# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod
kubectl describe pod -n <namespace> <pod-name>
```

### Issue: Cannot Access Application
```bash
# Check gateway
kubectl get gateway -n bookinfo

# Check virtual service
kubectl get virtualservice -n bookinfo

# Check service
kubectl get svc -n bookinfo productpage

# Get Minikube IP
minikube ip -p istio-ambient
```

### Issue: No Observability Data
```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check telemetry config
kubectl get telemetry -A

# Restart istiod
kubectl rollout restart deployment/istiod -n istio-system
```

## 🔗 Quick Links

- [Main README](./README.md)
- [Implementation Guide](./IMPLEMENTATION_GUIDE.md)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Ambient Mesh Guide](https://istio.io/latest/docs/ambient/)
