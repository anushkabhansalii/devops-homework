# EC2 — Elastic Compute Cloud (Compute)

**Name:** Anushka Jain

## What is EC2?
EC2 gives you **virtual servers ("instances") in the cloud** that you can launch in minutes, resize, stop and terminate, paying per second. You control the OS and everything above it (IaaS) — AWS manages the physical hardware, hypervisor (Nitro) and data center.

```text
AMI (template) + Instance type (CPU/RAM) + Key pair + Security group + Subnet (VPC) + EBS volume
                                       │
                                       ▼
                               running EC2 instance
```

## AMI (Amazon Machine Image)
The **template** an instance boots from: root volume snapshot (OS + pre-installed software), architecture (x86_64 / arm64), virtualization type, and launch permissions.
- AWS-provided: Amazon Linux 2023, Ubuntu, Windows Server, …
- AWS Marketplace (vendor images) and community AMIs
- **Custom AMIs** — bake your app/config into an image (e.g. with Packer) for fast, identical launches ("golden image")

AMIs are **regional** (copy them to use elsewhere) and each has an ID like `ami-0abcd1234…`.

## Instance types
Named `family + generation + [attributes] . size`, e.g. `t3.micro`, `m7g.large`, `c7i.2xlarge`.

| Family | Optimized for | Example use |
|---|---|---|
| **t** (t3, t4g) | burstable general purpose (CPU credits) | dev/test, small web apps |
| **m** (m7i, m7g) | balanced general purpose | app servers, mid DBs |
| **c** (c7i, c7g) | compute | batch, encoding, high-traffic web |
| **r / x** (r7i, x2) | memory | in-memory caches, big DBs |
| **i / d** | storage (local NVMe) | NoSQL, data warehousing |
| **p / g / inf / trn** | accelerated (GPU / ML chips) | ML training/inference, graphics |

Suffix letters: `g` = Graviton (ARM, cheaper), `i` = Intel, `a` = AMD, `n` = enhanced networking, `d` = local NVMe disk.

**Pricing models:** On-Demand (per second), Savings Plans / Reserved Instances (1–3 yr commitment, up to ~72% off), **Spot** (spare capacity, up to ~90% off, can be reclaimed with 2-min notice), Dedicated Hosts.

## Key pairs
SSH authentication for Linux instances: AWS stores the **public key** and injects it into `~/.ssh/authorized_keys`; you keep the **private key** (`.pem`) — AWS never shows it again.
```bash
chmod 400 my-key.pem
ssh -i my-key.pem ec2-user@<public-ip>
```
Better: **SSM Session Manager** — shell access through IAM with no SSH keys and no open port 22 (also logged).

## Security groups
A **stateful virtual firewall at the instance (ENI) level**.
- Only **allow** rules (no deny); everything not allowed is blocked inbound; all outbound allowed by default
- **Stateful**: if inbound traffic is allowed, the response goes back out automatically
- Sources can be CIDRs or **other security groups** (e.g. "DB SG allows 5432 only from App SG")
- Rule changes apply immediately; an instance can have several SGs

```text
web-sg: inbound 443 from 0.0.0.0/0, 22 from my-ip/32
db-sg:  inbound 5432 from web-sg
```

## EBS (Elastic Block Store)
**Network-attached block storage** (a virtual disk) for an instance, in one Availability Zone.
- Persists independently of the instance (root volume deleted on termination by default — `DeleteOnTermination`)
- Types: **gp3** (general SSD, default), io2 (provisioned IOPS for DBs), st1/sc1 (throughput / cold HDD)
- **Snapshots** → incremental backups stored in S3, can be copied across regions and used to create AMIs/volumes
- Encryption with KMS; can resize / change type online
- Different from **instance store** — fast local NVMe that is *lost* when the instance stops

## Public vs private IP
| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| From | subnet CIDR (e.g. 10.0.1.25) | AWS pool | allocated to your account |
| Reachable from | inside the VPC (and peered/VPN networks) | internet (needs IGW route + SG) | internet |
| Lifetime | for the life of the ENI | **changes on stop/start** | static until released |
| Cost | free | charged per hour (IPv4) | charged per hour |

An instance in a **private subnet** has only a private IP and reaches the internet through a NAT gateway; a **public subnet** instance gets a public IP and routes via the Internet Gateway.

## Instance lifecycle
```text
          launch
            │
            ▼
        pending ───► running ◄────────────── start
                       │   │  reboot (same host, keeps everything)
              stop     │   │ terminate
                       ▼   ▼
                  stopping  shutting-down
                       │          │
                       ▼          ▼
                    stopped    terminated (gone; root EBS deleted by default)
```
- **Running** — billed for compute
- **Stopped** — no compute charge, EBS still billed; public IP released; may move to new hardware on start
- **Hibernate** — RAM saved to EBS, resumes where it left off
- **Terminated** — permanent

## Common use cases
- Web/application servers behind an Application Load Balancer + **Auto Scaling Group**
- Self-managed databases or software needing full OS control
- Kubernetes worker nodes (EKS managed node groups / Karpenter)
- CI build runners, batch & HPC jobs (often on Spot)
- Bastion hosts / jump boxes (now mostly replaced by SSM)

## Terraform example
```hcl
resource "aws_instance" "web" {
  ami                    = "ami-0abcdef1234567890"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "my-key"
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }
  tags = { Name = "web-server" }
}
```
(The full VPC + EC2 build is in the next session's Terraform project.)

Reference: https://docs.aws.amazon.com/ec2/
