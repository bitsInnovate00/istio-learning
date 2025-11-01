# APISIX Deployment Fix - etcd Image Issue

## Problem
When deploying APISIX, the etcd StatefulSet was failing with `ImagePullBackOff` error:
```
Failed to pull image "bitnami/etcd:3.5.11": manifest for bitnami/etcd:3.5.11 not found
```

## Root Cause
1. **Image Version**: The bitnami/etcd:3.5.11 tag doesn't exist in the registry
2. **Cluster Configuration**: Initial etcd configuration had mismatched cluster URLs causing crash loop

## Solution Applied

### 1. Changed etcd Image
**From:** `bitnami/etcd:3.5.11`  
**To:** `quay.io/coreos/etcd:v3.5.9` (official CoreOS etcd image)

### 2. Fixed etcd Configuration
Added proper cluster configuration flags:
```yaml
command:
  - etcd
  - --name=etcd0
  - --data-dir=/etcd-data
  - --listen-client-urls=http://0.0.0.0:2379
  - --advertise-client-urls=http://etcd.apisix.svc.cluster.local:2379
  - --listen-peer-urls=http://0.0.0.0:2380
  - --initial-advertise-peer-urls=http://etcd-0.etcd.apisix.svc.cluster.local:2380
  - --initial-cluster=etcd0=http://etcd-0.etcd.apisix.svc.cluster.local:2380
  - --initial-cluster-state=new
```

### 3. Added Resource Limits
```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

## Files Modified
- `manifests/apisix-deployment.yaml` - etcd StatefulSet configuration
- `scripts/deploy-apisix.sh` - Added note about the fix

## Verification

### Check etcd Status
```bash
kubectl get pods -n apisix -l app=etcd
# Should show: etcd-0   1/1   Running
```

### Check APISIX Connection to etcd
```bash
kubectl logs -n apisix -l app=apisix | grep etcd
# Should see: "main etcd watcher started"
```

### Full Deployment Test
```bash
cd /home/user/work/study/istio/Practical-Istio/chapter-ambient-observability
./scripts/deploy-apisix.sh
```

### 4. Fixed Health Check Probes
**Problem:** `/apisix/status` endpoint returns 404 until routes are configured  
**Solution:** Changed to TCP socket probes instead of HTTP:
```yaml
livenessProbe:
  tcpSocket:
    port: 9080
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  tcpSocket:
    port: 9080
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Status
✅ **Fully Fixed** - All components now start successfully:
- etcd: Using quay.io/coreos/etcd:v3.5.9 with proper cluster config
- APISIX: Connects to etcd successfully
- Health checks: Using TCP probes instead of HTTP

## Alternative Solutions (if needed)

### Option 1: Use Different Bitnami Tag
```yaml
image: bitnami/etcd:3.5  # Use major.minor tag
```

### Option 2: Use Latest Official etcd
```yaml
image: quay.io/coreos/etcd:latest
```

### Option 3: Simplify for Development
For development/testing, you can use an in-memory etcd without persistence:
```yaml
# Remove volumeMounts and volumeClaimTemplates
# Add to command:
- --listen-client-urls=http://0.0.0.0:2379
- --advertise-client-urls=http://$(POD_IP):2379
```

## Lessons Learned
1. Always verify Docker image tags exist before deployment
2. Use official images when possible for stability
3. etcd cluster configuration requires precise URL matching
4. StatefulSets with PVCs may need time to fully initialize

## Next Steps
After this fix is applied:
1. etcd starts successfully
2. APISIX can connect to etcd
3. Routes can be configured via Admin API
4. Integration with Istio mesh works as expected

Deploy with:
```bash
./scripts/deploy-apisix.sh
./scripts/test-apisix.sh
```
