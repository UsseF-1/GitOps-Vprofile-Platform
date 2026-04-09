# ──────────────────────────────────────────────────────────────────
# variables.tf — Input variable definitions for the VPC + EKS stack
# ──────────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region where all resources will be provisioned."
  type        = string
  default     = "us-east-2"
}

variable "clusterName" {
  description = "Name of the EKS cluster. Used as a tag on subnets for the load balancer controller."
  type        = string
  default     = "vprofile-eks"
}
