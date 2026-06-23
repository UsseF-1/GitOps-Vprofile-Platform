module "ebs_csi_irsa_role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version = "~> 5.50"

    role_name = "ebs-csi-driver-role"

    attach_ebs_csi_policy = true

    oidc_providers = {
        main = {
        provider_arn = module.eks.oidc_provider_arn

        namespace_service_accounts = [
            "kube-system:ebs-csi-controller-sa"
        ]
        }
    }
}