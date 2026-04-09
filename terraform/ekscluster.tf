# ──────────────────────────────────────────────────────────────────
# ekscluster.tf — Creates an EKS cluster with a managed node group
#                 using the official terraform-aws-modules/eks module.
#
# Resources provisioned:
#   - EKS Control Plane (managed by AWS)
#   - EKS Managed Node Group (2 t3.small worker nodes)
#   - IAM roles and policies for EKS and EC2 nodes
#   - Security groups for cluster communication
#   - aws-auth ConfigMap for RBAC
# ──────────────────────────────────────────────────────────────────

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.19.1"

  cluster_name    = var.clusterName
  cluster_version = "1.28"

  # VPC and subnets created by vpc.tf
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Expose the cluster API endpoint publicly so GitHub Actions runners
  # (which are not inside the VPC) can authenticate with kubectl.
  cluster_endpoint_public_access = true

  # ── Managed Node Group ──────────────────────────────────────────
  # EC2 instances that run the actual workloads (pods).
  # 't3.small' balances cost and capacity for practice/staging.
  # Scale up instance type and desired_size for production.

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    vprofile_nodes = {
      name = "vprofile-node-group"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      # Use private subnets so nodes are not directly exposed to internet
      subnet_ids = module.vpc.private_subnets

      labels = {
        role    = "worker"
        project = "vprofile-gitops"
      }

      tags = {
        Project     = "vprofile-gitops"
        Environment = "production"
        ManagedBy   = "Terraform"
      }
    }
  }

  tags = {
    Project     = "vprofile-gitops"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# ──────────────────────────────────────────────────────────────────
# Data source: retrieve EKS cluster auth info for the Kubernetes provider
# ──────────────────────────────────────────────────────────────────

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# ──────────────────────────────────────────────────────────────────
# Kubernetes provider: authenticates using EKS cluster credentials
# ──────────────────────────────────────────────────────────────────

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
