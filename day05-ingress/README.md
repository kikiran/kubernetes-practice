# Kubernetes Ingress Demo Project

This project demonstrates how to:

- Deploy multiple applications
- Expose them using ClusterIP services
- Route traffic using Kubernetes Ingress

---

## Architecture

Browser → LoadBalancer → Ingress → Service → Pod

---

## Step 1: Create Namespace

kubectl apply -f namespace.yaml

---

## Step 2: Deploy Applications

kubectl apply -f nginx-deployment.yaml
kubectl apply -f httpd-deployment.yaml

---

## Step 3: Install Ingress Controller

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.2.1/deploy/static/provider/cloud/deploy.yaml

---

## Step 4: Deploy Ingress

kubectl apply -f ingress.yaml

---

## Step 5: Get External IP

kubectl get svc -n ingress-nginx

---

## Access Applications

http://<external-ip>/nginx
http://<external-ip>/httpd

---

## Verify

kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev


## Ingress Options

### Option 1: Simple Host-Based Routing

kubectl apply -f ingress-host.yaml

Access:
http://example.com/nginx
http://example.com/httpd


### Option 2: Regex + Rewrite Routing

kubectl apply -f external-dns.yaml

Access:
http://example.com/nginx/test
http://example.com/httpd/demo


---

## Important

Make sure:

1. Ingress controller is installed
2. DNS points example.com to LoadBalancer IP

OR add entry in /etc/hosts:

<external-ip> example.com
