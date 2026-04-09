# 🚀 GitOps Vprofile — Production-Ready GitOps Pipeline on AWS EKS

[![Terraform](https://img.shields.io/badge/Terraform-1.6.3-7B42BC?logo=terraform)](https://terraform.io)
[![EKS](https://img.shields.io/badge/Amazon%20EKS-1.28-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1689?logo=helm)](https://helm.sh)
[![SonarCloud](https://img.shields.io/badge/SonarCloud-Quality%20Gate-F3702A?logo=sonarcloud)](https://sonarcloud.io)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=github-actions)](https://github.com/features/actions)

---

## 📖 Description

**GitOps Vprofile** is a complete, production-ready GitOps implementation that manages both **infrastructure provisioning** and **application deployment** entirely through Git — with zero manual AWS console access required.

Every infrastructure change and every code change flows through GitHub Actions pipelines that enforce code review, automated testing, quality gates, and immutable deployments. Manual changes are architecturally impossible because no human holds direct AWS credentials; only the CI/CD system does.

This project deploys a real Java web application (the Vprofile stack) onto an AWS EKS Kubernetes cluster using:
- **Terraform** for infrastructure-as-code (VPC + EKS)
- **Maven + SonarCloud** for build and code quality
- **Docker + Amazon ECR** for container image management
- **Helm** for Kubernetes application packaging
- **GitHub Actions** for the GitOps engine

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        DEVELOPER / ADMIN                        │
│            (only has access to GitHub, NOT to AWS)             │
└──────────────────────────┬──────────────────────────────────────┘
                           │  git push / pull request
          ┌────────────────┴────────────────┐
          │                                 │
          ▼                                 ▼
  ┌───────────────┐                ┌────────────────────┐
  │ iac-vprofile  │                │  vprofile-action   │
  │ (Terraform)   │                │ (App Source Code)  │
  │  Repository   │                │    Repository      │
  └───────┬───────┘                └────────┬───────────┘
          │ GitHub Actions                  │ GitHub Actions
          │ terraform.yml                   │ main.yml
          ▼                                 ▼
  ┌───────────────────────┐    ┌────────────────────────────────┐
  │   STAGING BRANCH      │    │   JOB 1: Testing               │
  │   terraform validate  │    │   mvn test + checkstyle        │
  │   terraform fmt       │    │   SonarCloud analysis          │
  │   terraform plan      │    │   Quality Gate check           │
  └───────┬───────────────┘    └────────────┬───────────────────┘
          │ PR + Approval                   │ success
          │ merge to main                   ▼
          ▼                    ┌────────────────────────────────┐
  ┌───────────────────────┐    │   JOB 2: Build & Publish       │
  │   MAIN BRANCH         │    │   docker build                 │
  │   terraform apply     │    │   docker push → Amazon ECR     │
  │   Creates:            │    │   Tag: latest + run_number     │
  │   - VPC               │    └────────────┬───────────────────┘
  │   - EKS Cluster       │                 │ success
  │   - Node Groups       │                 ▼
  │   - NGINX Ingress     │    ┌────────────────────────────────┐
  └───────┬───────────────┘    │   JOB 3: Deploy to EKS         │
          │                    │   aws eks update-kubeconfig    │
          │                    │   kubectl create secret        │
          ▼                    │   helm upgrade --install       │
  ┌───────────────────────┐    └────────────┬───────────────────┘
  │      AWS CLOUD        │                 │
  │  ┌─────────────────┐  │                 ▼
  │  │   VPC (10.0/16) │◄─┼─────────────────┤
  │  │  ┌───────────┐  │  │         ┌───────────────┐
  │  │  │ Public SN │  │  │         │ Amazon ECR    │
  │  │  │ (NAT GW)  │  │  │         │ vprofileapp   │
  │  │  │ (NLB)     │  │  │         │ :42, :latest  │
  │  │  └───────────┘  │  │         └───────────────┘
  │  │  ┌───────────┐  │  │
  │  │  │ Private SN│  │  │
  │  │  │ EKS Nodes │  │  │
  │  │  │ (t3.small)│  │  │
  │  │  └───────────┘  │  │
  │  └─────────────────┘  │
  └───────────────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Cloud Provider | AWS (EKS, ECR, VPC, S3, IAM) |
| Infrastructure-as-Code | Terraform 1.6.3 |
| Container Orchestration | Amazon EKS (Kubernetes 1.28) |
| Application Packaging | Helm 3.x |
| Container Registry | Amazon ECR |
| CI/CD Engine | GitHub Actions |
| Code Quality | SonarCloud (Maven + Checkstyle) |
| Build Tool | Apache Maven 3.9 |
| Runtime | Apache Tomcat 9 on JDK 17 |
| Ingress | NGINX Ingress Controller |
| State Backend | Amazon S3 (versioned) |

---

## ✨ Features

- **Zero manual AWS access** — all changes flow through Git commits and pull requests
- **Drift prevention** — infrastructure state is tracked in S3, workflows detect and correct drift
- **Branch strategy** — `staging` branch validates; `main` branch deploys
- **Pull request gate** — human review required before any infrastructure change applies
- **Immutable deployments** — every image is tagged with the GitHub run number, enabling exact rollbacks
- **Code quality enforcement** — SonarCloud quality gate blocks deployment of bad code
- **Helm-managed releases** — atomic upgrades with rollback capability
- **Secure secrets management** — zero credentials in code; all stored in GitHub Secrets
- **Multi-stage Docker build** — lean production images without build-time dependencies

---

## 📋 Prerequisites

Before running this project you need:

| Tool | Version | Install |
|---|---|---|
| AWS CLI | v2+ | [docs.aws.amazon.com](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| Terraform | 1.6.3+ | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/downloads) |
| kubectl | 1.28+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.x | [helm.sh](https://helm.sh/docs/intro/install/) |
| GitHub CLI | 2.x | [cli.github.com](https://cli.github.com/) |
| jq | any | `brew install jq` / `apt install jq` |

You also need:
- An **AWS account** with permissions to create VPCs, EKS clusters, ECR repos, IAM users, and S3 buckets
- A **GitHub account** with the two repositories forked
- A **SonarCloud account** (free) with an organization and project created
- A **registered domain name** (for the Ingress hostname)

---

## ⚙️ Installation & Setup

### Step 1 — Fork the repositories

Fork these two repositories into your GitHub account:
- `github.com/hkhcoder/iac-vprofile` → Infrastructure (Terraform)
- `github.com/hkhcoder/vprofile-action` → Application (Java source + Helm)

When forking `iac-vprofile`, **uncheck "Copy the main branch only"** to also get the `staging` branch.

### Step 2 — Run the setup script

```bash
chmod +x scripts/setup-aws-prereqs.sh

./scripts/setup-aws-prereqs.sh \
  --region us-east-2 \
  --bucket-name vprofile-tf-state-$(date +%s) \
  --ecr-repo vprofileapp \
  --iac-repo YOUR_GITHUB_USERNAME/iac-vprofile \
  --app-repo YOUR_GITHUB_USERNAME/vprofile-action
```

This script creates the IAM user, S3 bucket, ECR repository, and stores all AWS credentials directly into GitHub Secrets — **they are never saved locally**.

### Step 3 — Configure SonarCloud

1. Log in to [sonarcloud.io](https://sonarcloud.io)
2. Create an **Organization** (e.g., `vprofile-actions-yourname`)
3. Create a **Project** inside it (e.g., `vproapp`)
4. Go to **My Account → Security** and generate a token
5. Add these secrets to your `vprofile-action` repository:

| Secret Name | Value |
|---|---|
| `SONAR_TOKEN` | The token you just generated |
| `SONAR_ORGANIZATION` | Your SonarCloud organization key |
| `SONAR_PROJECT_KEY` | Your SonarCloud project key |
| `SONAR_URL` | `https://sonarcloud.io` |

### Step 4 — Update configuration values

In `terraform/variables.tf`, set your region and cluster name:
```hcl
variable "region"      { default = "us-east-2" }
variable "clusterName" { default = "vprofile-eks" }
```

In `terraform/terraform.tf`, confirm the backend region matches.

In `.github/workflows/main.yml`, confirm the env vars:
```yaml
env:
  AWS_REGION: us-east-2
  ECR_REPOSITORY: vprofileapp
  EKS_CLUSTER: vprofile-eks
```

In `helm/vprofilecharts/values.yaml`, set your domain:
```yaml
ingress:
  host: "vprofile.yourdomain.com"
```

### Step 5 — Trigger the infrastructure pipeline

1. Make a change in `terraform/` folder on the `staging` branch
2. Push — the workflow runs `terraform validate` + `terraform plan`
3. Open a **Pull Request** from `staging` → `main`
4. Review the Terraform plan output in the PR
5. **Merge** the PR — `terraform apply` runs and creates VPC + EKS + NGINX Ingress

### Step 6 — Trigger the application pipeline

1. Push any change to the `main` branch of `vprofile-action`
2. The workflow runs: Test → Build Docker image → Push to ECR → Deploy via Helm

---

## 🔑 Required GitHub Secrets

### iac-vprofile repository

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `BUCKET_TF_STATE` | S3 bucket name for Terraform state |

### vprofile-action repository

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `REGISTRY` | ECR registry URI (e.g., `123456789.dkr.ecr.us-east-2.amazonaws.com`) |
| `SONAR_TOKEN` | SonarCloud authentication token |
| `SONAR_ORGANIZATION` | SonarCloud organization key |
| `SONAR_PROJECT_KEY` | SonarCloud project key |
| `SONAR_URL` | `https://sonarcloud.io` |

---

## 🧪 Usage & Example Commands

### Validate workflows locally
```bash
chmod +x tests/validate-workflows.sh
./tests/validate-workflows.sh
```

### Run a Terraform plan locally (before pushing)
```bash
chmod +x tests/test-terraform-plan.sh
./tests/test-terraform-plan.sh \
  --bucket your-tf-state-bucket \
  --region us-east-2
```

### Deploy Helm chart manually (debug)
```bash
chmod +x scripts/deploy-helm-local.sh
./scripts/deploy-helm-local.sh \
  --region us-east-2 \
  --cluster-name vprofile-eks \
  --registry 123456789.dkr.ecr.us-east-2.amazonaws.com \
  --ecr-repo vprofileapp \
  --tag 42
```

### Check running pods after deployment
```bash
aws eks update-kubeconfig --region us-east-2 --name vprofile-eks
kubectl get pods -n default
kubectl get ingress -n default
kubectl get svc -n default
```

### Roll back to a previous Helm release
```bash
helm history vprofile-stack
helm rollback vprofile-stack <REVISION_NUMBER>
```

### Destroy all infrastructure
```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh \
  --region us-east-2 \
  --cluster-name vprofile-eks \
  --bucket-name your-tf-state-bucket \
  --tf-dir ./terraform
```

---

## 📁 Folder Structure

```
gitops-vprofile/
│
├── .github/
│   └── workflows/
│       ├── terraform.yml     # IAC pipeline: validate → plan → apply (on main)
│       └── main.yml          # App pipeline: test → build → push ECR → deploy Helm
│
├── terraform/                # Infrastructure-as-Code for VPC + EKS
│   ├── terraform.tf          # Providers, backend (S3), required versions
│   ├── variables.tf          # Input variables (region, cluster name)
│   ├── vpc.tf                # VPC module: subnets, NAT GW, IGW
│   ├── ekscluster.tf         # EKS module: cluster, node groups, IAM roles
│   └── outputs.tf            # Exported values: cluster name, VPC ID, etc.
│
├── helm/
│   └── vprofilecharts/       # Helm chart for the Vprofile application
│       ├── Chart.yaml        # Chart metadata and version
│       ├── values.yaml       # Default values (overridden by CI/CD at deploy time)
│       └── templates/
│           ├── vproappdefinition.yml  # Kubernetes Deployment manifest
│           ├── vproappservice.yml     # Kubernetes ClusterIP Service
│           └── vproingress.yaml       # NGINX Ingress routing rule
│
├── kubernetes/               # Standalone K8s manifests (reference / manual use)
│   ├── vproapp-deployment.yml
│   ├── vproapp-service.yml
│   └── vproingress.yml
│
├── scripts/
│   ├── setup-aws-prereqs.sh  # One-time setup: IAM, S3, ECR, GitHub Secrets
│   ├── cleanup.sh            # Destroy all AWS resources safely
│   └── deploy-helm-local.sh  # Manual Helm deploy for debugging
│
├── configs/
│   ├── sonar-project.properties  # SonarCloud scan configuration reference
│   └── aws-iam-policy.json       # Least-privilege IAM policy reference
│
├── tests/
│   ├── validate-workflows.sh     # actionlint + Helm lint + Terraform fmt check
│   └── test-terraform-plan.sh    # Full local Terraform plan dry-run
│
├── Dockerfile                # Multi-stage build: Maven → Tomcat runtime
├── .gitignore
├── README.md
└── DOCUMENTATION.md
```

---

## 🖼️ Screenshots

| Screenshot | Description |
|---|---|
| `docs/screenshots/terraform-plan-output.png` | GitHub Actions showing Terraform plan with 59 resources |
| `docs/screenshots/sonar-quality-gate.png` | SonarCloud quality gate passing |
| `docs/screenshots/ecr-image-tags.png` | ECR repository with tagged images |
| `docs/screenshots/eks-pods-running.png` | `kubectl get pods` showing running pods |
| `docs/screenshots/vprofile-app-login.png` | Vprofile application login page |

---

## 🔮 Future Improvements

- [ ] **OIDC authentication** — replace long-lived IAM keys with GitHub's OIDC provider for keyless AWS authentication
- [ ] **Slack/Teams notifications** — post pipeline results to a chat channel
- [ ] **Multi-environment support** — add dev/staging/prod environments with separate state files
- [ ] **Horizontal Pod Autoscaler** — auto-scale pods based on CPU/memory metrics
- [ ] **AWS Secrets Manager** — store application database credentials in AWS Secrets Manager instead of Kubernetes Secrets
- [ ] **External DNS** — automate DNS record creation via the ExternalDNS controller
- [ ] **cert-manager** — automatically provision and renew TLS certificates via Let's Encrypt
- [ ] **ArgoCD** — replace Helm-in-CI with a dedicated GitOps controller for pull-based deployments
- [ ] **Per-AZ NAT Gateways** — upgrade from single NAT GW to one per AZ for high availability
- [ ] **Terraform Atlantis** — add PR-based Terraform plan comments via Atlantis

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🤝 Acknowledgements

Built following the GitOps principles taught in the DevOps course by [Imran Teli](https://github.com/hkhcoder). Terraform modules from [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules).
