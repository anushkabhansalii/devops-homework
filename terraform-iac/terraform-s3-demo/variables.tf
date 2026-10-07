variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket will be created."
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name of the S3 bucket."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket names must be 3-63 chars of lowercase letters, numbers, dots and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment tag (dev / staging / prod)."
  default     = "dev"
}

variable "enable_versioning" {
  type        = bool
  description = "Keep every version of every object."
  default     = true
}

variable "use_local_emulator" {
  type        = bool
  description = "Point the provider at a local AWS emulator instead of real AWS."
  default     = false
}

variable "local_endpoint" {
  type        = string
  description = "URL of the local AWS emulator."
  default     = "http://localhost:4566"
}
