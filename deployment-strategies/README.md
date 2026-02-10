# Kubernetes Deployment Strategies on AWS EKS

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-326CE5)](https://kubernetes.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900)](https://aws.amazon.com/eks/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED)](https://www.docker.com/)

Complete, production-ready examples of three Kubernetes deployment strategies on AWS EKS.

## 🎯 What's Included

This repository contains everything you need to learn and implement:

- **Rolling Update Deployments** - Gradual, zero-downtime updates
- **Canary Deployments** - Test new versions with a small percentage of traffic
- **Blue-Green Deployments** - Instant switching between versions

## 📚 Documentation

- **[COMPLETE_GUIDE.md](COMPLETE_GUIDE.md)** - Comprehensive 100+ page guide with step-by-step instructions
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick command reference and cheat sheet
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Overview and comparison of strategies

## 🚀 Quick Start

### Prerequisites
- AWS Account with EKS access
- Docker installed
- kubectl installed
- eksctl installed
- AWS CLI configured

### 1. Clone and Setup

```bash
git clone <repo-url>
cd deployment-strategies

# Make scripts executable
chmod +x scripts/*.sh
```

### 2. Create EKS Cluster

```bash
# Create cluster (15-20 minutes)
eksctl create cluster -f eks-cluster.yaml

# Verify
kubectl get nodes
```

### 3. Build Docker Images

```bash
# Build v1
./scripts/build-images.sh <YOUR_DOCKERHUB_USERNAME> v1 blue

# Build v2
./scripts/build-images.sh <YOUR_DOCKERHUB_USERNAME> v2 green
```

### 4. Try Rolling Update

```bash
# Deploy v1
kubectl apply -f 1-rolling-update/01-namespace.yaml
kubectl apply -f 1-rolling-update/02-deployment-v1.yaml
kubectl apply -f 1-rolling-update/03-service.yaml

# Get URL
SERVICE_URL=$(kubectl get svc rolling-demo-service -n deployment-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test
curl http://$SERVICE_URL

# Update to v2
kubectl apply -f 1-rolling-update/04-deployment-v2.yaml

# Watch rollout
kubectl rollout status deployment/rolling-demo -n deployment-demo
```

## 📊 Strategy Comparison

| Strategy | Downtime | Risk | Rollback | Complexity | Best For |
|----------|----------|------|----------|------------|----------|
| **Rolling** | None | Medium | ~1 min | Low | Regular updates |
| **Canary** | None | Low | ~30 sec | Medium | High-risk features |
| **Blue-Green** | None | Very Low | Instant | High | Critical changes |

## 📁 Project Structure

```
deployment-strategies/
├── app.js                      # Node.js application
├── Dockerfile                  # Docker configuration
├── package.json                # Dependencies
│
├── scripts/
│   ├── build-images.sh        # Build Docker images
│   └── test-deployment.sh     # Test traffic distribution
│
├── 1-rolling-update/          # Rolling update manifests
├── 2-canary/                  # Canary deployment manifests
└── 3-blue-green/              # Blue-green deployment manifests
```

## 🎓 Learning Path

1. **Start with Rolling Update** (Easiest)
   - Follow COMPLETE_GUIDE.md Section 5
   - Practice rollback procedures
   
2. **Move to Canary** (Intermediate)
   - Follow COMPLETE_GUIDE.md Section 6
   - Practice traffic distribution
   
3. **Master Blue-Green** (Advanced)
   - Follow COMPLETE_GUIDE.md Section 7
   - Practice instant switching

## 🔧 Key Features

✅ Production-ready configurations
✅ Health checks and probes
✅ Resource limits
✅ Graceful shutdown
✅ Rollback procedures
✅ Monitoring commands
✅ Testing scripts
✅ Complete documentation

## 📖 Detailed Guides

### Rolling Update
- How it works
- Configuration examples
- Step-by-step deployment
- Rollback procedures
- Best practices

### Canary Deployment
- Traffic splitting strategy
- Gradual rollout phases
- Metrics monitoring
- A/B testing scenarios
- Automated canary with Flagger

### Blue-Green Deployment
- Zero-downtime switching
- Preview environments
- Instant rollback
- Database migration strategies
- Cost optimization

## 🧪 Testing

```bash
# Test traffic distribution
./scripts/test-deployment.sh http://SERVICE_URL 100

# Monitor pods
watch kubectl get pods -n deployment-demo

# Check logs
kubectl logs -n deployment-demo -l app=APP_NAME -f
```

## 🚨 Rollback

```bash
# Rolling Update
kubectl rollout undo deployment/rolling-demo -n deployment-demo

# Canary
kubectl scale deployment canary-test --replicas=0 -n deployment-demo

# Blue-Green (instant)
kubectl apply -f 3-blue-green/03-service-production-blue.yaml
```

## 🧹 Cleanup

```bash
# Delete namespace
kubectl delete namespace deployment-demo

# Delete EKS cluster
eksctl delete cluster --name deployment-demo-cluster --region us-east-1
```

## 📚 Additional Resources

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Flagger - Automated Canary](https://flagger.app/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details

## 🙋 Support

For questions or issues:
- Open an issue on GitHub
- Check the COMPLETE_GUIDE.md troubleshooting section
- Review QUICK_REFERENCE.md for commands

## ⭐ Acknowledgments

- Kubernetes community
- AWS EKS team
- Open source contributors

---

**Made with ❤️ for DevOps Engineers**

**Start your deployment journey today! 🚀**
