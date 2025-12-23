# 1. kubernetes-Installation

- [Day-01: Installation](day01-installation)

# 2. Kubernetes Workloads – Pod, ReplicaSet, Deployment

- [Day-02: Worker-node](day02-worker-node)

This repository demonstrates **basic Kubernetes workload resources** using simple YAML examples:

- `pod.yml`
- `replicaset.yml`
- `deployment.yml`

These manifests help understand how Kubernetes runs, manages, and scales containerized applications.

---

## 📁 Repository Structure

```bash
.
├── pod.yml
├── replicaset.yml
├── deployment.yml
└── README.md

| Resource   | Purpose                                          |
| ---------- | ------------------------------------------------ |
| Pod        | Smallest deployable unit                         |
| ReplicaSet | Ensures a fixed number of Pods                   |
| Deployment | Manages ReplicaSets and supports rolling updates |



🔹 What is a Pod?

A Pod is the smallest unit in Kubernetes. It runs one or more containers that share:

Network (IP, ports)

Storage volumes

⚠️ Pods are not self-healing and not recommended for production workloads.


🔹 What is a ReplicaSet?

A ReplicaSet ensures that a specified number of identical Pods are always running.

✔ If a Pod crashes → a new one is created automatically.

✅ When to use ReplicaSet

Rarely used directly

Mostly managed by Deployments

Educational purposes


🔹 What is a Deployment?

A Deployment is the most commonly used workload in Kubernetes.

It provides:

Auto-scaling

Self-healing

Rolling updates

Rollbacks

Deployment internally manages ReplicaSets.

✅ When to use Deployment

Stateless applications

Web servers

APIs

Microservices


| Feature         | Pod | ReplicaSet | Deployment   |
| --------------- | --- | ---------- | ----------   |
| Self-healing    | ❌   | ✅          | ✅          |
| Scaling         | ❌   | ✅          | ✅          |
| Rolling updates | ❌   | ❌          | ✅          |
| Production use  | ❌   | ⚠️ Rare     | ✅          |
```

# 3. Kubernetes Services - NodePort, LoadBalancer, ClusterIP

- [Day-03: Services](day03-service)

1️⃣ ClusterIP (Default)
🔹 Description
Exposes the Service inside the cluster only
Not accessible from outside the cluster
Best for internal communication
🔹 Use cases
Backend services
Internal APIs
Database connections

2️⃣ NodePort
🔹 Description
Exposes the Service on each node’s IP
Uses a port range 30000–32767
Accessible externally via <NodeIP>:<NodePort>
🔹 Use cases
Learning & testing
Simple external access

3️⃣ LoadBalancer
🔹 Description
Exposes Service using a cloud provider load balancer
Automatically assigns an external IP
Built on top of NodePort
🔹 Use cases
Production applications
Public-facing services
Cloud environments (EKS, AKS, GKE)

| Feature         | ClusterIP | NodePort | LoadBalancer |
| --------------- | --------- | -------- | ------------ |
| Internal access | ✅        | ✅       | ✅           |
| External access | ❌        | ✅       | ✅           |
| Cloud required  | ❌        | ❌       | ✅           |
| Production use  | ❌        | ❌       | ✅           |
| Simplicity      | ⭐⭐⭐    | ⭐⭐     | ⭐⭐⭐⭐     |

✅ When to use what?
ClusterIP → Internal communication
NodePort → Learning & debugging
LoadBalancer → Production workloads
