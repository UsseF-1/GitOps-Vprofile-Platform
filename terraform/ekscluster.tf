module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "~> 20.0"

    cluster_name    = var.eks_name
    cluster_version = "1.30"

    # Makes the cluster API accessible from your laptop
    cluster_endpoint_public_access = true

    # Gives the person running terraform admin access automatically
    enable_cluster_creator_admin_permissions = true

    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets

    cluster_addons = {
        aws-ebs-csi-driver = {
            most_recent = true
        }
    }

    # This defines the actual servers that run your pods
    eks_managed_node_groups = {
        general = {
            instance_types = ["t3.medium"]
            min_size       = 1
            max_size       = 2
            desired_size   = 1
        }
}

    tags = {
        Name        = "GitOps-EKS-Cluster"
    }
}