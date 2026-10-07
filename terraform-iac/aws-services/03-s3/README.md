# S3 — Simple Storage Service (Storage)

**Name:** Anushka Jain

## What is S3?
S3 is AWS's **object storage** service: you store any amount of data as **objects** inside **buckets** and access them over HTTPS (API, CLI, SDK, console). It is designed for **99.999999999% (11 nines) durability** by storing data redundantly across multiple Availability Zones, scales automatically, and you pay only for what you store and transfer. It is *not* a file system or a disk — there are no real folders, no in-place edits; you PUT and GET whole objects.

The bucket I created with Terraform in [`../../terraform-s3-demo`](../../terraform-s3-demo) uses most of the features below (versioning, encryption, public access block, tags, an object).

## Buckets
- A **container** for objects; name is **globally unique** across all AWS accounts (3–63 chars, lowercase, numbers, dots, hyphens)
- Created in **one region** (data stays there unless you replicate it)
- Soft limit of 100 buckets per account (can be raised)
- Bucket-level settings: versioning, encryption, lifecycle rules, policies, logging, replication, Block Public Access, Object Lock, static website hosting, event notifications

## Objects
- An object = **key** (full name, e.g. `logs/2026/10/07/app.log`) + **data** (0 B – 5 TB) + **metadata** (+ optional tags, version ID)
- "Folders" are just key **prefixes** shown by the console
- Uploads over 100 MB should use **multipart upload**
- Strong read-after-write consistency for all operations
- Addressed as `s3://bucket/key` or `https://bucket.s3.<region>.amazonaws.com/key`

## Storage classes
| Class | For | Retrieval | Notes |
|---|---|---|---|
| **S3 Standard** | frequently accessed data | ms | default, ≥3 AZs |
| **S3 Intelligent-Tiering** | unknown / changing patterns | ms | auto-moves objects between tiers, small monitoring fee |
| **S3 Standard-IA** | infrequent but fast access | ms | cheaper storage, per-GB retrieval fee, 30-day min |
| **S3 One Zone-IA** | re-creatable infrequent data | ms | single AZ (less resilient), cheaper |
| **S3 Express One Zone** | ultra-low latency hot data | single-digit ms | directory buckets, single AZ |
| **Glacier Instant Retrieval** | archive accessed ~quarterly | ms | 90-day min |
| **Glacier Flexible Retrieval** | archives | minutes – 12 h | 90-day min |
| **Glacier Deep Archive** | long-term compliance archives | 12 – 48 h | cheapest, 180-day min |

## Versioning
When enabled, S3 keeps **every version** of every object: overwriting creates a new version, deleting just adds a *delete marker* (the old versions are still recoverable). Protects against accidental deletes/overwrites and ransomware.
- States: Unversioned → **Enabled** → Suspended (can never go back to unversioned)
- Old versions still cost storage → combine with lifecycle rules to expire noncurrent versions
- Required for replication and Object Lock
```hcl
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

## Lifecycle policies
Rules that automatically **transition** objects to cheaper classes or **expire** (delete) them based on age, prefix or tags.
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.demo.id
  rule {
    id     = "logs-retention"
    status = "Enabled"
    filter {
      prefix = "logs/"
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
```
Typical: logs → IA after 30 days → Glacier after 90 → delete after 1 year; also abort incomplete multipart uploads after 7 days.

## Encryption
- **In transit**: HTTPS/TLS (enforce with a bucket policy denying `aws:SecureTransport = false`)
- **At rest** (server-side) — since Jan 2023 *every* new object is encrypted by default:
  - **SSE-S3** (AES-256, S3-managed keys) — default, what my demo uses
  - **SSE-KMS** — keys in AWS KMS: key policies, rotation, CloudTrail audit of every decrypt (use S3 Bucket Keys to cut KMS cost)
  - **DSSE-KMS** — dual-layer for strict compliance
  - **SSE-C** — you supply the key per request
- **Client-side** encryption — encrypt before uploading

## Bucket policies
Resource-based JSON policy attached to the bucket — controls access for principals, other accounts, or conditions (IP, VPC endpoint, TLS).
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::anushka-devops-session18-demo", "arn:aws:s3:::anushka-devops-session18-demo/*"],
    "Condition": { "Bool": { "aws:SecureTransport": "false" } }
  }]
}
```
**Block Public Access** (account + bucket level) overrides any policy/ACL that would make data public — keep it ON unless you really host public content (then prefer CloudFront with Origin Access Control). In my demo an anonymous `curl` of the object returned **HTTP 403** because of it, while a signed request worked. ACLs are legacy — new buckets have *Object Ownership = Bucket owner enforced* (ACLs disabled).

## Common use cases
- Backups, disaster recovery, archives (with Glacier classes)
- Static website hosting / frontend assets behind CloudFront
- Data lakes & analytics (Athena, EMR, Glue, Redshift Spectrum)
- Application file uploads (images, documents) via pre-signed URLs
- Log storage (CloudTrail, ALB, VPC flow logs)
- Artifact storage for CI/CD; **Terraform remote state** (`backend "s3"` with state locking)
- ML training datasets and model artifacts

Reference: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html
