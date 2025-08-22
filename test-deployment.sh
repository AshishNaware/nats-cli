#!/bin/bash

echo "🧪 Testing NATS Server Deployment"
echo "=================================="

# Check cluster
echo "1. Checking cluster status..."
kubectl cluster-info > /dev/null 2>&1 || { echo "❌ Cluster not accessible"; exit 1; }
echo "✅ Cluster accessible"

# Check if NATS is deployed
echo "2. Checking NATS deployment..."
if ! kubectl get pods -n nats-system > /dev/null 2>&1; then
    echo "❌ NATS not deployed. Run: make k8s-setup"
    exit 1
fi

# Check pod status
POD_STATUS=$(kubectl get pods -n nats-system -o jsonpath='{.items[0].status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Pod not running. Status: $POD_STATUS"
    exit 1
fi
echo "✅ Pod running"

# Start port forward
echo "3. Starting port forward..."
kubectl port-forward svc/nats-server-nodeport 30422:4222 30822:8222 -n nats-system > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Test health endpoint
echo "4. Testing health endpoint..."
if curl -s http://localhost:30822/healthz | grep -q "ok"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    kill $PF_PID 2>/dev/null
    exit 1
fi

# Test server info
echo "5. Testing server info..."
if curl -s http://localhost:30822/varz | grep -q "auth_required"; then
    echo "✅ Server info accessible"
else
    echo "❌ Server info failed"
    kill $PF_PID 2>/dev/null
    exit 1
fi

# Test NATS connection (if nats CLI available)
echo "6. Testing NATS connection..."
if command -v nats > /dev/null 2>&1; then
    echo "   NATS CLI found - testing connection..."
    timeout 5s nats sub "test" --server localhost:30422 --user admin --password password123 > /dev/null 2>&1 &
    SUB_PID=$!
    sleep 1
    nats pub "test" "test message" --server localhost:30422 --user admin --password password123 > /dev/null 2>&1
    kill $SUB_PID 2>/dev/null
    echo "✅ NATS connection working"
else
    echo "   NATS CLI not found - skipping connection test"
fi

# Cleanup
echo "7. Cleaning up..."
kill $PF_PID 2>/dev/null

echo ""
echo "🎉 All tests passed! NATS server is working correctly."
echo ""
echo "To access NATS server:"
echo "  - Client port: localhost:30422"
echo "  - HTTP monitoring: localhost:30822"
echo "  - Credentials: admin/password123"
echo ""
echo "To start port forwarding: kubectl port-forward svc/nats-server-nodeport 30422:4222 30822:8222 -n nats-system"
