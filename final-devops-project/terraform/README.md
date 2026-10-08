# Terraform — AWS infrastructure for TaskBoard

Provisions the production platform: **VPC (2 AZs, public + private subnets, IGW, NAT gateway, route tables) → IAM roles → EKS cluster (KMS-encrypted secrets, restricted API endpoint) → managed node group in the private subnets.**

| File | Contents |
|---|---|
| `versions.tf` | Terraform + AWS provider versions, (commented) S3 remote-state backend |
| `providers.tf` | AWS provider, default tags, local-emulator switch |
| `variables.tf` / `terraform.tfvars` | region, cluster name/version, CIDRs, node sizes, admin CIDRs (validated) |
| `vpc.tf` | VPC, subnets (with Kubernetes ELB discovery tags), IGW, EIP + NAT, routes |
| `iam.tf` | EKS cluster role + node role with the AWS-managed EKS policies |
| `eks.tf` | KMS key, EKS cluster, managed node group |
| `outputs.tf` | VPC/subnet IDs, cluster endpoint, `aws eks update-kubeconfig ...` command |

For the homework it runs against **Moto** (local AWS emulator, `use_local_emulator = true`) — `terraform plan` shows 23 resources; apply/destroy output is in the [project README](../README.md#terraform). Set `use_local_emulator = false` and `aws configure` to build it for real (EKS + NAT gateway are billable).
