# ──────────────────────────────────────────────────────────────────
# vpc.tf — Creates a production-grade VPC using the official
#           terraform-aws-modules/vpc module.
#
# Resources provisioned:
#   - 1 VPC (10.0.0.0/16)
#   - 3 Public subnets across 3 AZs
#   - 3 Private subnets across 3 AZs
#   - 1 NAT Gateway (single — saves cost for non-prod)
#   - Internet Gateway
#   - Route tables for public and private subnets
# ──────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "vprofile-vpc"

  # /16 gives us 65,536 addresses — plenty for private/public subnets
  cidr = "10.0.0.0/16"

  # Dynamically pick the first 3 AZs in the configured region
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Private subnets — where EKS worker nodes live (no direct internet)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  # Public subnets — where the NAT gateway and load balancers live
  public_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  # Enable NAT gateway so private subnet instances can reach the internet
  enable_nat_gateway = true

  # Single NAT gateway reduces cost for non-production workloads.
  # For production, use one per AZ for HA.
  single_nat_gateway = true

  # Assign DNS hostnames to instances so EKS node registration works
  enable_dns_hostnames = true

  # ── Tags required by EKS for subnet auto-discovery ──────────────
  # EKS uses these tags to know which subnets it can use for
  # internal load balancers (private) and public load balancers.

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.clusterName}" = "shared"
    "kubernetes.io/role/elb"                   = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.clusterName}" = "shared"
    "kubernetes.io/role/internal-elb"          = 1
  }

  tags = {
    Project     = "vprofile-gitops"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
