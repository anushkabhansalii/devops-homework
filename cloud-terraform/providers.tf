# Provider 1: AWS. Talks to real AWS by default; terraform.tfvars switches it to a local AWS
# emulator (Moto in Docker) for this homework so no real account / money is needed.
provider "aws" {
  region = var.aws_region

  access_key                  = var.use_local_emulator ? "test" : null
  secret_key                  = var.use_local_emulator ? "test" : null
  skip_credentials_validation = var.use_local_emulator
  skip_requesting_account_id  = var.use_local_emulator
  skip_metadata_api_check     = var.use_local_emulator
  s3_use_path_style           = var.use_local_emulator

  endpoints {
    ec2 = var.use_local_emulator ? var.local_endpoint : null
    s3  = var.use_local_emulator ? var.local_endpoint : null
    sts = var.use_local_emulator ? var.local_endpoint : null
  }

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "Terraform"
      Owner     = "Anushka Jain"
      Session   = "19"
    }
  }
}

# Provider 2: random - generates a unique suffix so the S3 bucket name is globally unique.
provider "random" {}
