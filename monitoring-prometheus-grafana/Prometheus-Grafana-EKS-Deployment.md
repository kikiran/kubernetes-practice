# Deployment of Prometheus and Grafana using Helm in EKS Cluster

**By Veerababu Narni**  
**Published: Apr 3, 2024**  
**Reading Time: 7 min**

---

## Overview

This guide covers the deployment of Prometheus and Grafana monitoring stack using Helm in an EKS (Elastic Kubernetes Service) cluster. Here's what you'll learn:

1. Install Prometheus and Grafana using Helm
2. Prometheus server processes and stores metrics data
3. Alert manager sends alerts to any systems/channels
4. Grafana visualizes scraped data in UI

---

## Prerequisites

- **EC2 instance**: t2.micro or larger
- **Helm**: Package manager for Kubernetes
- **Security Groups**: Configured properly to allow traffic

### Installing Helm (if not already installed)

```bash
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
```

---

## Step 1: Understanding the Components

### Why Use Helm?

Helm is a package manager for Kubernetes that simplifies the installation of all components in one command. Installing via Helm is recommended because:
- You won't miss any configuration steps
- It's very efficient
- Reduces manual configuration errors

### What is Prometheus?

- **Open-source monitoring tool** for Kubernetes and beyond
- Provides **out-of-the-box monitoring capabilities** for container orchestration platforms
- Can monitor **servers and databases** as well
- **Collects and stores metrics** as time-series data with timestamps
- **Pull-based model**: Scrapes metrics from HTTP endpoints of targets

### What is Grafana?

- **Open-source visualization and analytics software**
- Allows you to **query, visualize, alert on, and explore metrics**
- Works with metrics stored anywhere
- Provides **user-friendly dashboards** compared to Prometheus UI

---

## Step-by-Step Installation

### Step 1: Add Helm Stable Charts Repository

Add the Helm stable charts for your local client:

```bash
helm repo add stable https://charts.helm.sh/stable
```

### Step 2: Add Prometheus Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

### Step 3: Create Prometheus Namespace

```bash
kubectl create namespace prometheus
```

### Step 4: Install Kube-Prometheus-Stack

```bash
helm install stable prometheus-community/kube-prometheus-stack -n prometheus
```

**Note**: This command installs the kube-prometheus-stack, which comes with a Grafana deployment embedded as the default option. You don't need to install Grafana separately.

### Step 5: Verify Installation

Check if Prometheus pods are running:

```bash
kubectl get pods -n prometheus
```

Check the services created:

```bash
kubectl get svc -n prometheus
```

**Important**: Grafana comes bundled with the kube-prometheus-stack. There's no need to install it as a separate tool.

---

## Exposing Prometheus and Grafana to External World

There are two ways to expose services:
1. **NodePort**
2. **LoadBalancer** (recommended)

We'll use LoadBalancer to attach an AWS Load Balancer.

### Expose Prometheus

Edit the Prometheus service to change from ClusterIP to LoadBalancer:

```bash
kubectl edit svc stable-kube-prometheus-sta-prometheus -n prometheus
```

Change the `type` field from `ClusterIP` to `LoadBalancer` and save the file.

After changing, you'll see a LoadBalancer endpoint that you can use to access Prometheus:

```
http://<LOAD_BALANCER_DNS>/
```

### Expose Grafana

Similarly, edit the Grafana service:

```bash
kubectl edit svc stable-grafana -n prometheus
```

Change `type` from `ClusterIP` to `LoadBalancer` and save.

You'll now have a LoadBalancer endpoint for Grafana.

### Get Grafana Admin Password

Retrieve the automatically generated admin password:

```bash
kubectl get secret --namespace prometheus stable-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

**Login Credentials:**
- **Username**: `admin`
- **Password**: [Use the command above to retrieve]

---

## Creating a Dashboard in Grafana

### Step 1: Access Grafana

Navigate to the Grafana LoadBalancer URL in your browser and log in with admin credentials.

### Step 2: Import a Pre-built Dashboard

1. Click on **"+"** icon or **"Import"** option
2. Search for dashboard templates (there are plenty of ready-made templates available)
3. Choose a template that uses Prometheus as the data source

### Step 3: View the Dashboard

Once imported, you'll see comprehensive monitoring data for your EKS cluster, including:

1. **CPU and RAM Usage**
   - Overall cluster resource consumption
   - Per-node breakdown

2. **Pods in Specific Namespace**
   - Pod count by namespace
   - Pod distribution

3. **Pod Up History**
   - Pod lifecycle metrics
   - Restart information

4. **HPA (Horizontal Pod Autoscaler) Metrics**
   - Current replica count
   - Target replica count
   - Scaling events

5. **Resources by Container**
   - CPU usage per container
   - Memory usage per container
   - Container limits

6. **Network Metrics**
   - Network bandwidth usage
   - Packet rate
   - Network errors

---

## Alternative Deployment Methods

There are other ways to deploy Prometheus and Grafana:

1. **Manual Configuration Files**: Create all configuration files for both Prometheus and Grafana and execute them in the correct order

2. **Prometheus Operator**: Simplifies and automates the configuration and management of the Prometheus monitoring stack running on Kubernetes

3. **Helm Chart**: Using Helm to install Prometheus Operator including Grafana

---

## Configuring Alerts with PagerDuty

### Step 1: Log in to PagerDuty

1. Go to [PagerDuty website](https://www.pagerduty.com/)
2. Log in with your credentials

### Step 2: Create a New Service (If Needed)

If you don't have a service already set up:

1. Navigate to the **Services** tab in PagerDuty
2. Click **+ New Service**
3. Enter the service name and other required details
4. Under **Integration Type**, choose **Events API v2** (this allows Grafana to send alerts)
5. Click **Add Service**

### Step 3: Obtain the Integration Key

1. After creating the service, you'll be on the service's **Configuration** page
2. Scroll to the **Integrations** section
3. Find the **Integration Key** under **Integration Settings**
4. **Copy the Integration Key** (you'll need this in Grafana)

### Step 4: Configure PagerDuty Integration in Grafana

#### 4.1 Add PagerDuty Contact Point

1. Go to **Alerting > Contact Points**
2. Click **Add Contact Point**
3. Name it **PagerDuty Alerts**
4. Select **PagerDuty** as the type
5. Enter your **PagerDuty Integration Key**
6. Click **Save**

#### 4.2 Create a High CPU Usage Alert

1. Go to **Alerting > Alert Rules**
2. Click **+ Create Alert Rule**
3. Name it **High CPU Usage Alert**

4. Add the query:

```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

5. Set the alert condition:
   - When **last value is above** `90`
   - For **duration**: 1 minute

6. Under **Notifications**, select **PagerDuty Alerts**

7. Click **Save Alert Rule**

### Step 5: Testing Alerts

1. Go to **Alerting > Alert Rules**
2. Click **Test Rule**
3. When CPU usage exceeds 90%, an alert will be triggered
4. Check PagerDuty to confirm the incident is created
5. Resolve the alert in PagerDuty to test the resolution notification

---

## Key Metrics to Monitor

### CPU Metrics
- Node CPU usage
- Container CPU limits and usage
- Pod CPU requests vs actual usage

### Memory Metrics
- Node memory availability
- Container memory usage
- Memory limits

### Pod Metrics
- Pod restarts
- Pod termination events
- Pod phase distribution

### Network Metrics
- Ingress/Egress bandwidth
- Network packets
- Network errors

### HPA Metrics
- Current replicas
- Target replicas
- Scaling events and history

---

## Best Practices

1. **Set Appropriate Alert Thresholds**
   - Don't alert on every small spike
   - Base thresholds on historical data

2. **Use Meaningful Dashboard Names**
   - Organize dashboards by team or service
   - Use descriptive names

3. **Monitor Multiple Data Sources**
   - Combine Prometheus with other data sources
   - Correlate metrics across systems

4. **Regular Backup**
   - Back up Grafana dashboards and configurations
   - Store alerts configuration in version control

5. **Security**
   - Change default passwords immediately
   - Use RBAC for Kubernetes access
   - Secure the LoadBalancer with security groups

---

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n prometheus
kubectl logs <pod-name> -n prometheus
```

### Service Not Accessible

```bash
kubectl get endpoints -n prometheus
kubectl get svc -n prometheus
```

### High Memory Usage

Check Prometheus retention settings and reduce if necessary.

### No Data in Grafana

1. Verify Prometheus is scraping targets: `http://<PROMETHEUS_LB>/targets`
2. Check data source configuration in Grafana
3. Verify network connectivity between services

---

## Conclusion

Congratulations! 🎉 You have successfully set up a complete monitoring solution using:

✅ **Prometheus** - For metrics collection and storage  
✅ **Grafana** - For visualization and dashboards  
✅ **PagerDuty** - For alerting and incident management  

This setup provides comprehensive visibility into your EKS cluster's health and performance.

---

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Helm Charts Repository](https://github.com/prometheus-community/helm-charts)
- [PagerDuty Integration Guide](https://www.pagerduty.com/docs/)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)

---

**Author**: Veerababu Narni  
**Date**: April 3, 2024  
**Platform**: Medium
