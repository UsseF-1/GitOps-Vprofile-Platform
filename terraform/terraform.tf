# ──────────────────────────────────────────────────────────────────
# terraform.tf — Provider versions, backend, and required providers
# ──────────────────────────────────────────────────────────────────

terraform {
  # Pin to a tested version to prevent unexpected breaking changes
  required_version = ">=1.6.3"

  # Remote state in S3 — bucket name is injected at runtime via
  # `terraform init -backend-config="bucket=<YOUR_BUCKET>"` in the workflow.
  # This ensures a single source of truth for infrastructure state.
  backend "s3" {
    key    = "terraform.tfstate"
    region = "us-east-2"
    # 'bucket' is NOT hardcoded here — it is passed at init time
    # from the BUCKET_TF_STATE GitHub Secret.
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.25.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
  }
}

# ──────────────────────────────────────────────────────────────────
# Provider configuration
# ──────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.region
}

# Data source: fetch all available AZs in the configured region
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
