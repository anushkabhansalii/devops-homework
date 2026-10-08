aws_region         = "ap-south-1"
cluster_name       = "taskboard-eks"
kubernetes_version = "1.33"
use_local_emulator = true # false + `aws configure` = real AWS (EKS + NAT gateway cost money!)
