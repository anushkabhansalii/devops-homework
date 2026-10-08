# Terraform S3 Demo

**Name:** Anushka Jain

Creates an AWS S3 bucket with Terraform and walks through the whole workflow: `init → fmt → validate → plan → apply → show → output → destroy`. All output below is from [`../run.sh`](../run.sh) on my machine.

> **Where it ran:** I don't have an AWS account set up on this laptop, so instead of real AWS I pointed the AWS provider at **[Moto](https://github.com/getmoto/moto)**, an open-source AWS API emulator running in Docker on `localhost:4566`. Terraform, the `hashicorp/aws` provider and every command are exactly the same — only the endpoint differs. Setting `use_local_emulator = false` in `terraform.tfvars` (and running `aws configure`) creates the bucket in real AWS instead.

## Project structure
```text
terraform-s3-demo/
├── terraform.tf        Terraform + provider version constraints (hashicorp/aws ~> 6.0)
├── provider.tf         AWS provider: region, default tags, optional local-emulator endpoint
├── variables.tf        input variables (with a validation rule on the bucket name)
├── terraform.tfvars    my values for those variables
├── main.tf             bucket + versioning + encryption + public access block + an object
├── outputs.tf          bucket name / ARN / region / versioning status / object URL
├── verify_bucket.py    reads the bucket back with signed boto3 calls (verification)
├── .terraform.lock.hcl provider version lock (committed so everyone uses the same provider build)
└── .gitignore          ignores .terraform/, *.tfstate, plan files
```

## How the files fit together
```text
terraform.tf ──► which provider + versions to download (terraform init)
provider.tf  ──► how to talk to AWS (region, credentials, endpoint, default_tags)
variables.tf ◄── terraform.tfvars  (values)          ┐
main.tf      ──► resources built from var.*          ├─► terraform plan / apply ──► real S3 bucket
outputs.tf   ──► values printed after apply          ┘                          ──► terraform.tfstate
```
- **Resources** in `main.tf`: `aws_s3_bucket` (the bucket, tags, `force_destroy`), `aws_s3_bucket_versioning` (Enabled), `aws_s3_bucket_server_side_encryption_configuration` (AES256), `aws_s3_bucket_public_access_block` (all four blocks on), `aws_s3_object` (`hello.txt`). In provider v4+ these bucket settings are separate resources rather than blocks inside `aws_s3_bucket`.
- **Variables**: `aws_region`, `bucket_name` (validated: 3–63 lowercase chars), `environment`, `enable_versioning`, `use_local_emulator`, `local_endpoint`.
- **default_tags** in the provider adds `ManagedBy / Project / Owner` to every resource automatically (see `tags_all` in the plan).
- **State** (`terraform.tfstate`) maps config to real resource IDs. It's git-ignored because it can contain secrets; teams store it remotely (S3 backend with locking).

## 1. `terraform init`
Downloads the provider plugin, creates `.terraform/` and the lock file.
```text
$ terraform init
Initializing the backend...
Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Installing hashicorp/aws v6.67.0...
- Installed hashicorp/aws v6.67.0 (signed by HashiCorp)
Terraform has been successfully initialized!
```

## 2. `terraform fmt` and 3. `terraform validate`
```text
$ terraform fmt -check -diff          <- no output = every file already in canonical format
$ terraform validate
Success! The configuration is valid.
```
`fmt` rewrites files into the standard style (`-check` just reports, useful in CI). `validate` checks syntax, references and types without contacting AWS.

## 4. `terraform plan`
Compares config with state + real infrastructure and shows what *would* change. `-out` saves the exact plan so `apply` does precisely that.
```text
$ terraform plan -out=tfplan
  # aws_s3_bucket.demo will be created
  + resource "aws_s3_bucket" "demo" {
      + arn           = (known after apply)
      + bucket        = "anushka-devops-session18-demo"
      + force_destroy = true
      + region        = "ap-south-1"
      + tags          = { "Environment" = "dev", "Name" = "anushka-devops-session18-demo" }
      + tags_all      = { "Environment" = "dev", "ManagedBy" = "Terraform", "Name" = "...",
                          "Owner" = "Anushka Jain", "Project" = "Session18" }
      ...
    }
  # aws_s3_bucket_public_access_block.demo will be created
  # aws_s3_bucket_server_side_encryption_configuration.demo will be created   (sse_algorithm = "AES256")
  # aws_s3_bucket_versioning.demo will be created                             (status = "Enabled")
  # aws_s3_object.readme will be created                                      (key = "hello.txt")

Plan: 5 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_arn        = (known after apply)
  + bucket_name       = "anushka-devops-session18-demo"
  + bucket_region     = "ap-south-1"
  + object_url        = "s3://anushka-devops-session18-demo/hello.txt"
  + versioning_status = "Enabled"
```
`+` create, `~` update in place, `-` destroy, `-/+` replace. `(known after apply)` = values AWS assigns.

## 5. `terraform apply`
```text
$ terraform apply tfplan
aws_s3_bucket.demo: Creating...
aws_s3_bucket.demo: Creation complete after 0s [id=anushka-devops-session18-demo]
aws_s3_bucket_public_access_block.demo: Creating...
aws_s3_object.readme: Creating...
aws_s3_bucket_server_side_encryption_configuration.demo: Creating...
aws_s3_bucket_versioning.demo: Creating...
...
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
bucket_arn = "arn:aws:s3:::anushka-devops-session18-demo"
bucket_name = "anushka-devops-session18-demo"
bucket_region = "ap-south-1"
object_url = "s3://anushka-devops-session18-demo/hello.txt"
versioning_status = "Enabled"
```
Terraform builds a **dependency graph**: the bucket is created first; the four resources that reference `aws_s3_bucket.demo.id` then run **in parallel**.

## 6. `terraform show` and 7. `terraform output`
```text
$ terraform state list
aws_s3_bucket.demo
aws_s3_bucket_public_access_block.demo
aws_s3_bucket_server_side_encryption_configuration.demo
aws_s3_bucket_versioning.demo
aws_s3_object.readme

$ terraform show                      <- human-readable state (trimmed)
resource "aws_s3_bucket" "demo" {
    arn           = "arn:aws:s3:::anushka-devops-session18-demo"
    bucket        = "anushka-devops-session18-demo"
    bucket_region = "ap-south-1"
    force_destroy = true
    ...

$ terraform output
bucket_arn = "arn:aws:s3:::anushka-devops-session18-demo"
bucket_name = "anushka-devops-session18-demo"
bucket_region = "ap-south-1"
object_url = "s3://anushka-devops-session18-demo/hello.txt"
versioning_status = "Enabled"

$ terraform output -raw bucket_arn    <- plain value, handy in scripts
arn:aws:s3:::anushka-devops-session18-demo
```
**Verifying the bucket really exists and is configured:**
```text
$ curl -s -o /dev/null -w 'anonymous GET hello.txt -> HTTP %{http_code}\n' http://localhost:4566/anushka-devops-session18-demo/hello.txt
anonymous GET hello.txt -> HTTP 403          <- Block Public Access is working

$ python3 verify_bucket.py anushka-devops-session18-demo http://localhost:4566     (signed API calls)
Buckets:      ['anushka-devops-session18-demo']
Versioning:   Enabled
Encryption:   AES256
PublicBlock:  {'BlockPublicAcls': True, 'IgnorePublicAcls': True, 'BlockPublicPolicy': True, 'RestrictPublicBuckets': True}
Tags:         {'Name': 'anushka-devops-session18-demo', 'ManagedBy': 'Terraform', 'Owner': 'Anushka Jain', 'Project': 'Session18', 'Environment': 'dev'}
hello.txt:    Hello from Terraform - Session 18 - Anushka Jain
```

**Idempotency** — running plan again right after apply:
```text
$ terraform plan -detailed-exitcode
No changes. Your infrastructure matches the configuration.
```
Applying the same config twice changes nothing — Terraform is declarative ("this is the desired state"), not a script of steps.

## 8. `terraform destroy`
```text
$ terraform destroy -auto-approve
  # aws_s3_bucket.demo will be destroyed
  # aws_s3_bucket_public_access_block.demo will be destroyed
  # aws_s3_bucket_server_side_encryption_configuration.demo will be destroyed
  # aws_s3_bucket_versioning.demo will be destroyed
  # aws_s3_object.readme will be destroyed
Plan: 0 to add, 0 to change, 5 to destroy.
...
Destroy complete! Resources: 5 destroyed.

$ terraform state list                 <- empty
$ python3 verify_bucket.py anushka-devops-session18-demo http://localhost:4566
botocore.errorfactory.NoSuchBucket: ... The specified bucket does not exist
```
Destroy runs in **reverse** dependency order (settings and object first, bucket last). `force_destroy = true` lets it delete a non-empty bucket — fine for a demo, dangerous for real data.

## Command summary
| Command | What it does |
|---|---|
| `terraform init` | download providers/modules, set up backend, write lock file |
| `terraform fmt` | format `.tf` files (`-check` for CI) |
| `terraform validate` | static check of syntax/references/types |
| `terraform plan` | preview changes (`-out` to save) |
| `terraform apply` | make real infrastructure match the config |
| `terraform show` | show the state or a saved plan |
| `terraform output` | print output values (`-raw`, `-json`) |
| `terraform state list` | list resources tracked in state |
| `terraform destroy` | delete everything this config manages |

## Run it yourself
```bash
docker run -d --name moto -p 4566:5000 motoserver/moto:latest
pip install boto3
cd terraform-iac && ./run.sh
```
