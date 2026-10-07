# AWS provider.
# By default this talks to real AWS using your normal credentials (aws configure / env vars).
# For this homework I ran it against a LOCAL AWS emulator (Moto in Docker) so no real cloud
# account or money is needed: terraform.tfvars sets use_local_emulator = true.
provider "aws" {
  region = var.aws_region

  # only used with the local emulator (dummy credentials, skip real-AWS checks)
  access_key                  = var.use_local_emulator ? "test" : null
  secret_key                  = var.use_local_emulator ? "test" : null
  skip_credentials_validation = var.use_local_emulator
  skip_requesting_account_id  = var.use_local_emulator
  skip_metadata_api_check     = var.use_local_emulator
  s3_use_path_style           = var.use_local_emulator

  endpoints {
    s3  = var.use_local_emulator ? var.local_endpoint : null
    sts = var.use_local_emulator ? var.local_endpoint : null
  }

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "Session18"
      Owner     = "Anushka Jain"
    }
  }
}
