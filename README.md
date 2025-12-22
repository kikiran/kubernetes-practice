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
