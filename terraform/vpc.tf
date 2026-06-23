module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "~> 5.8.0"
    name = "GitOps_vpc"
    cidr = "10.0.0.0/16"

    azs             = [var.zone1, var.zone2]
    private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

    enable_nat_gateway = true
    single_nat_gateway     = true

    public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.eks_name}" = "shared"
}

private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.eks_name}" = "shared"
}

    tags = {
        Name = "GitOps_vpc"
    }
}
