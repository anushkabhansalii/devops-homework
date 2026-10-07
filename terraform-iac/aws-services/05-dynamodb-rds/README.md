# DynamoDB & RDS — Database Services

**Name:** Anushka Jain

| | **DynamoDB** | **RDS** |
|---|---|---|
| Type | NoSQL key-value / document | Relational (SQL) |
| Management | fully **serverless** — no instances | managed DB **instances** you size |
| Schema | schemaless (only keys defined) | fixed schema, tables, joins, constraints |
| Scaling | automatic, virtually unlimited, single-digit ms | vertical (bigger instance) + read replicas |
| Query | by key (+ indexes) | full SQL, joins, aggregations |
| Pricing | per request or provisioned capacity + storage | per instance-hour + storage + I/O |
| Best for | known access patterns at massive scale | complex queries, transactions, existing SQL apps |

---

# DynamoDB

## NoSQL
DynamoDB is a fully managed, serverless **NoSQL** database: data is stored as key-value items / JSON-like documents instead of normalized relational tables. There are **no joins**; you design tables around your **access patterns** (often a single table holds several entity types). In return you get consistent single-digit-millisecond latency at any scale, automatic multi-AZ replication, and no servers, patching or capacity planning (on-demand mode).

## Tables
A collection of items; the only thing you must define is the **primary key**. Capacity modes:
- **On-demand** — pay per read/write request, scales instantly (good default)
- **Provisioned** — set RCUs/WCUs (+ auto scaling), cheaper for steady traffic

Extra features: **Global Secondary Indexes** (query by other attributes), Local Secondary Indexes, **TTL** (auto-expire items), **Streams** (change feed → Lambda), point-in-time recovery, **Global Tables** (multi-region active-active), transactions, encryption at rest by default.

## Items
One record in a table (like a row), max **400 KB**. Items in the same table can have completely different attributes.
```json
{ "user_id": "u#1001", "booking_id": "b#2026-10-07#42", "from": "Delhi", "to": "Mumbai", "seats": 2, "status": "CONFIRMED" }
```

## Attributes
The fields of an item (like columns, but not fixed). Types: scalar (`S` string, `N` number, `B` binary, `BOOL`, `NULL`), document (`M` map, `L` list) and sets (`SS`, `NS`, `BS`).

## Partition key
The **mandatory** part of the primary key. DynamoDB hashes it to decide which physical **partition** stores the item. A table with only a partition key needs it to be **unique** per item. Choose a **high-cardinality** key (user_id, order_id) so traffic spreads evenly — a low-cardinality key (e.g. `status`) creates **hot partitions**.

## Sort key
Optional second part of the primary key (composite key = partition key + sort key). Items with the same partition key are stored together **sorted by the sort key**, enabling range queries: `begins_with`, `between`, `>`, `<`.
```text
PK = user_id         SK = booking_id (date-prefixed)
Query: user_id = "u#1001" AND booking_id BETWEEN "b#2026-10-01" AND "b#2026-10-31"   → all October bookings, sorted
```

## Use cases
Shopping carts, user sessions & profiles, gaming leaderboards, IoT/time-series events, ad-tech, serverless backends (API Gateway + Lambda + DynamoDB), metadata stores, and **Terraform state locking** (classic `dynamodb_table` lock; newer versions can lock natively in S3).

```hcl
resource "aws_dynamodb_table" "bookings" {
  name         = "bookings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "booking_id"
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "booking_id"
    type = "S"
  }
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
  point_in_time_recovery {
    enabled = true
  }
}
```

---

# RDS

## Relational database
**Amazon RDS (Relational Database Service)** runs managed relational databases: tables with a fixed schema, rows/columns, primary & foreign keys, SQL, joins and ACID transactions. AWS handles provisioning, OS + DB patching, backups, failover and monitoring; you handle schema, queries, indexes, and choosing the instance size.

## Supported engines
- **PostgreSQL**, **MySQL**, **MariaDB**
- **Oracle**, **Microsoft SQL Server**, **Db2**
- **Amazon Aurora** (MySQL / PostgreSQL compatible) — AWS's cloud-native engine: storage auto-grows to 128 TiB with 6 copies across 3 AZs, up to 15 low-lag replicas, Aurora Serverless v2 auto-scales capacity

## DB instances
The compute that runs the database: an **instance class** (e.g. `db.t4g.micro`, `db.m7g.large`, `db.r7g.xlarge` for memory-heavy) + **storage** (gp3 / io2 EBS, with storage auto-scaling). It lives in a **DB subnet group** (private subnets across ≥2 AZs), has an endpoint (`mydb.xxxx.ap-south-1.rds.amazonaws.com:5432`), and is configured through parameter groups / option groups. No SSH/OS access.

## Security
- Run in **private subnets**, `publicly_accessible = false`
- **Security groups** allow the DB port only from the app's SG
- **Encryption at rest** with KMS (must be chosen at creation) and **TLS in transit** (`rds.force_ssl`)
- Credentials in **AWS Secrets Manager** with automatic rotation (`manage_master_user_password = true`) — never in code/Terraform vars
- **IAM database authentication** (short-lived tokens instead of passwords)
- Audit logs to CloudWatch, deletion protection, CloudTrail for API calls

## Backups
- **Automated backups** — daily snapshot + transaction logs, retention 1–35 days, enables **point-in-time restore** to any second in the window
- **Manual snapshots** — kept until you delete them; copy across regions/accounts
- Restores always create a **new** instance

## Multi-AZ
A **synchronous standby** copy in another AZ for **high availability** (not for reads, in the classic deployment). On failure, patching or AZ outage, RDS **automatically fails over** by flipping the DNS endpoint to the standby (typically 60–120 s) — the app keeps using the same endpoint. *Multi-AZ DB clusters* (MySQL/Postgres) add two readable standbys and faster failover.

## Read replicas
**Asynchronous** copies used to **scale reads** (reports, analytics, read-heavy APIs) — each has its own endpoint, may lag slightly, can be in another region (also DR), and can be promoted to a standalone primary. Up to 15 for most engines (Aurora up to 15 sharing storage).

| | Multi-AZ standby | Read replica |
|---|---|---|
| Purpose | availability / failover | read scaling |
| Replication | synchronous | asynchronous |
| Serves reads | no (classic) | yes |
| Cross-region | no | yes |

## Use cases
Traditional web & mobile backends, e-commerce orders/payments (transactions), ERP/CRM, SaaS multi-tenant apps, anything with relational data and complex queries, lift-and-shift of existing MySQL/Postgres/Oracle/SQL Server databases.

```hcl
resource "aws_db_instance" "app" {
  identifier                  = "app-postgres"
  engine                      = "postgres"
  engine_version              = "17"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  storage_encrypted           = true
  db_subnet_group_name        = aws_db_subnet_group.private.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  username                    = "appadmin"
  manage_master_user_password = true    # password generated & rotated in Secrets Manager
  multi_az                    = true
  backup_retention_period     = 7
  deletion_protection         = true
  publicly_accessible         = false
}
```

References: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html · https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html
