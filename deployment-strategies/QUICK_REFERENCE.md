# Quick Reference - Deployment Strategies Commands

## 🚀 EKS Setup

```bash
# Create cluster
eksctl create cluster -f eks-cluster.yaml

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name deployment-demo-cluster

# Verify
kubectl get nodes
kubectl cluster-info
```

## 🔄 Rolling Update - Quick Commands

```bash
# Deploy v1
kubectl apply -f 1-rolling-update/02-deployment-v1.yaml
kubectl apply -f 1-rolling-update/03-service.yaml

# Get service URL
SERVICE_URL=$(kubectl get svc rolling-demo-service -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Monitor
watch kubectl get pods -n deployment-demo -l app=rolling-demo

# Update to v2
kubectl apply -f 1-rolling-update/04-deployment-v2.yaml

# Watch rollout
kubectl rollout status deployment/rolling-demo -n deployment-demo

# Rollback
kubectl rollout undo deployment/rolling-demo -n deployment-demo

# History
kubectl rollout history deployment/rolling-demo -n deployment-demo
```

## 🕯️ Canary - Quick Commands

```bash
# Deploy stable (90%)
kubectl apply -f 2-canary/01-deployment-stable.yaml
kubectl apply -f 2-canary/03-service.yaml

# Deploy canary (10%)
kubectl apply -f 2-canary/02-deployment-canary.yaml

# Get URL
CANARY_URL=$(kubectl get svc canary-demo-service -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test distribution
./scripts/test-deployment.sh http://$CANARY_URL 100

# Increase canary to 25%
kubectl scale deployment canary-stable --replicas=6 -n deployment-demo
kubectl scale deployment canary-test --replicas=2 -n deployment-demo

# Increase to 50%
kubectl scale deployment canary-stable --replicas=5 -n deployment-demo
kubectl scale deployment canary-test --replicas=5 -n deployment-demo

# Full rollout (100%)
kubectl scale deployment canary-stable --replicas=0 -n deployment-demo
kubectl scale deployment canary-test --replicas=10 -n deployment-demo

# Emergency rollback
kubectl scale deployment canary-test --replicas=0 -n deployment-demo
kubectl scale deployment canary-stable --replicas=10 -n deployment-demo
```

## 🔵🟢 Blue-Green - Quick Commands

```bash
# Deploy blue (production)
kubectl apply -f 3-blue-green/01-deployment-blue.yaml
kubectl apply -f 3-blue-green/03-service-production-blue.yaml
kubectl apply -f 3-blue-green/05-services-preview.yaml

# Deploy green (standby)
kubectl apply -f 3-blue-green/02-deployment-green.yaml

# Get URLs
PROD_URL=$(kubectl get svc bluegreen-production -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GREEN_URL=$(kubectl get svc bluegreen-preview-green -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test green
curl http://$GREEN_URL
./scripts/test-deployment.sh http://$GREEN_URL 50

# SWITCH to green
kubectl apply -f 3-blue-green/04-service-production-green.yaml

# Verify
curl http://$PROD_URL

# ROLLBACK to blue
kubectl apply -f 3-blue-green/03-service-production-blue.yaml
```

## 📊 Monitoring Commands

```bash
# Watch pods
watch -n 1 kubectl get pods -n deployment-demo

# Watch with details
kubectl get pods -n deployment-demo -o wide -w

# View logs
kubectl logs -n deployment-demo -l app=APP_NAME --tail=100 -f

# Check resources
kubectl top pods -n deployment-demo
kubectl top nodes

# View events
kubectl get events -n deployment-demo --sort-by='.lastTimestamp'

# Describe deployment
kubectl describe deployment DEPLOYMENT_NAME -n deployment-demo

# Check service endpoints
kubectl get endpoints -n deployment-demo
```

## 🔧 Useful One-Liners

```bash
# Get all pod versions
kubectl get pods -n deployment-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.version}{"\n"}{end}'

# Count pods by version
kubectl get pods -n deployment-demo -l app=APP_NAME -o json | jq -r '.items[].metadata.labels.version' | sort | uniq -c

# Test endpoint continuously
while true; do curl -s http://$URL | jq -r '.version'; sleep 1; done

# Port forward for local testing
kubectl port-forward -n deployment-demo svc/SERVICE_NAME 8080:80

# Get pod IPs
kubectl get pods -n deployment-demo -o wide | awk '{print $1"\t"$6}'

# Check readiness of all pods
kubectl get pods -n deployment-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Exec into pod
kubectl exec -it -n deployment-demo POD_NAME -- /bin/sh

# Copy files from pod
kubectl cp deployment-demo/POD_NAME:/path/to/file ./local-file
```

## 🧪 Testing Commands

```bash
# Health check all pods
for pod in $(kubectl get pods -n deployment-demo -o name); do
  kubectl exec -n deployment-demo $pod -- curl -s localhost:3000/health
done

# Load test
ab -n 1000 -c 10 http://$URL/

# Concurrent requests
for i in {1..100}; do curl -s http://$URL & done; wait

# Response time
time curl http://$URL

# Custom test script
./scripts/test-deployment.sh http://$URL 200
```

## 🔙 Rollback Commands

```bash
# Rolling Update rollback
kubectl rollout undo deployment/DEPLOYMENT_NAME -n deployment-demo
kubectl rollout undo deployment/DEPLOYMENT_NAME -n deployment-demo --to-revision=2

# Canary rollback
kubectl scale deployment canary-test --replicas=0 -n deployment-demo
kubectl scale deployment canary-stable --replicas=10 -n deployment-demo

# Blue-Green rollback (instant)
kubectl apply -f 3-blue-green/03-service-production-blue.yaml

# Check rollback status
kubectl rollout status deployment/DEPLOYMENT_NAME -n deployment-demo
```

## 🧹 Cleanup Commands

```bash
# Delete namespace (all resources)
kubectl delete namespace deployment-demo

# Delete specific deployment
kubectl delete deployment DEPLOYMENT_NAME -n deployment-demo

# Delete all deployments
kubectl delete deployment --all -n deployment-demo

# Delete EKS cluster
eksctl delete cluster --name deployment-demo-cluster --region us-east-1

# Clean Docker images
docker rmi YOUR_REGISTRY/deployment-demo:v1
docker rmi YOUR_REGISTRY/deployment-demo:v2
docker system prune -a
```

## 🎯 Aliases (Add to ~/.bashrc)

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kl='kubectl logs'
alias kd='kubectl describe'
alias kex='kubectl exec -it'
alias kpf='kubectl port-forward'
alias kdel='kubectl delete'
alias kw='watch kubectl get'
alias kn='kubectl config set-context --current --namespace'
```

## 📐 Scaling Commands

```bash
# Manual scale
kubectl scale deployment DEPLOYMENT_NAME --replicas=10 -n deployment-demo

# Autoscaling
kubectl autoscale deployment DEPLOYMENT_NAME --min=3 --max=10 --cpu-percent=80 -n deployment-demo

# Check HPA
kubectl get hpa -n deployment-demo

# Delete HPA
kubectl delete hpa HPA_NAME -n deployment-demo
```

## 🔍 Debugging Commands

```bash
# Describe pod for errors
kubectl describe pod POD_NAME -n deployment-demo

# Check pod logs
kubectl logs POD_NAME -n deployment-demo
kubectl logs POD_NAME -n deployment-demo --previous  # Previous container

# Interactive shell
kubectl exec -it POD_NAME -n deployment-demo -- /bin/sh

# Debug with ephemeral container
kubectl debug POD_NAME -n deployment-demo -it --image=busybox

# Network debugging
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -n deployment-demo

# Check resource quotas
kubectl describe resourcequota -n deployment-demo

# View all API resources
kubectl api-resources
```

## 💡 Pro Tips

```bash
# Export resources for backup
kubectl get deployment DEPLOYMENT_NAME -n deployment-demo -o yaml > backup.yaml

# Apply with validation
kubectl apply --dry-run=client -f file.yaml
kubectl apply --server-dry-run -f file.yaml

# Diff before apply
kubectl diff -f file.yaml

# Force delete stuck pod
kubectl delete pod POD_NAME -n deployment-demo --force --grace-period=0

# Get resource usage
kubectl top pods -n deployment-demo --sort-by=memory
kubectl top pods -n deployment-demo --sort-by=cpu

# Watch specific field
kubectl get pods -n deployment-demo -w -o jsonpath='{.items[*].status.phase}'

# Create secret from literal
kubectl create secret generic my-secret --from-literal=key=value -n deployment-demo

# Edit resource live
kubectl edit deployment DEPLOYMENT_NAME -n deployment-demo
```
