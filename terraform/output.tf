# ─── VPC ────────────────────────────────────────────
output "vpc_id" {
    description = "ID of the VPC"
    value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
    description = "IDs of the private subnets where EKS nodes run"
    value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
    description = "IDs of the public subnets where Ingress lives"
    value       = module.vpc.public_subnets
}

# ─── EKS ────────────────────────────────────────────
output "cluster_name" {
    description = "EKS cluster name — needed to generate kubeconfig"
    value       = module.eks.cluster_name
}

output "cluster_endpoint" {
    description = "EKS cluster API endpoint"
    value       = module.eks.cluster_endpoint
}

# ─── ECR ────────────────────────────────────────────
output "ecr_app_url" {
    description = "ECR URL for app image"
    value       = aws_ecr_repository.app.repository_url
}

output "ecr_db_url" {
    description = "ECR URL for db image"
    value       = aws_ecr_repository.db.repository_url
}

output "ecr_web_url" {
    description = "ECR URL for web image"
    value       = aws_ecr_repository.web.repository_url
}