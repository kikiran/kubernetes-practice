## 1. Validate Upgrade Strategy

### 1.1 Test in Lower Environments First
- Kubernetes upgrades are **irreversible** in EKS.
- Downgrades are **not supported** once the control plane is upgraded.
- Always perform the upgrade in **dev / test / staging** environments before production.

**Why this matters:**  
Any breaking API changes, add-on incompatibilities, or workload failures must be discovered early to avoid production impact.

## 2. Review Kubernetes Release Notes

- Carefully review:
  - Kubernetes **version release notes**
  - Amazon EKS–specific release notes
- Pay attention to:
  - Removed or deprecated APIs
  - Behavioral changes
  - Feature gates promoted to GA
  - Security and networking changes

  **Why this matters:**  
Workloads or controllers using removed APIs will fail immediately after the upgrade.

## 3. Validate Cluster Health

Before starting the upgrade:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

Ensure:

All nodes are in Ready state

No crash-looping system pods

No ongoing cluster or node group updates

## 4. Cordon and Drain Nodes

```
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### Why this matters:

- Prevents new workloads from being scheduled on nodes being upgraded

- Ensures graceful pod eviction

- Reduces application downtime

Note: Managed node group upgrades automatically cordon and drain nodes, but manual control is recommended for sensitive workloads.

## 5. Control Plane and Node Version Alignment

### 5.1 Control Plane First

- EKS always upgrades the control plane first

- Worker nodes remain on the old version until upgraded

### 5.2 Kubelet Version Compatibility

- The kubelet version should match the control plane version as closely as possible

- While minor skew is allowed, running mismatched versions for long periods is not recommended

## Best practice:

Upgrade node groups immediately after the control plane upgrade completes

### 6. Cluster Autoscaler Compatibility

- Ensure the Cluster Autoscaler version supports Kubernetes 1.35

- The autoscaler version must match the Kubernetes minor version

``` 
kubectl -n kube-system get deployment cluster-autoscaler
```
## 7. Subnet IP Availability
### 7.1 Minimum Available IPs

- Each subnet used by the cluster must have at least 5 available IP addresses

#### Why this matters:

- New nodes require IPs during rolling upgrades

- Insufficient IPs can cause:

- Node provisioning failures

- Stuck node group upgrades

## 8. EKS Add-ons Compatibility

- Ensure all core add-ons support Kubernetes 1.35:

- Amazon VPC CNI

- CoreDNS

- kube-proxy

- AWS Load Balancer Controller

- CSI drivers (EBS / EFS)

#### Action:

Upgrade add-ons before or immediately after the control plane upgrade

