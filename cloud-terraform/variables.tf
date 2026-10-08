variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "session19"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per AZ."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "One private subnet per AZ."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to the web server (never 0.0.0.0/0)."
  type        = string
  default     = "203.0.113.10/32"

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "SSH must not be open to the whole internet."
  }
}

variable "use_local_emulator" {
  description = "Point the AWS provider at a local emulator instead of real AWS."
  type        = bool
  default     = false
}

variable "local_endpoint" {
  description = "URL of the local AWS emulator."
  type        = string
  default     = "http://localhost:4566"
}
