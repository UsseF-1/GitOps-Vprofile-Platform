terraform {
    backend "s3" {
        bucket = "gitops-vprofile-project-bucket"
        key    = "dev/terraform.tfstate"
        region = "us-east-1"
        encrypt        = true
        # dynamodb_table = "terraform-locks"  #COST
    }
}