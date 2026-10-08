# Latest Amazon Linux 2023 AMI (looked up, not hard-coded - AMI IDs differ per region)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>Session 19 - deployed by Terraform - Anushka Jain</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # Explicit dependency: user_data needs internet access to install nginx, which only works once
  # the public route table is attached. Terraform can't see that from references alone.
  depends_on = [aws_route_table_association.public]

  tags = { Name = "${var.project}-web" }
}
