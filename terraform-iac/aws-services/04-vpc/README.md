# VPC — Virtual Private Cloud (Networking)

**Name:** Anushka Jain

## What is a VPC?
A VPC is your own **logically isolated private network inside an AWS region**. You choose its IP range, split it into subnets across Availability Zones, and control routing and firewalls. Every EC2 instance, RDS database, EKS node, Lambda-in-VPC, load balancer… lives in a VPC. Each account gets a *default VPC* per region, but real environments build their own (usually with Terraform — see the next session's project).

```text
Region (ap-south-1)
└── VPC 10.0.0.0/16
    ├── AZ ap-south-1a
    │   ├── Public subnet  10.0.1.0/24  ── route 0.0.0.0/0 → Internet Gateway   (ALB, NAT GW, bastion)
    │   └── Private subnet 10.0.11.0/24 ── route 0.0.0.0/0 → NAT Gateway        (app servers)
    ├── AZ ap-south-1b
    │   ├── Public subnet  10.0.2.0/24
    │   └── Private subnet 10.0.12.0/24
    └── Internet Gateway (attached to the VPC)
```

## CIDR
**Classless Inter-Domain Routing** notation describes an IP range as `base-address/prefix-length`; the prefix says how many leading bits are fixed.

| CIDR | Addresses | Typical use |
|---|---|---|
| 10.0.0.0/16 | 65,536 | whole VPC (allowed /16 – /28) |
| 10.0.1.0/24 | 256 (**251 usable** in AWS) | one subnet |
| 10.0.1.0/28 | 16 (11 usable) | smallest subnet |
| 203.0.113.10/32 | 1 | a single IP in a security group rule |
| 0.0.0.0/0 | everything | default route / "anywhere" |

AWS reserves **5 IPs in every subnet**: network address, .1 (VPC router), .2 (DNS), .3 (future), and broadcast. Use private (RFC 1918) ranges — 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 — and plan them so VPCs you might peer/connect **don't overlap**.

## Subnets
A slice of the VPC's CIDR that lives in **exactly one Availability Zone**. Resources are launched into subnets. Spread subnets across ≥2 AZs for high availability. Whether a subnet is *public* or *private* is **not** a setting — it's decided purely by its route table.

## Route tables
A set of rules (`destination CIDR → target`) that decide where traffic leaving a subnet goes. Every subnet is associated with exactly one route table (the VPC's *main* table if not explicitly set). Every table has the implicit `local` route so all subnets in the VPC can reach each other. Most specific route wins.

| Destination | Target | Meaning |
|---|---|---|
| 10.0.0.0/16 | local | traffic inside the VPC |
| 0.0.0.0/0 | igw-xxxx | everything else → internet (**public** subnet) |
| 0.0.0.0/0 | nat-xxxx | everything else → NAT (**private** subnet) |
| 172.31.0.0/16 | pcx-xxxx | to a peered VPC |
| (S3 prefix list) | vpce-xxxx | gateway endpoint to S3 without internet |

## Internet Gateway (IGW)
A horizontally-scaled, highly-available VPC component that allows **two-way** communication between the VPC and the internet. One IGW per VPC. An instance is reachable from the internet only if: its subnet routes `0.0.0.0/0 → IGW`, it has a public/Elastic IP, and its security group + NACL allow the traffic. Free.

## NAT Gateway
Lets instances in **private subnets** start **outbound** connections to the internet (OS updates, calling APIs, pulling images) while staying **unreachable from the internet**. It lives in a *public* subnet with an Elastic IP; private route tables send `0.0.0.0/0` to it. Managed and scaled by AWS, but **charged per hour + per GB** — for HA you deploy one per AZ. (Alternatives: NAT instance — cheaper but self-managed; VPC endpoints to reach AWS services privately without NAT.)

## Security Groups
**Stateful** firewall attached to an ENI / instance: allow-rules only, return traffic automatically allowed, can reference other security groups. First and main line of defense. (Details in the EC2 doc.)

## Network ACLs
**Stateless** firewall at the **subnet** level.
| | Security Group | Network ACL |
|---|---|---|
| Level | instance / ENI | subnet |
| State | **stateful** | **stateless** (must allow return traffic, e.g. ephemeral ports 1024-65535) |
| Rules | allow only | allow **and deny** |
| Evaluation | all rules together | in **number order**, first match wins |
| Default | deny in, allow out (custom SG) | default NACL allows all |
| Typical use | main access control | coarse subnet-wide blocks (e.g. deny a malicious IP range) |

## Public vs private subnet
| | Public subnet | Private subnet |
|---|---|---|
| Default route | `0.0.0.0/0 → Internet Gateway` | `0.0.0.0/0 → NAT Gateway` (or none) |
| Instances get | public IP (auto-assign) | private IP only |
| Reachable from internet | yes (if SG allows) | **no** |
| Can reach internet | yes | outbound only via NAT |
| Put here | load balancers, NAT gateways, bastion | app servers, databases, EKS nodes, caches |

Standard 3-tier pattern: **ALB in public subnets → app instances in private subnets → RDS in private (isolated) DB subnets**, spread over 2–3 AZs.

## Other VPC pieces worth knowing
- **VPC endpoints** — Gateway (S3, DynamoDB; free) and Interface/PrivateLink (most services) to reach AWS privately
- **VPC peering / Transit Gateway** — connect VPCs (TGW for hub-and-spoke at scale)
- **Site-to-Site VPN / Direct Connect** — connect on-premises networks
- **VPC Flow Logs** — capture IP traffic metadata for troubleshooting & security

Reference: https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html
