# NATS Server Kubernetes Deployment

This directory contains Kubernetes manifests and scripts to deploy the NATS server in a local Kind cluster or any Kubernetes environment.

## 🚀 Quick Start

### Prerequisites

1. **Kind** - Local Kubernetes cluster
   ```bash
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   chmod +x ./kind
   sudo mv ./kind /usr/local/bin/kind
   ```

2. **kubectl** - Kubernetes command-line tool
   ```bash
   # Install kubectl for your platform
   # https://kubernetes.io/docs/tasks/tools/install-kubectl/
   ```

3. **Docker** - Container runtime

### Automated Setup

```bash
# Setup NATS server on existing Kubernetes cluster
make k8s-setup

# Or use the script directly
./k8s/scripts/setup-kind.sh
```

### Manual Setup

```bash
# 1. Ensure you have a Kubernetes cluster running
# (Kind, Minikube, Docker Desktop, etc.)

# 2. Deploy NATS server
kubectl apply -f k8s/

# 3. Check status
make k8s-status
```

## 📁 File Structure

```
k8s/
├── namespace.yaml          # NATS namespace
├── configmap.yaml          # NATS server configuration
├── secret.yaml            # Authentication credentials
├── deployment.yaml        # NATS server deployment
├── service.yaml           # Services (ClusterIP + NodePort)
├── pvc.yaml              # Persistent volume claim
├── tls-secret.yaml       # TLS certificates (optional)
├── kustomization.yaml    # Kustomize configuration
├── values.yaml           # Configuration values
└── scripts/
    ├── setup-kind.sh     # Automated Kind setup
    ├── cleanup.sh        # Cleanup script
    └── generate-tls.sh   # TLS certificate generation
```

## 🔧 Configuration

### Authentication

The deployment uses username/password authentication configured via Kubernetes secrets:

```yaml
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nats-auth-secret
  namespace: nats-system
type: Opaque
data:
  username: YWRtaW4=  # admin (base64 encoded)
  password: cGFzc3dvcmQxMjM=  # password123 (base64 encoded)
```

**To update credentials:**
```bash
# Generate base64 encoded credentials
echo -n "your_username" | base64
echo -n "your_password" | base64

# Update the secret
kubectl patch secret nats-auth-secret -n nats-system -p '{"data":{"username":"<base64_username>","password":"<base64_password>"}}'
```

### TLS Configuration

For production use, enable TLS:

1. **Generate certificates:**
   ```bash
   make k8s-tls
   # or
   ./k8s/scripts/generate-tls.sh
   ```

2. **Update ConfigMap** (`k8s/configmap.yaml`):
   ```yaml
   # Uncomment TLS section
   tls {
       cert_file: "/etc/nats/certs/tls.crt"
       key_file: "/etc/nats/certs/tls.key"
       ca_file: "/etc/nats/certs/ca.crt"
       verify: true
   }
   ```

3. **Apply TLS secret:**
   ```bash
   kubectl apply -f k8s/tls-secret.yaml
   ```

## 🌐 Services

The deployment creates two services:

### ClusterIP Service
- **Name**: `nats-server`
- **Internal access**: `nats-server.nats-system.svc.cluster.local:4222`
- **HTTP monitoring**: `nats-server.nats-system.svc.cluster.local:8222`

### NodePort Service
- **Name**: `nats-server-nodeport`
- **External access**: `localhost:30422` (NATS client)
- **HTTP monitoring**: `localhost:30822`

## 📊 Monitoring

### Health Checks
- **Health endpoint**: `http://localhost:30822/healthz`
- **Metrics**: `http://localhost:30822/metrics`
- **Server info**: `http://localhost:30822/varz`

### Port Forwarding
```bash
# Port forward for external access
make k8s-port-forward

# Or manually
kubectl port-forward svc/nats-server-nodeport 30422:4222 30822:8222 -n nats-system
```

## 🔍 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n nats-system
kubectl describe pod -n nats-system -l app=nats-server
```

### View Logs
```bash
kubectl logs -n nats-system -l app=nats-server
kubectl logs -n nats-system -l app=nats-server -f  # Follow logs
```

### Check Services
```bash
kubectl get svc -n nats-system
kubectl describe svc nats-server -n nats-system
```

### Test Connection
```bash
# Test NATS connection
nats sub "test" &
nats pub "test" "hello world"

# Test HTTP endpoint
curl http://localhost:30822/healthz
```

## 🧹 Cleanup

### Remove NATS Server
```bash
make k8s-delete
# or
kubectl delete -f k8s/
```

### Remove Kind Cluster
```bash
make k8s-cleanup
# or
./k8s/scripts/cleanup.sh
```

## 🔄 Scaling

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nats-server-hpa
  namespace: nats-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nats-server
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Manual Scaling
```bash
kubectl scale deployment nats-server -n nats-system --replicas=3
```

## 🔐 Security

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nats-network-policy
  namespace: nats-system
spec:
  podSelector:
    matchLabels:
      app: nats-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: nats-system
    ports:
    - protocol: TCP
      port: 4222
    - protocol: TCP
      port: 8222
```

### RBAC (Optional)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nats-server
  namespace: nats-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: nats-server-role
  namespace: nats-system
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nats-server-rolebinding
  namespace: nats-system
subjects:
- kind: ServiceAccount
  name: nats-server
  namespace: nats-system
roleRef:
  kind: Role
  name: nats-server-role
  apiGroup: rbac.authorization.k8s.io
```

## 📈 Production Considerations

1. **Use a proper storage class** for production workloads
2. **Enable TLS** for secure communication
3. **Set up monitoring** with Prometheus and Grafana
4. **Configure resource limits** based on your workload
5. **Use a proper ingress controller** for external access
6. **Set up backup and disaster recovery** for JetStream data
7. **Configure network policies** for security
8. **Use secrets management** (e.g., HashiCorp Vault) for credentials

## 🎯 Makefile Targets

```bash
# Kubernetes operations
make k8s-setup         # Setup NATS server on existing cluster
make k8s-deploy        # Deploy to existing cluster
make k8s-delete        # Delete from cluster
make k8s-cleanup       # Cleanup Kubernetes resources
make k8s-tls           # Generate TLS certificates
make k8s-status        # Check deployment status
make k8s-port-forward  # Port forward services
```
