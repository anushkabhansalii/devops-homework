# Real AWS by default; terraform.tfvars switches to a local AWS emulator (Moto) for the homework.
provider "aws" {
  region = var.aws_region

  access_key                  = var.use_local_emulator ? "test" : null
  secret_key                  = var.use_local_emulator ? "test" : null
  skip_credentials_validation = var.use_local_emulator
  skip_requesting_account_id  = var.use_local_emulator
  skip_metadata_api_check     = var.use_local_emulator

  endpoints {
    ec2 = var.use_local_emulator ? var.local_endpoint : null
    eks = var.use_local_emulator ? var.local_endpoint : null
    iam = var.use_local_emulator ? var.local_endpoint : null
    kms = var.use_local_emulator ? var.local_endpoint : null
    sts = var.use_local_emulator ? var.local_endpoint : null
  }

  default_tags {
    tags = {
      Project   = "taskboard"
      ManagedBy = "Terraform"
      Owner     = "Anushka Jain"
    }
  }
}
