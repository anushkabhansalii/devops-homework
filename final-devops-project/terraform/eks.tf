# Customer-managed KMS key to encrypt Kubernetes Secrets at rest in etcd (envelope encryption)
resource "aws_kms_key" "eks" {
  description             = "${var.cluster_name} secrets encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    # public endpoint kept for kubectl from a laptop, but only from the admin's IP range
    # (fully private would need a VPN / bastion - documented as an accepted risk)
    endpoint_public_access = true
    public_access_cidrs    = var.cluster_admin_cidrs
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_scaling.min
    desired_size = var.node_scaling.desired
    max_size     = var.node_scaling.max
  }

  update_config {
    max_unavailable = 1
  }

  labels = { workload = "taskboard" }

  depends_on = [aws_iam_role_policy_attachment.node, aws_route_table_association.private]
}
