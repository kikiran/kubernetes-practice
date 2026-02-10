# Complete Guide: Deployment Strategies on AWS EKS

## 📋 Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [EKS Cluster Setup](#eks-cluster-setup)
4. [Application Setup](#application-setup)
5. [Strategy 1: Rolling Update](#strategy-1-rolling-update)
6. [Strategy 2: Canary Deployment](#strategy-2-canary-deployment)
7. [Strategy 3: Blue-Green Deployment](#strategy-3-blue-green-deployment)
8. [Monitoring & Verification](#monitoring--verification)
9. [Rollback Procedures](#rollback-procedures)
10. [Best Practices](#best-practices)

---

## 🎯 Overview

This guide demonstrates three production-grade deployment strategies on AWS EKS:

### Deployment Strategies Comparison

| Strategy | Downtime | Risk | Rollback Speed | Complexity | Traffic Control |
|----------|----------|------|----------------|------------|-----------------|
| **Rolling Update** | None | Medium | Fast | Low | Gradual |
| **Canary** | None | Low | Fast | Medium | Precise % |
| **Blue-Green** | None | Very Low | Instant | High | Instant switch |

### When to Use Which Strategy

**Rolling Update:**
- ✅ Regular updates with backward compatibility
- ✅ Limited infrastructure
- ✅ Low-risk changes
- ❌ Avoid for breaking changes

**Canary:**
- ✅ High-risk features
- ✅ Need to test with real traffic
- ✅ Want precise traffic control
- ✅ A/B testing scenarios

**Blue-Green:**
- ✅ Zero-downtime requirement
- ✅ Need instant rollback
- ✅ Database migration involved
- ❌ Requires 2x infrastructure

---

## ✅ Prerequisites

### 1. Required Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# eksctl
curl --silent --location "https://github.com/weksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Verify installations
aws --version
eksctl version
kubectl version --client
docker --version
```

### 2. AWS Configuration

```bash
# Configure AWS credentials
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

### 3. Required AWS Permissions

Your IAM user/role needs:
- EC2 full access
- EKS full access
- CloudFormation full access
- IAM permissions to create service roles
- VPC permissions

---

## 🚀 EKS Cluster Setup

### Step 1: Create EKS Cluster

```bash
# Create cluster configuration file
cat > eks-cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: deployment-demo-cluster
  region: us-east-1
  version: "1.28"

# Managed Node Groups
managedNodeGroups:
  - name: deployment-demo-ng
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 2
    maxSize: 6
    volumeSize: 20
    ssh:
      allow: true
    labels:
      role: worker
    tags:
      Environment: demo
      Project: deployment-strategies

# Enable necessary addons
addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy

# CloudWatch logging
cloudWatch:
  clusterLogging:
    enableTypes: ["*"]
EOF

# Create the cluster (takes 15-20 minutes)
eksctl create cluster -f eks-cluster.yaml
```

**Expected Output:**
```
2026-02-10 10:00:00 [ℹ]  eksctl version 0.169.0
2026-02-10 10:00:00 [ℹ]  using region us-east-1
2026-02-10 10:00:00 [ℹ]  setting availability zones to [us-east-1a us-east-1b us-east-1c]
...
2026-02-10 10:20:00 [✔]  EKS cluster "deployment-demo-cluster" in "us-east-1" region is ready
```

### Step 2: Verify Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name deployment-demo-cluster

# Verify connection
kubectl get nodes
# Should show 3 nodes in Ready state

# Check cluster info
kubectl cluster-info
eksctl get cluster

# View node details
kubectl get nodes -o wide
```

### Step 3: Install AWS Load Balancer Controller

```bash
# Create IAM OIDC provider
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster deployment-demo-cluster \
    --approve

# Download IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=deployment-demo-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-east-1 \
  --approve

# Install cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager

# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=deployment-demo-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 4: Install Metrics Server

```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

---

## 💻 Application Setup

### Step 1: Clone Repository and Build Images

```bash
# Clone the repository (or create from provided files)
git clone <your-repo-url>
cd deployment-strategies

# Make scripts executable
chmod +x scripts/*.sh

# Login to Docker registry (Docker Hub example)
docker login

# Build v1 (blue)
./scripts/build-images.sh <YOUR_DOCKERHUB_USERNAME> v1 blue

# Build v2 (green)
./scripts/build-images.sh <YOUR_DOCKERHUB_USERNAME> v2 green

# Verify images
docker images | grep deployment-demo
```

### Step 2: Update Kubernetes Manifests

```bash
# Replace YOUR_REGISTRY with your actual registry in all manifest files
find . -name "*.yaml" -type f -exec sed -i "s/YOUR_REGISTRY/<YOUR_DOCKERHUB_USERNAME>/g" {} +

# Verify changes
grep "image:" 1-rolling-update/02-deployment-v1.yaml
```

### Step 3: Create Namespace

```bash
# Create namespace
kubectl apply -f 1-rolling-update/01-namespace.yaml

# Verify
kubectl get namespace deployment-demo
```

---

## 🔄 Strategy 1: Rolling Update

### Overview
Rolling update gradually replaces old pods with new ones, ensuring zero downtime.

### How It Works
```
Initial State: [v1] [v1] [v1] [v1] [v1] [v1]
Step 1:        [v1] [v1] [v1] [v1] [v2] [v2]  (maxSurge: 2)
Step 2:        [v1] [v1] [v2] [v2] [v2] [v2]  (maxUnavailable: 1)
Step 3:        [v2] [v2] [v2] [v2] [v2] [v2]
Final State:   [v2] [v2] [v2] [v2] [v2] [v2]
```

### Step 1: Deploy Initial Version (v1)

```bash
cd 1-rolling-update

# Deploy v1
kubectl apply -f 02-deployment-v1.yaml
kubectl apply -f 03-service.yaml

# Wait for deployment
kubectl rollout status deployment/rolling-demo -n deployment-demo

# Check pods
kubectl get pods -n deployment-demo -l app=rolling-demo
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
rolling-demo-7d4b9c8f5d-2xk9m   1/1     Running   0          30s
rolling-demo-7d4b9c8f5d-4np2q   1/1     Running   0          30s
rolling-demo-7d4b9c8f5d-6rxbv   1/1     Running   0          30s
rolling-demo-7d4b9c8f5d-8th4c   1/1     Running   0          30s
rolling-demo-7d4b9c8f5d-jk2nm   1/1     Running   0          30s
rolling-demo-7d4b9c8f5d-pq7wx   1/1     Running   0          30s
```

### Step 2: Get Service URL

```bash
# Get LoadBalancer URL
kubectl get svc rolling-demo-service -n deployment-demo

# Wait for EXTERNAL-IP
kubectl get svc rolling-demo-service -n deployment-demo -w

# Once you have EXTERNAL-IP, test it
SERVICE_URL=$(kubectl get svc rolling-demo-service -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$SERVICE_URL
```

### Step 3: Monitor Current State

```bash
# Open a new terminal window for continuous monitoring
watch -n 1 kubectl get pods -n deployment-demo -l app=rolling-demo

# In another terminal, monitor in detail
kubectl get pods -n deployment-demo -l app=rolling-demo -w
```

### Step 4: Perform Rolling Update to v2

```bash
# Apply v2 deployment
kubectl apply -f 04-deployment-v2.yaml

# Immediately start watching the rollout
kubectl rollout status deployment/rolling-demo -n deployment-demo --watch

# In the monitoring terminal, you'll see:
# - New pods being created (v2)
# - Old pods being terminated (v1)
# - Gradual transition
```

**What You'll See:**
```
NAME                            READY   STATUS              RESTARTS   AGE   VERSION
rolling-demo-7d4b9c8f5d-2xk9m   1/1     Running             0          5m    v1
rolling-demo-7d4b9c8f5d-4np2q   1/1     Running             0          5m    v1
rolling-demo-7d4b9c8f5d-6rxbv   1/1     Running             0          5m    v1
rolling-demo-7d4b9c8f5d-8th4c   1/1     Running             0          5m    v1
rolling-demo-9k3n2j7g8h-abc12   0/1     ContainerCreating   0          2s    v2  ← New pod
rolling-demo-9k3n2j7g8h-def34   0/1     ContainerCreating   0          2s    v2  ← New pod
```

### Step 5: Test During Rollout

```bash
# In another terminal, continuously test
while true; do 
  curl -s http://$SERVICE_URL | grep -o '"version":"[^"]*"' | cut -d'"' -f4
  sleep 0.5
done

# You'll see mixed output:
# v1
# v1
# v2
# v1
# v2
# v2
```

### Step 6: Verify Completion

```bash
# Check rollout status
kubectl rollout status deployment/rolling-demo -n deployment-demo

# Verify all pods are v2
kubectl get pods -n deployment-demo -l app=rolling-demo

# Check deployment history
kubectl rollout history deployment/rolling-demo -n deployment-demo

# Describe deployment
kubectl describe deployment rolling-demo -n deployment-demo
```

### Step 7: Rollback (if needed)

```bash
# Rollback to previous version
kubectl rollout undo deployment/rolling-demo -n deployment-demo

# Rollback to specific revision
kubectl rollout undo deployment/rolling-demo -n deployment-demo --to-revision=1

# Check rollback status
kubectl rollout status deployment/rolling-demo -n deployment-demo
```

### Understanding maxSurge and maxUnavailable

```yaml
strategy:
  rollingUpdate:
    maxSurge: 2        # Can create 2 extra pods (6+2=8 total during update)
    maxUnavailable: 1  # Can have 1 pod unavailable (minimum 5 ready)
```

**Example with 6 replicas:**
- maxSurge: 2 → Can have up to 8 pods during update
- maxUnavailable: 1 → Must maintain at least 5 ready pods

**Timeline:**
```
Time  | Total | v1  | v2  | Action
------|-------|-----|-----|---------------------------
0:00  | 6     | 6   | 0   | Initial state
0:05  | 8     | 6   | 2   | Create 2 v2 pods (maxSurge)
0:10  | 7     | 5   | 2   | Terminate 1 v1 pod
0:15  | 8     | 5   | 3   | Create 1 v2 pod
0:20  | 7     | 4   | 3   | Terminate 1 v1 pod
...continues until all v1 → v2
```

---

## 🕯️ Strategy 2: Canary Deployment

### Overview
Canary deployment routes a small percentage of traffic to the new version while most traffic goes to the stable version.

### Traffic Distribution Strategy
```
Phase 1: 90% stable (v1), 10% canary (v2)
Phase 2: 75% stable (v1), 25% canary (v2)
Phase 3: 50% stable (v1), 50% canary (v2)
Phase 4: 0% stable (v1), 100% canary (v2) → v2 becomes stable
```

### Step 1: Deploy Stable Version

```bash
cd ../2-canary

# Deploy stable version (v1)
kubectl apply -f 01-deployment-stable.yaml
kubectl apply -f 03-service.yaml

# Wait for deployment
kubectl rollout status deployment/canary-stable -n deployment-demo

# Verify
kubectl get pods -n deployment-demo -l version=stable
```

### Step 2: Get Service URL and Baseline Test

```bash
# Get service URL
CANARY_URL=$(kubectl get svc canary-demo-service -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test stable version
curl http://$CANARY_URL

# Run baseline test (100 requests)
cd ../scripts
./test-deployment.sh http://$CANARY_URL 100
```

**Expected Output (100% v1):**
```
Version Distribution:
  v1: 100 requests (100.00%)

Color Distribution:
  blue: 100 requests (100.00%)
```

### Step 3: Deploy Canary (10% traffic)

```bash
cd ../2-canary

# Deploy canary version (1 replica = ~10% with 9 stable replicas)
kubectl apply -f 02-deployment-canary.yaml

# Verify both deployments
kubectl get deployments -n deployment-demo
# canary-stable: 9/9 replicas
# canary-test: 1/1 replicas

kubectl get pods -n deployment-demo -l app=canary-demo
```

### Step 4: Monitor Canary (10% traffic)

```bash
# Test traffic distribution
../scripts/test-deployment.sh http://$CANARY_URL 100

# Open monitoring dashboard
watch -n 2 'kubectl get pods -n deployment-demo -l app=canary-demo -o wide'

# Monitor logs from canary
kubectl logs -n deployment-demo -l version=canary -f

# Check metrics
kubectl top pods -n deployment-demo -l app=canary-demo
```

**Expected Output (~10% canary):**
```
Version Distribution:
  v1: 90 requests (90.00%)
  v2: 10 requests (10.00%)

Color Distribution:
  blue: 90 requests (90.00%)
  green: 10 requests (10.00%)
```

### Step 5: Increase Canary to 25%

```bash
# Scale stable down, canary up
kubectl scale deployment canary-stable --replicas=6 -n deployment-demo
kubectl scale deployment canary-test --replicas=2 -n deployment-demo

# Wait for scaling
kubectl rollout status deployment/canary-stable -n deployment-demo
kubectl rollout status deployment/canary-test -n deployment-demo

# Test distribution
../scripts/test-deployment.sh http://$CANARY_URL 100
```

**Expected Output (~25% canary):**
```
Version Distribution:
  v1: 75 requests (75.00%)
  v2: 25 requests (25.00%)
```

### Step 6: Increase to 50%

```bash
# Equal distribution
kubectl scale deployment canary-stable --replicas=5 -n deployment-demo
kubectl scale deployment canary-test --replicas=5 -n deployment-demo

# Test
../scripts/test-deployment.sh http://$CANARY_URL 100
```

### Step 7: Full Rollout (100% canary)

```bash
# All traffic to new version
kubectl scale deployment canary-stable --replicas=0 -n deployment-demo
kubectl scale deployment canary-test --replicas=10 -n deployment-demo

# Verify
../scripts/test-deployment.sh http://$CANARY_URL 100
```

**Expected Output (100% v2):**
```
Version Distribution:
  v2: 100 requests (100.00%)

Color Distribution:
  green: 100 requests (100.00%)
```

### Step 8: Promote Canary to Stable

```bash
# Delete old stable deployment
kubectl delete deployment canary-stable -n deployment-demo

# Rename canary to stable
kubectl patch deployment canary-test -n deployment-demo -p '{"metadata":{"name":"canary-stable"}}'

# Or update labels
kubectl label deployment canary-test -n deployment-demo version=stable --overwrite
```

### Step 9: Rollback Canary (if issues detected)

```bash
# Immediately scale down canary
kubectl scale deployment canary-test --replicas=0 -n deployment-demo

# Scale up stable
kubectl scale deployment canary-stable --replicas=10 -n deployment-demo

# Verify rollback
../scripts/test-deployment.sh http://$CANARY_URL 100
```

### Advanced: Automated Canary with Flagger

```bash
# Install Flagger
kubectl apply -k github.com/fluxcd/flagger//kustomize/linkerd

# Create Canary resource
cat <<EOF | kubectl apply -f -
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: automated-canary
  namespace: deployment-demo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: canary-stable
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
EOF
```

---

## 🔵🟢 Strategy 3: Blue-Green Deployment

### Overview
Blue-Green deployment runs two identical production environments. Traffic switches instantly from blue to green.

### Architecture
```
┌─────────────┐
│   Router    │ ◄── Production Service
└──────┬──────┘
       │
       ├─────► Blue (v1) - Currently serving traffic
       │       Pods: 5 replicas
       │
       └─────► Green (v2) - Standby, ready to switch
               Pods: 5 replicas
```

### Step 1: Deploy Blue Environment (Current Production)

```bash
cd ../3-blue-green

# Deploy blue (v1)
kubectl apply -f 01-deployment-blue.yaml
kubectl apply -f 03-service-production-blue.yaml
kubectl apply -f 05-services-preview.yaml

# Wait for deployment
kubectl rollout status deployment/blue-deployment -n deployment-demo

# Verify
kubectl get pods -n deployment-demo -l color=blue
kubectl get svc -n deployment-demo
```

### Step 2: Get Service URLs

```bash
# Production service (currently pointing to blue)
PROD_URL=$(kubectl get svc bluegreen-production -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Blue preview service
BLUE_URL=$(kubectl get svc bluegreen-preview-blue -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Production URL: http://$PROD_URL"
echo "Blue Preview URL: http://$BLUE_URL"

# Test production (should be blue/v1)
curl http://$PROD_URL
```

### Step 3: Deploy Green Environment (New Version)

```bash
# Deploy green (v2) - does NOT receive production traffic yet
kubectl apply -f 02-deployment-green.yaml

# Wait for green deployment
kubectl rollout status deployment/green-deployment -n deployment-demo

# Verify green is running
kubectl get pods -n deployment-demo -l color=green
```

### Step 4: Test Green Environment via Preview Service

```bash
# Get green preview URL
GREEN_URL=$(kubectl get svc bluegreen-preview-green -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Green Preview URL: http://$GREEN_URL"

# Test green directly
curl http://$GREEN_URL

# Run comprehensive tests on green
../scripts/test-deployment.sh http://$GREEN_URL 50

# Verify green is working correctly
echo "Testing green endpoints:"
curl http://$GREEN_URL/health
curl http://$GREEN_URL/version
curl http://$GREEN_URL/api/info
```

### Step 5: Verify Both Environments Running

```bash
# Check all deployments
kubectl get deployments -n deployment-demo

# Expected:
# NAME                READY   UP-TO-DATE   AVAILABLE   AGE
# blue-deployment     5/5     5            5           10m
# green-deployment    5/5     5            5           2m

# Check all pods
kubectl get pods -n deployment-demo -l app=bluegreen-demo

# Verify both are healthy
kubectl get pods -n deployment-demo -l app=bluegreen-demo -o wide
```

### Step 6: Run Final Tests on Green

```bash
# Smoke tests
echo "=== Running smoke tests on Green ==="

# Test all endpoints
for endpoint in / /health /ready /version /api/info; do
    echo "Testing $endpoint..."
    curl -s http://$GREEN_URL$endpoint | jq . || echo "Failed"
done

# Load test
echo "=== Running load test on Green ==="
for i in {1..1000}; do
    curl -s http://$GREEN_URL > /dev/null &
done
wait

# Check green pod resource usage
kubectl top pods -n deployment-demo -l color=green

# Check logs for errors
kubectl logs -n deployment-demo -l color=green --tail=100 | grep -i error
```

### Step 7: SWITCH PRODUCTION TRAFFIC (Blue → Green)

```bash
# 🚨 CRITICAL MOMENT: Switch production traffic to green
kubectl apply -f 04-service-production-green.yaml

echo "✅ Traffic switched to GREEN!"

# Verify the switch
kubectl get svc bluegreen-production -n deployment-demo -o yaml | grep -A 2 selector

# Test production URL (should now be green/v2)
curl http://$PROD_URL
```

**What Happens:**
```
Before:  Production → Blue (v1)
After:   Production → Green (v2)

Time: < 1 second (instant switch)
Downtime: 0
```

### Step 8: Monitor After Switch

```bash
# Monitor production traffic
watch -n 1 'curl -s http://$PROD_URL | jq .version'

# Monitor pod health
kubectl get pods -n deployment-demo -l app=bluegreen-demo -w

# Check for any errors
kubectl logs -n deployment-demo -l color=green --tail=50 -f

# Test production extensively
../scripts/test-deployment.sh http://$PROD_URL 200
```

**Expected Output (100% green):**
```
Version Distribution:
  v2: 200 requests (100.00%)

Color Distribution:
  green: 200 requests (100.00%)
```

### Step 9: Keep Blue as Fallback

```bash
# Keep blue running for quick rollback
kubectl get deployments -n deployment-demo

# Blue is still running with 5 replicas
# Green is now serving production traffic

# Monitor both
kubectl get pods -n deployment-demo -o wide
```

### Step 10: Rollback (If Needed)

```bash
# 🚨 INSTANT ROLLBACK to Blue
kubectl apply -f 03-service-production-blue.yaml

echo "⚡ Rolled back to BLUE!"

# Verify rollback
curl http://$PROD_URL

# Test
../scripts/test-deployment.sh http://$PROD_URL 100
```

**Rollback Time: < 1 second**

### Step 11: Cleanup Old Environment (After Confidence)

```bash
# After green has been stable for some time (e.g., 24 hours)
# and you're confident, delete blue

kubectl delete deployment blue-deployment -n deployment-demo
kubectl delete svc bluegreen-preview-blue -n deployment-demo

# Rename green to blue for next deployment
kubectl patch deployment green-deployment -n deployment-demo \
  -p '{"spec":{"template":{"metadata":{"labels":{"color":"blue"}}}}}'
```

---

## 📊 Monitoring & Verification

### Real-time Monitoring Dashboard

```bash
# Terminal 1: Watch pods
watch -n 1 'kubectl get pods -n deployment-demo -o wide'

# Terminal 2: Watch services
watch -n 1 'kubectl get svc -n deployment-demo'

# Terminal 3: Continuous testing
while true; do
  curl -s http://$SERVICE_URL | jq -r '.version, .color'
  sleep 1
done

# Terminal 4: Resource monitoring
watch -n 2 'kubectl top pods -n deployment-demo'
```

### Detailed Verification Commands

```bash
# Check deployment status
kubectl get deployments -n deployment-demo
kubectl rollout status deployment/DEPLOYMENT_NAME -n deployment-demo

# View deployment details
kubectl describe deployment DEPLOYMENT_NAME -n deployment-demo

# Check pod distribution across nodes
kubectl get pods -n deployment-demo -o wide

# View events
kubectl get events -n deployment-demo --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints -n deployment-demo

# View logs from specific version
kubectl logs -n deployment-demo -l version=v2 --tail=100

# Check resource usage
kubectl top pods -n deployment-demo
kubectl top nodes
```

### Application-level Monitoring

```bash
# Health check all pods
for pod in $(kubectl get pods -n deployment-demo -o name); do
  echo "Checking $pod"
  kubectl exec -n deployment-demo $pod -- curl -s localhost:3000/health | jq .
done

# Response time testing
time curl http://$SERVICE_URL

# Concurrent requests test
for i in {1..50}; do
  curl -s http://$SERVICE_URL &
done
wait
```

### Using K9s for Interactive Monitoring

```bash
# Install k9s
brew install derailed/k9s/k9s  # macOS
# Or download from https://github.com/derailed/k9s

# Launch k9s
k9s -n deployment-demo

# Keyboard shortcuts:
# 0: Show all pods
# 1: Show deployments  
# 2: Show services
# l: View logs
# d: Describe resource
# shift+f: Port forward
```

---

## 🔙 Rollback Procedures

### Rolling Update Rollback

```bash
# Quick rollback to previous version
kubectl rollout undo deployment/rolling-demo -n deployment-demo

# Rollback to specific revision
kubectl rollout history deployment/rolling-demo -n deployment-demo
kubectl rollout undo deployment/rolling-demo -n deployment-demo --to-revision=2

# Monitor rollback
kubectl rollout status deployment/rolling-demo -n deployment-demo
```

### Canary Rollback

```bash
# Emergency rollback: Scale canary to 0
kubectl scale deployment canary-test --replicas=0 -n deployment-demo
kubectl scale deployment canary-stable --replicas=10 -n deployment-demo

# Verify
kubectl get pods -n deployment-demo -l app=canary-demo
```

### Blue-Green Rollback

```bash
# Instant rollback: Switch service back
kubectl apply -f 03-service-production-blue.yaml

# Verify
curl http://$PROD_URL | jq .version
# Should show v1
```

### Automated Rollback Triggers

Create a monitoring script:

```bash
#!/bin/bash
# auto-rollback.sh

ERROR_THRESHOLD=5
ERROR_COUNT=0

while true; do
    # Test endpoint
    response=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVICE_URL/health)
    
    if [ "$response" != "200" ]; then
        ERROR_COUNT=$((ERROR_COUNT + 1))
        echo "Error detected! Count: $ERROR_COUNT"
        
        if [ $ERROR_COUNT -ge $ERROR_THRESHOLD ]; then
            echo "🚨 ERROR THRESHOLD EXCEEDED! Initiating rollback..."
            kubectl rollout undo deployment/rolling-demo -n deployment-demo
            exit 1
        fi
    else
        ERROR_COUNT=0
    fi
    
    sleep 10
done
```

---

## 🎯 Best Practices

### 1. Pre-Deployment Checklist

```bash
# ✅ Verify cluster health
kubectl get nodes
kubectl top nodes

# ✅ Check available resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# ✅ Verify images exist
docker pull YOUR_REGISTRY/deployment-demo:v2

# ✅ Test manifests
kubectl apply --dry-run=client -f deployment.yaml

# ✅ Backup current state
kubectl get deployment rolling-demo -n deployment-demo -o yaml > backup-deployment.yaml
```

### 2. Health Checks Configuration

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 15  # Wait for app to start
  periodSeconds: 10         # Check every 10s
  timeoutSeconds: 3         # Timeout after 3s
  failureThreshold: 3       # Restart after 3 failures

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5    # Start checking early
  periodSeconds: 5          # Check frequently
  timeoutSeconds: 3
  successThreshold: 1       # Ready after 1 success
  failureThreshold: 3       # Remove from LB after 3 failures
```

### 3. Resource Management

```yaml
resources:
  requests:
    cpu: 100m      # Minimum CPU
    memory: 128Mi  # Minimum memory
  limits:
    cpu: 500m      # Maximum CPU
    memory: 512Mi  # Maximum memory
```

### 4. Deployment Speed Control

**Fast rollout (low risk):**
```yaml
strategy:
  rollingUpdate:
    maxSurge: 50%
    maxUnavailable: 25%
```

**Slow rollout (high risk):**
```yaml
strategy:
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### 5. Labels and Annotations

```yaml
metadata:
  labels:
    app: myapp
    version: v2
    environment: production
    team: backend
  annotations:
    deployment.kubernetes.io/revision: "5"
    description: "Added new feature X"
```

### 6. Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: rolling-demo
```

### 7. Testing Strategy

```bash
# 1. Unit tests (before build)
npm test

# 2. Integration tests (after deployment)
./run-integration-tests.sh

# 3. Smoke tests (immediate)
curl http://$URL/health

# 4. Load tests (canary phase)
ab -n 10000 -c 100 http://$URL/

# 5. Monitoring (continuous)
# - Check logs
# - Monitor metrics
# - Alert on errors
```

### 8. Cleanup Strategy

```bash
# Keep last 3 revisions
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-demo
spec:
  revisionHistoryLimit: 3  # Keep only 3 old ReplicaSets
EOF

# Regular cleanup
kubectl delete replicaset --field-selector 'status.replicas=0' -n deployment-demo
```

---

## 🧹 Cleanup

### Cleanup Deployments

```bash
# Delete all resources in namespace
kubectl delete namespace deployment-demo

# Or delete individually
kubectl delete deployment --all -n deployment-demo
kubectl delete service --all -n deployment-demo
kubectl delete pod --all -n deployment-demo
```

### Cleanup EKS Cluster

```bash
# Delete the entire cluster
eksctl delete cluster --name deployment-demo-cluster --region us-east-1

# This will:
# - Delete all node groups
# - Delete the EKS cluster
# - Clean up associated AWS resources
# Takes 10-15 minutes
```

### Cleanup Docker Images

```bash
# Remove local images
docker rmi YOUR_REGISTRY/deployment-demo:v1
docker rmi YOUR_REGISTRY/deployment-demo:v2

# Remove from registry (Docker Hub)
# Go to hub.docker.com and delete manually
# Or use Docker Hub API
```

---

## 📚 Additional Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Kubernetes Deployments**: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- **eksctl Documentation**: https://eksctl.io/
- **Flagger (Automated Canary)**: https://flagger.app/
- **Argo Rollouts**: https://argoproj.github.io/argo-rollouts/

---

## 🎉 Conclusion

You now have hands-on experience with:
- ✅ Setting up AWS EKS cluster
- ✅ Rolling Update deployments
- ✅ Canary deployments with traffic splitting
- ✅ Blue-Green deployments with instant switching
- ✅ Monitoring and verification
- ✅ Rollback procedures
- ✅ Production best practices

**Practice makes perfect!** Try different scenarios and combinations. 🚀
