output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ)."
  value       = aws_subnet.private[*].id
}

output "security_group_id" {
  description = "Web security group ID."
  value       = aws_security_group.web.id
}

output "web_instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL of the web server."
  value       = "http://${aws_instance.web.public_ip}"
}

output "assets_bucket" {
  description = "Name of the S3 assets bucket."
  value       = aws_s3_bucket.assets.bucket
}
