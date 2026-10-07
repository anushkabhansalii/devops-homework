# The bucket itself
resource "aws_s3_bucket" "demo" {
  bucket        = var.bucket_name
  force_destroy = true # allow `terraform destroy` even if the bucket has objects (demo only)

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Versioning - keep old versions of overwritten / deleted objects
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Default encryption at rest (SSE-S3 / AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket                  = aws_s3_bucket.demo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# An object uploaded by Terraform, to prove the bucket works
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.demo.id
  key          = "hello.txt"
  content      = "Hello from Terraform - Session 18 - Anushka Jain\n"
  content_type = "text/plain"
}
