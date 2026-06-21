variable "region" {
    description = "AWS region for all resources"
    default     = "us-east-1"
}

variable "zone1" {
    description = "First availability zone"
    default     = "us-east-1a"
}

variable "zone2" {
    description = "Second availability zone"
    default     = "us-east-1b"   
}

variable "eks_name" {
    description = "Name of the EKS cluster"
    default     = "depi_eks"
}