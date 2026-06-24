# GitOps Vprofile Platform on AWS

## Overview

GitOps Vprofile Platform is an end-to-end DevOps project that demonstrates how to provision, deploy, secure, monitor, and scale a multi-tier application on AWS using modern DevOps practices.

The project automates the complete application lifecycle starting from infrastructure provisioning with Terraform, containerization using Docker, Continuous Integration and Continuous Delivery (CI/CD) with GitHub Actions, deployment to Amazon EKS using Helm Charts, monitoring with Prometheus and Grafana, and application scaling using Kubernetes Horizontal Pod Autoscaler (HPA).

---

# Project Architecture

```text
Developer
    |
    v
GitHub Repository
    |
    v
GitHub Actions CI/CD Pipeline
    |
    +--> Maven Unit Testing
    |
    +--> Docker Image Build
    |
    +--> Trivy Security Scan
    |
    +--> Push Images to Amazon ECR
    |
    +--> Helm Deployment
    |
    v
Amazon EKS Cluster
    |
    +--> Vprofile Application (Tomcat)
    +--> MySQL Database
    +--> RabbitMQ
    +--> Memcached
    |
    +--> Ingress NGINX
    |
    +--> HPA
    |
    +--> Metrics Server
    |
    +--> Prometheus
    |
    +--> Grafana
```

---

# Technologies Used

## Cloud

* AWS VPC
* Amazon EKS
* Amazon ECR
* IAM
* EC2
* Elastic Load Balancer

## Infrastructure as Code

* Terraform

## Containerization

* Docker
* Docker Compose

## Kubernetes

* Kubernetes
* Helm Charts
* Ingress NGINX
* HPA
* Persistent Volumes

## CI/CD

* GitHub Actions

## Security

* Trivy

## Monitoring

* Prometheus
* Grafana
* Metrics Server

---

# Infrastructure Provisioning

The infrastructure is fully provisioned using Terraform.

Resources created:

* Custom VPC
* Public Subnets
* Private Subnets
* Internet Gateway
* NAT Gateway
* Route Tables
* Amazon EKS Cluster
* Managed Node Groups
* Amazon ECR Repositories
* IAM Roles and Policies
* EBS CSI Driver

Infrastructure deployment:

```bash
terraform init
terraform plan
terraform apply
```

Infrastructure destruction:

```bash
terraform destroy
```

---

# Containerization

The application components are containerized using Docker.

Containers:

* Vprofile Application
* MySQL Database
* Web Layer

Images are built automatically through GitHub Actions and stored in Amazon ECR.

Repositories:

* vprofile-app
* vprofile-db
* vprofile-web

---

# Continuous Integration Pipeline

The CI pipeline is implemented using GitHub Actions.

Pipeline stages:

## Test Stage

Runs Maven unit tests.

```bash
mvn clean test
```

## Build Stage

Builds Docker images.

```bash
docker build
```

## Security Scan Stage

Scans container images using Trivy.

Scanned severity levels:

* HIGH
* CRITICAL

## Push Stage

Pushes versioned images to Amazon ECR.

Image tags:

* latest
* commit SHA

---

# Continuous Delivery Pipeline

After successful image push:

1. GitHub Actions authenticates with AWS.
2. Connects to EKS.
3. Updates Kubernetes manifests through Helm.
4. Deploys the new application version.
5. Performs rolling updates without downtime.

Deployment command:

```bash
helm upgrade --install vprofile ./helm/vprofile
```

---

# Kubernetes Deployment

Application components deployed:

## Application Layer

* Vprofile Application

## Database Layer

* MySQL

## Messaging Layer

* RabbitMQ

## Cache Layer

* Memcached

## Networking Layer

* Ingress NGINX

---

# Helm Chart

The project uses a custom Helm Chart for managing Kubernetes resources.

Managed resources:

* Deployments
* Services
* PersistentVolumeClaims
* Secrets
* Ingress
* HPA

Benefits:

* Reusable deployments
* Version control
* Easy upgrades
* Easy rollbacks

---

# Monitoring Stack

The monitoring stack is deployed using Helm.

Components:

## Prometheus

Collects metrics from:

* Kubernetes Nodes
* Pods
* Containers
* Services

## Grafana

Provides visualization dashboards for:

* Cluster CPU Usage
* Cluster Memory Usage
* Node Metrics
* Pod Metrics
* Kubernetes Health

## Metrics Server

Provides metrics for:

* kubectl top nodes
* kubectl top pods
* Horizontal Pod Autoscaler

---

# Horizontal Pod Autoscaler

The application automatically scales based on CPU utilization.

Configuration:

* Minimum Replicas: 1
* Maximum Replicas: 5
* Target CPU Utilization: 70%

Benefits:

* Automatic scaling
* Better availability
* Resource optimization

---

# Security

Container security scanning is integrated into the CI pipeline.

Tool used:

* Trivy

Scans:

* OS vulnerabilities
* Package vulnerabilities
* Critical issues
* High severity issues

---

# Ingress and External Access

Ingress NGINX is used as the entry point for application traffic.

Features:

* External Load Balancer
* Path-based routing
* Kubernetes-native traffic management

---

# Key Features

* Infrastructure as Code using Terraform
* GitOps-inspired deployment workflow
* Automated CI/CD Pipeline
* Security Scanning with Trivy
* Amazon EKS Deployment
* Custom Helm Charts
* Monitoring with Prometheus and Grafana
* Horizontal Pod Autoscaling
* Ingress NGINX Integration
* Production-style Kubernetes Architecture

---

# Future Improvements

* ArgoCD Integration
* Alertmanager Notifications
* Grafana Dashboards as Code
* Blue/Green Deployments
* Canary Releases
* Multi-Environment Deployments
* OIDC Authentication for GitHub Actions

---

# Author

Youssef Ahmed Elsayed

Cloud Operations / DevOps Engineer

AWS | Kubernetes | Terraform | Docker | GitHub Actions | Monitoring
