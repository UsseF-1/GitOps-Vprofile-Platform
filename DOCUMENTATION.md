# 📚 Technical Documentation — GitOps Vprofile

## Table of Contents

1. [Architecture Deep Dive](#1-architecture-deep-dive)
2. [Component Breakdown](#2-component-breakdown)
3. [Data Flow & Request Flow](#3-data-flow--request-flow)
4. [Infrastructure Explanation](#4-infrastructure-explanation)
5. [CI/CD Pipeline Explanation](#5-cicd-pipeline-explanation)
6. [Security Considerations](#6-security-considerations)
7. [Scaling Considerations](#7-scaling-considerations)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Architecture Deep Dive

### What is GitOps?

GitOps is an operational framework that treats Git as the **single source of truth** for both application code and infrastructure configuration. Every change to infrastructure or application state must be expressed as a commit to a Git repository. Automated tools detect these changes and reconcile the live system to match the desired state in Git.

The critical distinction from standard DevOps is **access control**: in a true GitOps model, no human has direct access to the production environment. The only path to change anything is via a Git commit → pull request → review → merge workflow.

### How this project implements GitOps

```
┌─────────────────────────────────────────────────────────────────────┐
│  GITOPS PRINCIPLE          →   IMPLEMENTATION IN THIS PROJECT        │
├─────────────────────────────────────────────────────────────────────┤
│  Declarative configuration  →  Terraform HCL + Helm values.yaml     │
│  Versioned and immutable    →  Git history + ECR image tags          │
│  Pulled automatically       →  GitHub Actions (event-driven)         │
│  Continuously reconciled    →  terraform apply on every main push    │
│  Drift prevention           →  No direct AWS console access          │
└─────────────────────────────────────────────────────────────────────┘
```

### Two-repository strategy

The project uses **two separate Git repositories** — a deliberate architectural decision:

**Repository 1: `iac-vprofile`** (Infrastructure)
- Contains: Terraform code for VPC and EKS cluster
- Branches: `staging` (test) and `main` (apply)
- Audience: DevOps/SRE team
- Change frequency: Low (infrastructure changes infrequently)

**Repository 2: `vprofile-action`** (Application)
- Contains: Java source code, Dockerfile, Helm charts
- Branch: `main`
- Audience: Developers + DevOps team
- Change frequency: High (application changes frequently)

**Why separate repositories?**

Coupling infrastructure and application code in one repo creates problems:
- Every app commit triggers an expensive Terraform run
- Infrastructure changes are buried in application history
- Different teams need different permissions (devs should not touch Terraform)
- Infrastructure has a slower, more deliberate review cadence
- The two concerns have different blast radii if something goes wrong

---

## 2. Component Breakdown

### 2.1 GitHub Actions Workflows

#### `terraform.yml` — Infrastructure Pipeline

This workflow is the GitOps engine for infrastructure. It triggers on any push to `main` or `staging` branches **when files inside the `terraform/` directory change**.

```
Trigger: push to staging or main (terraform/** paths)

Job: terraform
  Step 1: actions/checkout@v4
    → Clones the repository into a fresh Ubuntu container

  Step 2: aws-actions/configure-aws-credentials@v4
    → Exports AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
      from GitHub Secrets into the runner environment

  Step 3: hashicorp/setup-terraform@v3
    → Downloads and installs Terraform 1.6.3 binary

  Step 4: terraform init -backend-config="bucket=$BUCKET_TF_STATE"
    → Connects to the S3 backend to read/write the state file
    → Downloads required provider plugins (AWS, Kubernetes, TLS, etc.)
    → The bucket name comes from the BUCKET_TF_STATE GitHub Secret

  Step 5: terraform fmt -check
    → Verifies code formatting compliance
    → Non-zero exit code fails the workflow (enforces code standards)

  Step 6: terraform validate
    → Validates HCL syntax and provider schema compliance
    → Catches type errors, undefined references, etc.

  Step 7: terraform plan -no-color -input=false -out planfile
    → Queries the AWS API to compare desired state (code) vs actual state
    → Saves the execution plan to a binary 'planfile'
    → The planfile is used by apply to prevent TOCTOU race conditions

  Step 8: [conditional] terraform apply -parallelism=1 planfile
    → Only executes when: github.ref == 'refs/heads/main' AND event == push
    → -parallelism=1 prevents race conditions with module dependencies
    → Uses the planfile so exactly what was reviewed is what gets applied

  Step 9: [conditional] Deploy NGINX Ingress Controller
    → Updates kubeconfig to authenticate with the new EKS cluster
    → Applies the NGINX Ingress Controller manifest from the official repo
    → This creates the AWS Network Load Balancer
```

#### `main.yml` — Application Pipeline

Three sequential jobs, each depending on the previous:

```
Trigger: workflow_dispatch OR push to main

JOB 1: Testing (ubuntu-latest)
  ├── actions/checkout@v4
  ├── mvn test              → JUnit tests, JaCoCo coverage report
  ├── mvn checkstyle:checkstyle → Code style report
  ├── actions/setup-java@v4 → Switch to Java 11 (SonarCloud requirement)
  ├── warchant/setup-sonar-scanner@v7 → Install SonarScanner CLI
  ├── sonar-scanner [args]  → Upload test + coverage + checkstyle to SonarCloud
  └── sonarsource/sonarqube-quality-gate-action → Poll quality gate result
      (fails if quality gate status != "OK")

JOB 2: BUILD_AND_PUBLISH (needs: Testing)
  ├── actions/checkout@v4
  └── appleboy/docker-ecr-action → Build Dockerfile, tag with:
        - 'latest'
        - github.run_number (e.g., "42")
      Then push both tags to ECR

JOB 3: DeployToEKS (needs: BUILD_AND_PUBLISH)
  ├── actions/checkout@v4
  ├── aws-actions/configure-aws-credentials@v4
  ├── aws eks update-kubeconfig → Generate ~/.kube/config for EKS
  ├── kubectl create secret docker-registry regcred
  │       → ECR pull secret using dynamic password from 'aws ecr get-login-password'
  └── bitovi/github-actions-deploy-eks-helm → helm upgrade --install
        chart: helm/vprofilecharts
        values: appimage=<ECR_URI>/vprofileapp, apptag=<run_number>
```

---

### 2.2 Terraform Modules

#### VPC Module (`vpc.tf`)

Uses `terraform-aws-modules/vpc/aws v5.0.0` — the official, battle-tested community module.

**Resources created:**
- 1× VPC with CIDR `10.0.0.0/16` (65,536 addresses)
- 3× Public subnets (`10.0.4-6.0/24`) — one per AZ
- 3× Private subnets (`10.0.1-3.0/24`) — one per AZ
- 1× Internet Gateway (attached to the VPC)
- 1× NAT Gateway (in a public subnet, with Elastic IP)
- 2× Route tables (public routes to IGW; private routes to NAT GW)

**Subnet tags for EKS:**
```
Public subnets:  kubernetes.io/cluster/<name>=shared
                 kubernetes.io/role/elb=1
Private subnets: kubernetes.io/cluster/<name>=shared
                 kubernetes.io/role/internal-elb=1
```
These tags are mandatory — without them, EKS cannot auto-discover subnets for the AWS Load Balancer Controller.

#### EKS Module (`ekscluster.tf`)

Uses `terraform-aws-modules/eks/aws v19.19.1`.

**Resources created:**
- EKS Control Plane (managed by AWS, multi-AZ by default)
- EKS Managed Node Group: 2× `t3.small` instances in private subnets
- IAM Role for EKS (allows EKS to call AWS APIs)
- IAM Role for EC2 nodes (allows nodes to join cluster, pull from ECR)
- Security groups for control plane ↔ node communication
- `aws-auth` ConfigMap for RBAC

**Why `cluster_endpoint_public_access = true`?**
GitHub Actions runners execute outside the VPC. The EKS API server must be publicly accessible for `kubectl` and `helm` commands in the workflow to succeed. In production, you would restrict this to specific IP ranges or use a VPN/bastion.

---

### 2.3 Helm Chart

The Helm chart packages three Kubernetes resources:

**`vproappdefinition.yml` (Deployment)**
- Runs the Vprofile Tomcat container
- Image: `{{ .Values.appimage }}:{{ .Values.apptag }}` — injected at deploy time
- `RollingUpdate` strategy with `maxUnavailable: 0` — zero-downtime deployments
- Readiness/liveness probes on `/` port 8080
- References `regcred` image pull secret for ECR authentication

**`vproappservice.yml` (Service)**
- Type: `ClusterIP` — not exposed to the internet directly
- Routes port 8080 → pod port 8080
- Selected by `app: vpro-app` label

**`vproingress.yaml` (Ingress)**
- Routes `vprofile.yourdomain.com/*` → service `my-app:8080`
- Uses `ingressClassName: nginx` to target the NGINX controller
- NGINX Ingress Controller must be deployed first (done by terraform.yml)

---

### 2.4 Dockerfile

Multi-stage build for the Vprofile Java application:

```dockerfile
Stage 1 (BUILD_IMAGE):
  Base:    maven:3.9.4-eclipse-temurin-17
  Actions: Copy pom.xml → download dependencies → copy src → mvn install
  Output:  /app/target/vprofileapp-v2.war

Stage 2 (Runtime):
  Base:    tomcat:9.0-jdk17-temurin-jammy  (~220MB vs ~600MB full JDK)
  Actions: Remove default ROOT webapp → copy WAR as ROOT.war
  Exposes: Port 8080
```

**Why multi-stage?**  
The Maven build requires the full JDK + Maven toolchain (~600MB). The runtime only needs the JRE + Tomcat. By copying only the compiled WAR, the final image is ~220MB instead of ~850MB. Smaller images mean:
- Faster ECR push/pull
- Reduced attack surface (no compiler, no maven, no dev tools in production)
- Lower egress costs when pods restart on new nodes

---

## 3. Data Flow & Request Flow

### 3.1 CI/CD Data Flow (Code Change)

```
Developer pushes code to 'main' branch of vprofile-action
         │
         ▼
GitHub triggers 'main.yml' workflow
         │
         ├──► JOB 1: Testing
         │         │
         │         ├── mvn test ──────────────────► target/surefire-reports/
         │         ├── mvn checkstyle ─────────────► target/checkstyle-result.xml
         │         ├── sonar-scanner ──────────────► SonarCloud API
         │         └── quality gate check ◄────────── SonarCloud API
         │                   │ PASS
         ▼
         ├──► JOB 2: BUILD_AND_PUBLISH
         │         │
         │         ├── docker build ──────────────► Local Docker image
         │         └── docker push ───────────────► Amazon ECR
         │               Tags: latest, <run_number>
         │                   │ PUSH SUCCESS
         ▼
         └──► JOB 3: DeployToEKS
                   │
                   ├── aws eks update-kubeconfig ──► ~/.kube/config
                   ├── kubectl create secret ──────► Kubernetes (regcred)
                   └── helm upgrade --install ─────► EKS Cluster
                         appimage=<ECR_URI>/vprofileapp
                         apptag=<run_number>
                               │
                               ▼
                   Kubernetes pulls image from ECR
                   Rolling update: new pods up → old pods down
```

### 3.2 End-User Request Flow (HTTP Traffic)

```
Browser: http://vprofile.yourdomain.com
         │
         ▼
[DNS] CNAME: vprofile.yourdomain.com → <NLB>.elb.amazonaws.com
         │
         ▼
[AWS Network Load Balancer]
  Created by NGINX Ingress Controller deployment
  Listens on port 80/443
         │
         ▼
[NGINX Ingress Controller Pod]
  Reads Ingress resource: host=vprofile.yourdomain.com → service my-app:8080
         │
         ▼
[Kubernetes Service: my-app (ClusterIP)]
  Selector: app=vpro-app
  Port: 8080 → TargetPort: 8080
         │
         ▼
[Vprofile App Pod (Tomcat)]
  Processes request, returns HTML response
         │
         ▼
Response travels back through the same path
```

---

## 4. Infrastructure Explanation

### 4.1 Network Design

```
VPC: 10.0.0.0/16
│
├── Public Subnets (10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24)
│   ├── Internet Gateway → direct internet access
│   ├── NAT Gateway (1x) → provides internet access to private subnets
│   └── Network Load Balancer → created by NGINX Ingress Controller
│
└── Private Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
    └── EKS Worker Nodes (t3.small)
        ├── System pods (kube-proxy, coredns, aws-node)
        ├── NGINX Ingress Controller pod
        └── Vprofile application pods
```

**Why private subnets for nodes?**
Worker nodes handle actual workloads and should not be directly reachable from the internet. Private subnets with NAT Gateway outbound access are the standard EKS production pattern. Inbound traffic is controlled exclusively through the Ingress/Load Balancer layer.

### 4.2 Terraform State Management

The `terraform.tfstate` file is the critical artifact that maps Terraform resource definitions to real AWS resource IDs. Without it, Terraform cannot update or delete resources.

**Local state (unsafe for CI/CD):**
- Lives on the machine where `terraform apply` ran
- GitHub Actions containers are ephemeral — destroyed after each run
- A new run without the state file would try to recreate everything → duplicate resources and billing

**S3 remote state (this project):**
- Lives permanently in the S3 bucket
- Shared between all workflow runs
- Bucket versioning enabled → recover from accidental corruption
- Public access blocked → no data exposure

**State locking:**  
For production, add a DynamoDB table for state locking to prevent concurrent Terraform runs:
```hcl
backend "s3" {
  dynamodb_table = "vprofile-tf-lock"
}
```

### 4.3 EKS Node Group Sizing

| Parameter | Value | Rationale |
|---|---|---|
| Instance type | `t3.small` | 2 vCPU, 2GB RAM — adequate for demo/practice |
| Desired size | 2 | One redundant node for rolling updates |
| Min size | 1 | Allows scale-down to save cost when idle |
| Max size | 3 | Headroom for load spikes |

For production: use `t3.medium` (4GB) or larger, min 2 per AZ for true HA.

---

## 5. CI/CD Pipeline Explanation

### 5.1 Infrastructure Pipeline Branch Strategy

```
Developer pushes Terraform change to 'staging' branch
         │
         ▼
Workflow runs: init → fmt → validate → plan
         │
         └── Workflow STOPS (does not apply on staging)
                   │
                   ▼
         Developer reviews Terraform plan output in GitHub Actions logs
                   │
                   ▼
         Pull Request: staging → main
                   │
                   ├── Code reviewer checks the plan output
                   └── Approves → Merges to main
                             │
                             ▼
                   Workflow runs again on main branch:
                   init → fmt → validate → plan → APPLY
```

**Why this two-branch strategy?**
- `staging` is a safety net — catch errors before they affect production
- Terraform plan on staging shows exactly what will change
- The PR creates an audit trail: who approved what infrastructure change and when
- The actual apply runs from `main`, which requires a merge (i.e., approval)

### 5.2 Image Tagging Strategy

Every Docker image is pushed with **two tags**:
- `latest` — always points to the most recent build
- `<github.run_number>` — immutable numeric tag (e.g., `42`, `43`, `44`)

The Helm chart is deployed with the run number tag. This means:
- Helm knows which exact image version is deployed
- Kubernetes can detect a real image change (vs. mutable `latest` tag)
- Rolling back is as simple as `helm rollback vprofile-stack <revision>`
- ECR shows a clear history of every deployed version

### 5.3 Quality Gate Integration

The SonarCloud quality gate step polls the SonarCloud API every few seconds after the scan completes. If the quality gate is `ERROR` (e.g., too many bugs, too little coverage), the step exits with a non-zero code, failing the entire workflow.

This means **no image is ever built or deployed from code that fails quality checks**. The developer must fix the issues, push again, and pass the gate before deployment proceeds.

---

## 6. Security Considerations

### 6.1 Secrets Management

| Risk | Mitigation |
|---|---|
| IAM keys in code | All keys stored in GitHub Secrets — encrypted at rest, masked in logs |
| IAM keys in local files | `setup-aws-prereqs.sh` stores keys directly to GitHub Secrets, never to disk |
| State file exposure | S3 bucket has public access blocked and versioning enabled |
| Docker image vulnerabilities | ECR `scanOnPush=true` — each push triggers an automated vulnerability scan |
| Kubernetes pull secret exposure | `regcred` secret is created from a dynamic ECR token (12-hour TTL), not static |

### 6.2 Access Control Model

```
┌───────────────────────────────────────────┐
│  WHO                │  CAN DO             │
├───────────────────────────────────────────┤
│  Developer          │  Push to Git        │
│  DevOps Engineer    │  Push to Git        │
│  Team Lead          │  Approve PRs        │
│  GitHub Actions     │  Apply to AWS       │
│  Nobody             │  Direct AWS access  │
└───────────────────────────────────────────┘
```

### 6.3 IAM Policy Principle of Least Privilege

The project uses `AdministratorAccess` for simplicity. For production, use the scoped policy defined in `configs/aws-iam-policy.json` which grants only the specific permissions required:
- EKS management
- EC2 (for node groups)
- Scoped S3 (only the state bucket)
- ECR (push and pull)
- KMS (EKS secret encryption)
- CloudWatch Logs (EKS control plane logging)

### 6.4 Network Security

- Worker nodes in **private subnets** — not directly reachable from the internet
- EKS API server has **public access** (required for GitHub Actions) — in production, restrict to known CIDRs
- All application traffic flows through **NLB → NGINX Ingress → ClusterIP Service** — no NodePort exposure
- Security groups are auto-managed by the EKS module with least-privilege rules

### 6.5 Container Security

- Multi-stage Dockerfile eliminates build tools (Maven, JDK compiler) from the runtime image
- Running as the default Tomcat user (non-root in newer Tomcat images)
- ECR image scanning enabled on push
- Image immutability enforced by numeric tags — `latest` is supplementary only

---

## 7. Scaling Considerations

### 7.1 Horizontal Pod Autoscaler (HPA)

Add an HPA to automatically scale the Vprofile deployment:

```yaml
# kubernetes/vproapp-hpa.yml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vproapp-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vproapp
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### 7.2 Cluster Autoscaler

The EKS node group is configured with `min_size=1`, `max_size=3`. To enable automatic node scaling, deploy the **Cluster Autoscaler**:

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=vprofile-eks \
  --set awsRegion=us-east-2
```

### 7.3 NAT Gateway — Single vs. Multi-AZ

| Mode | Cost | Availability |
|---|---|---|
| Single NAT GW (this project) | ~$0.045/hr | If NAT GW AZ fails, private subnets lose internet |
| One per AZ (production) | ~$0.135/hr | Each AZ independently routes outbound traffic |

Change `single_nat_gateway = false` in `vpc.tf` for production HA.

### 7.4 EKS Control Plane Scaling

The EKS control plane is fully managed by AWS and scales automatically. You do not need to manage its capacity.

---

## 8. Troubleshooting

### 8.1 Terraform Workflow Failures

**`Error: Backend configuration changed`**
```
Error: Backend configuration changed
A change in the backend configuration has been detected
```
**Fix:** The S3 bucket name in the workflow secret doesn't match the last `terraform init`. Run:
```bash
terraform init -backend-config="bucket=YOUR_BUCKET" -reconfigure
```

---

**`Error: Invalid required_version constraint`**
```
Error: Unsupported Terraform Core version. Required: >= 1.6.3. Got: 1.5.x
```
**Fix:** The `setup-terraform` action installed an older version. Pin it:
```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.6.3
```

---

**Terraform plan shows unexpected destroys**
```
Plan: 0 to add, 1 to change, 5 to destroy
```
**Fix:** Review the plan output carefully. Common causes:
- Changing the `cluster_name` variable (EKS identifies by name)
- Changing `cidr` values on existing subnets
- Changing `availability_zones` count

If unintended, revert the code change and commit again.

---

### 8.2 Application Workflow Failures

**`Error: SonarQube server cannot be reached`**
```
ERROR: SonarQube server [https://...] can not be reached
```
**Fix:** The `SONAR_URL` secret is missing or incorrect. Add it:
```
SONAR_URL = https://sonarcloud.io
```

---

**Quality gate returns `ERROR`**
```
ERROR: QUALITY GATE STATUS: ERROR
```
**Fix:** Check the SonarCloud project dashboard for details. Options:
1. Fix the code issues reported and push again
2. Adjust the quality gate rules in SonarCloud (for practice only)

---

**ECR push fails: `no basic auth credentials`**
```
Error response from daemon: no basic auth credentials
```
**Fix:** The `REGISTRY` secret contains the ECR repo name appended. It should be **only** the registry URI:
```
# Correct:   123456789012.dkr.ecr.us-east-2.amazonaws.com
# Incorrect: 123456789012.dkr.ecr.us-east-2.amazonaws.com/vprofileapp
```

---

**Helm deploy fails: `ImagePullBackOff`**
```
Warning  Failed  ErrImagePull: could not pull image: ...
```
**Fix:** The `regcred` secret was not created or has expired. Check:
```bash
kubectl get secret regcred -n default -o yaml
kubectl describe pod <pod-name> -n default
```
The `DeployToEKS` job recreates this secret with `--dry-run=client -o yaml | kubectl apply -f -`. Verify the job completed successfully.

---

**`kubectl: command not found` in workflow**

The workflow installs kubectl via `azure/setup-kubectl@v3`. If this step is missing or fails, subsequent kubectl commands fail. Check workflow logs for the `Install kubectl` step.

---

### 8.3 EKS / Kubernetes Issues

**Pods stuck in `Pending` state**
```bash
kubectl describe pod <pod-name> -n default
```
Common causes:
- `Insufficient CPU/memory` → scale up node group in Terraform
- `No nodes available` → check node group health in AWS console
- `Unschedulable` → check taints/tolerations

---

**Ingress has no ADDRESS**
```bash
kubectl get ingress -n default
# NAME          CLASS   HOSTS    ADDRESS   PORTS   AGE
# vproingress   nginx   ...              80      5m
```
**Fix:** NGINX Ingress Controller is not deployed or not running. Check:
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```
If missing, re-run the terraform.yml workflow on `main` which deploys it, or apply manually:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
```

---

**Application returns `502 Bad Gateway`**
The Ingress is routing to a service that has no healthy pods. Check:
```bash
kubectl get pods -n default -l app=vpro-app
kubectl logs <pod-name> -n default
```
If the pod is in `CrashLoopBackOff`, check if the Docker image was built correctly.

---

### 8.4 Cleanup Issues

**`terraform destroy` fails with dependency errors**
This usually means the NGINX Ingress Controller's Network Load Balancer still exists and is attached to a VPC subnet. The EKS module cannot delete the VPC while the NLB is active.

**Fix:** Delete the Ingress Controller first:
```bash
aws eks update-kubeconfig --region us-east-2 --name vprofile-eks
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
# Wait 60 seconds for NLB deregistration
sleep 60
# Then run terraform destroy
```

This is exactly what `scripts/cleanup.sh` automates.
