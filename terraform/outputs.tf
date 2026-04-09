# ──────────────────────────────────────────────────────────────────
# outputs.tf — Expose useful values from the Terraform apply run.
#              These appear in the GitHub Actions workflow log and
#              can be used by downstream configurations.
# ──────────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "region" {
  description = "AWS region where the cluster is deployed."
  value       = var.region
}

output "vpc_id" {
  description = "ID of the VPC created for the cluster."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs of the private subnets where nodes are running."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs of the public subnets for load balancers."
  value       = module.vpc.public_subnets
}
