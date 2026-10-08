terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Team setup: remote state in S3 with native locking (commented out for the local demo)
  # backend "s3" {
  #   bucket       = "anushka-taskboard-tfstate"
  #   key          = "final-project/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  # }
}
