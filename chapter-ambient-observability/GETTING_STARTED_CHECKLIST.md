# Getting Started Checklist - Istio Ambient Mode Implementation

## 📋 Pre-Implementation Checklist

### System Requirements
- [ ] **Operating System**: Linux, macOS, or Windows with WSL2
- [ ] **Minikube**: Version 1.31 or later installed
- [ ] **kubectl**: Version 1.28 or later installed
- [ ] **Docker**: Docker Desktop or compatible runtime running
- [ ] **Hardware**: 
  - [ ] 16GB RAM available (minimum)
  - [ ] 8 CPU cores available
  - [ ] 50GB free disk space
- [ ] **Network**: Stable internet connection for downloads

### Verification Commands
```bash
# Check Minikube
minikube version

# Check kubectl
kubectl version --client

# Check Docker
docker --version
docker ps

# Check available resources
free -h  # Linux/macOS
docker stats  # Check Docker resources
```

## 🚀 Implementation Checklist

### Phase 1: Setup (15 minutes)
- [ ] Clone or navigate to repository
- [ ] Change to implementation directory
  ```bash
  cd /home/user/work/study/istio/Practical-Istio/chapter-ambient-observability
  ```
- [ ] Make scripts executable
  ```bash
  chmod +x scripts/*.sh
  ```
- [ ] Review README.md
- [ ] Review IMPLEMENTATION_GUIDE.md (optional, for manual setup)

### Phase 2: Automated Installation (10 minutes)
- [ ] Run quick start script
  ```bash
  ./scripts/quick-start.sh
  ```
- [ ] Wait for completion (approximately 10 minutes)
- [ ] Review console output for any errors
- [ ] Note the access instructions at the end

### Phase 3: Verification (5 minutes)
- [ ] Run verification script
  ```bash
  ./scripts/verify-installation.sh
  ```
- [ ] Confirm all checks pass (20+ checks)
- [ ] Check Minikube status
  ```bash
  minikube status -p istio-ambient
  ```
- [ ] Verify all pods are running
  ```bash
  kubectl get pods -A
  ```

### Phase 4: Access Dashboards (2 minutes)
- [ ] Open all dashboards
  ```bash
  ./scripts/open-dashboards.sh
  ```
- [ ] Access Grafana at http://localhost:3000
  - [ ] Login with admin/admin
  - [ ] Browse Istio dashboards
- [ ] Access Kiali at http://localhost:20001
  - [ ] Login with admin/admin
  - [ ] View service graph
- [ ] Access Jaeger at http://localhost:16686
  - [ ] Search for traces
- [ ] Access Prometheus at http://localhost:9090
  - [ ] Check targets are up

### Phase 5: Generate Traffic (5 minutes)
- [ ] Generate test traffic
  ```bash
  ./scripts/generate-traffic.sh 50 2
  ```
- [ ] Refresh dashboards to see metrics
- [ ] Check Kiali for traffic flow
- [ ] Check Jaeger for traces
- [ ] Review Grafana metrics

### Phase 6: Manual Testing (10 minutes)
- [ ] Get Minikube IP
  ```bash
  MINIKUBE_IP=$(minikube ip -p istio-ambient)
  echo $MINIKUBE_IP
  ```
- [ ] Test external access
  ```bash
  curl http://${MINIKUBE_IP}:30080/productpage
  ```
- [ ] Test internal communication
  ```bash
  kubectl exec -n bookinfo deploy/sleep -- curl -s http://productpage:9080/productpage
  ```
- [ ] Verify mTLS
  ```bash
  kubectl apply -f manifests/mtls-test.yaml -n bookinfo
  kubectl logs -n bookinfo job/mtls-verification
  ```

### Phase 7: Explore Features (30 minutes)
- [ ] **Grafana Exploration**
  - [ ] View Istio Mesh Dashboard
  - [ ] View Istio Service Dashboard
  - [ ] View Istio Workload Dashboard
  - [ ] Check request rates and latencies
  
- [ ] **Kiali Exploration**
  - [ ] View Graph (Versioned app graph)
  - [ ] Check service health
  - [ ] Verify ambient mode (no sidecar icons)
  - [ ] Review traffic distribution
  
- [ ] **Jaeger Exploration**
  - [ ] Search for productpage service
  - [ ] View distributed traces
  - [ ] Analyze trace details
  - [ ] Check service dependencies
  
- [ ] **Prometheus Exploration**
  - [ ] Run sample queries (see QUICK_REFERENCE.md)
  - [ ] Check Istio metrics
  - [ ] Verify target health

### Phase 8: Ambient Mode Verification (10 minutes)
- [ ] Verify no sidecars in pods
  ```bash
  kubectl get pods -n bookinfo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
  ```
- [ ] Check ztunnel DaemonSet
  ```bash
  kubectl get ds -n istio-system ztunnel
  ```
- [ ] Verify namespace label
  ```bash
  kubectl get namespace bookinfo --show-labels | grep dataplane-mode
  ```
- [ ] Review ambient architecture
  - [ ] Understand ztunnel role
  - [ ] Understand CNI plugin
  - [ ] Compare with sidecar mode

## 📚 Learning Checklist

### Day 1: Environment & Installation
- [ ] Read README.md
- [ ] Read IMPLEMENTATION_GUIDE.md Phase 1-2
- [ ] Understand Minikube setup
- [ ] Learn Istio ambient mode concepts
- [ ] Complete installation
- [ ] Verify all components

### Day 2: Observability & Application
- [ ] Read IMPLEMENTATION_GUIDE.md Phase 3-5
- [ ] Understand observability stack
- [ ] Deploy sample application
- [ ] Generate and analyze traffic
- [ ] Explore all dashboards
- [ ] Understand mTLS configuration

### Day 3: Advanced & Testing
- [ ] Read IMPLEMENTATION_GUIDE.md Phase 6-8
- [ ] Review QUICK_REFERENCE.md
- [ ] Test authorization policies
- [ ] Experiment with waypoint proxy
- [ ] Review resource tuning
- [ ] Plan production migration

## 🎯 Success Criteria Checklist

### Installation Success
- [ ] ✅ Minikube cluster running
- [ ] ✅ Istio control plane (istiod) healthy
- [ ] ✅ Ztunnel DaemonSet running
- [ ] ✅ CNI plugin installed
- [ ] ✅ All observability pods running
- [ ] ✅ Bookinfo application deployed
- [ ] ✅ No sidecars in application pods

### Observability Success
- [ ] ✅ Prometheus scraping metrics
- [ ] ✅ Grafana showing dashboards
- [ ] ✅ Jaeger collecting traces
- [ ] ✅ Kiali showing service graph
- [ ] ✅ All dashboards accessible
- [ ] ✅ Real-time data flowing

### Security Success
- [ ] ✅ mTLS enabled (STRICT mode)
- [ ] ✅ PeerAuthentication configured
- [ ] ✅ Service-to-service encryption working
- [ ] ✅ mTLS test passes

### Application Success
- [ ] ✅ Productpage accessible externally
- [ ] ✅ Internal service communication working
- [ ] ✅ All microservices running
- [ ] ✅ Traffic flowing through mesh

## 🔧 Troubleshooting Checklist

If something goes wrong:

- [ ] Check IMPLEMENTATION_GUIDE.md Troubleshooting section
- [ ] Review QUICK_REFERENCE.md Common Issues
- [ ] Run verification script: `./scripts/verify-installation.sh`
- [ ] Check pod status: `kubectl get pods -A`
- [ ] Check logs:
  ```bash
  kubectl logs -n istio-system -l app=istiod
  kubectl logs -n istio-system -l app=ztunnel
  ```
- [ ] Check events: `kubectl get events -A --sort-by='.lastTimestamp'`
- [ ] Check resources: `kubectl top nodes && kubectl top pods -A`
- [ ] Restart components if needed
- [ ] Consider cleanup and fresh start: `./scripts/cleanup.sh`

## 🧹 Cleanup Checklist

When you're done:

- [ ] Stop port-forwards (Ctrl+C in dashboard terminal)
- [ ] Run cleanup script
  ```bash
  ./scripts/cleanup.sh
  ```
- [ ] Decide whether to keep or delete Minikube cluster
- [ ] Review what you learned
- [ ] Document any custom changes
- [ ] Plan next steps (production migration, etc.)

## 📝 Documentation Review Checklist

Before moving to production:

- [ ] Read all documentation files:
  - [ ] README.md
  - [ ] IMPLEMENTATION_GUIDE.md
  - [ ] QUICK_REFERENCE.md
  - [ ] SUMMARY.md
- [ ] Review all manifest files
- [ ] Understand all scripts
- [ ] Note production considerations
- [ ] Identify customization needs
- [ ] Plan team training

## 🎓 Knowledge Validation Checklist

Confirm you understand:

- [ ] **Ambient Mode**
  - [ ] Difference from sidecar mode
  - [ ] Ztunnel architecture
  - [ ] When to use waypoint proxy
  - [ ] Resource advantages

- [ ] **Istio Components**
  - [ ] istiod (control plane)
  - [ ] ztunnel (data plane)
  - [ ] CNI plugin
  - [ ] Ingress gateway

- [ ] **Observability**
  - [ ] Prometheus metrics
  - [ ] Grafana dashboards
  - [ ] Jaeger tracing
  - [ ] Kiali visualization

- [ ] **Security**
  - [ ] mTLS concepts
  - [ ] PeerAuthentication
  - [ ] AuthorizationPolicy
  - [ ] Certificate management

- [ ] **Traffic Management**
  - [ ] Gateway
  - [ ] VirtualService
  - [ ] DestinationRule
  - [ ] Traffic splitting

## ✨ Next Steps Checklist

After completing this implementation:

- [ ] Experiment with traffic routing
  - [ ] Route by header
  - [ ] Route by weight
  - [ ] Fault injection
  - [ ] Timeouts and retries

- [ ] Explore advanced features
  - [ ] Deploy waypoint proxy
  - [ ] Create authorization policies
  - [ ] Set up certificate rotation
  - [ ] Configure custom metrics

- [ ] Plan production deployment
  - [ ] Choose cloud provider
  - [ ] Size cluster appropriately
  - [ ] Configure high availability
  - [ ] Set up monitoring alerts
  - [ ] Plan migration strategy

- [ ] Team enablement
  - [ ] Share documentation
  - [ ] Conduct training sessions
  - [ ] Create runbooks
  - [ ] Establish support processes

## 📊 Metrics to Track

During and after implementation:

- [ ] Installation time (target: ~10 minutes)
- [ ] Verification pass rate (target: 100%)
- [ ] Dashboard accessibility (target: 100%)
- [ ] Application response time
- [ ] Resource usage vs. allocated
- [ ] Number of issues encountered
- [ ] Time to resolution for issues
- [ ] Team understanding level

---

## 🎉 Completion

Once all checklists are complete:

**You have successfully implemented Istio in ambient mode with complete observability stack!**

- ✅ Production-ready setup
- ✅ Full monitoring and tracing
- ✅ Security enabled (mTLS)
- ✅ Sample application running
- ✅ Team ready for next phase

**Congratulations!** 🎊

---

**Need Help?**
- Review documentation in this directory
- Check QUICK_REFERENCE.md for commands
- Run verify-installation.sh for diagnostics
- Review Istio documentation at istio.io
