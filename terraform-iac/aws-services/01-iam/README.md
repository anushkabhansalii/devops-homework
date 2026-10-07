# IAM — Identity and Access Management (Governance)

**Name:** Anushka Jain

## What is IAM?
IAM is the AWS service that decides **who** (authentication) can do **what** on **which resources** (authorization) in an AWS account. It is global (not tied to a region) and free. Every single AWS API call — from the console, CLI, SDK or Terraform — is checked against IAM policies; anything not explicitly allowed is **denied by default**.

```text
Principal (user / role / service)  ──calls──►  AWS API (e.g. s3:PutObject on arn:aws:s3:::my-bucket/*)
                                                  │
                                       IAM policy evaluation
                                                  │
                         explicit Deny? ──yes──► DENY
                                │ no
                         explicit Allow? ──no──► DENY (implicit)
                                │ yes
                              ALLOW
```

## Root user
The email you signed up with. Has unrestricted access and some account-only powers (close account, change support plan, billing settings). **Never use it day-to-day**: enable MFA on it, delete its access keys, and create admin identities instead.

## Users
A **permanent identity** for one person or application, with long-term credentials:
- console password (+ MFA) for humans
- access key ID + secret access key for CLI/SDK

Long-term access keys are the #1 source of AWS breaches (leaked to GitHub, laptops). Modern practice: humans log in through **IAM Identity Center (SSO)**, and workloads use **roles**, so very few IAM users exist.

## Groups
A collection of users that share permissions — attach the policy to the group, not to each user. `Developers`, `Admins`, `ReadOnly`. A user can be in several groups; groups cannot contain groups and cannot be used as a principal in a policy.

## Roles
An identity **without permanent credentials** that someone or something *assumes* to get **temporary credentials** (via STS, expire in 15 min – 12 h). A role has two policies:
- **Trust policy** — *who* may assume it (an AWS service like `ec2.amazonaws.com`, another account, a federated/OIDC identity)
- **Permissions policy** — *what* it can do once assumed

Examples: an EC2 instance profile role so the app on the instance can read S3 without keys; **GitHub Actions OIDC** → assume a deploy role (no AWS keys stored in GitHub secrets); cross-account access; Kubernetes pods via IRSA / EKS Pod Identity.

## Policies
JSON documents that grant or deny permissions.
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::anushka-devops-session18-demo",
        "arn:aws:s3:::anushka-devops-session18-demo/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "true" } }
    }
  ]
}
```
Elements: `Effect` (Allow/Deny), `Action` (service:operation), `Resource` (ARNs), optional `Condition` (IP, MFA, tags, time, TLS…), and `Principal` (only in resource-based policies).

| Policy type | Attached to | Notes |
|---|---|---|
| AWS managed | users/groups/roles | maintained by AWS, e.g. `ReadOnlyAccess`, `AmazonS3FullAccess` — convenient but broad |
| Customer managed | users/groups/roles | your own reusable policies — preferred |
| Inline | one identity | embedded, deleted with the identity |
| Resource-based | a resource (S3 bucket policy, SQS, KMS key policy) | has a `Principal`; enables cross-account access |
| Permissions boundary | user/role | the *maximum* permissions it can ever have |
| SCP (Organizations) | an account / OU | guardrail for whole accounts, even root |

## Permissions — how evaluation works
1. Everything starts as **implicit deny**.
2. An **explicit Deny** anywhere (SCP, boundary, identity or resource policy) always wins.
3. Otherwise the request needs an **Allow** — and it must be allowed by *every* applicable layer (SCP ∩ boundary ∩ identity/resource policy).

## Least privilege
Give each identity **only the permissions it needs, on only the resources it needs, for only as long as it needs**. In practice:
- start from nothing and add specific actions (`s3:GetObject` on one bucket, not `s3:*` on `*`)
- use **IAM Access Analyzer** to generate policies from CloudTrail activity and find unused permissions / externally shared resources
- prefer short-lived role credentials over access keys
- separate roles for read vs. deploy vs. admin

## IAM best practices
- Lock away the root user: MFA, no access keys
- Use **IAM Identity Center** (SSO) + federation for humans; MFA everywhere
- Use **roles** for workloads (EC2 instance profiles, Lambda execution roles, EKS Pod Identity, GitHub OIDC) — no hard-coded keys
- Least privilege, customer-managed policies, permissions boundaries for delegated admins
- Rotate / remove unused credentials (credential report, Access Analyzer unused-access findings)
- Use conditions (`aws:MultiFactorAuthPresent`, `aws:SourceIp`, tags) to tighten policies
- Use AWS Organizations + SCPs to set guardrails across accounts
- Log everything with **CloudTrail**

## Common use cases
- Developers group with read-only prod access and full dev access
- EC2 / Lambda reading from S3 or DynamoDB through a role
- CI/CD pipeline (GitHub Actions) deploying with an OIDC-assumed role instead of stored keys
- Cross-account access (central security/logging account)
- Terraform running with a dedicated, scoped deploy role

## Terraform example
```hcl
resource "aws_iam_role" "app" {
  name = "app-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "read_bucket" {
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::anushka-devops-session18-demo/*" }]
  })
}
```

References: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html · https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
