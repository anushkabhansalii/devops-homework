variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "taskboard-eks"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.11.0/24", "10.30.12.0/24"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_scaling" {
  type = object({ min = number, desired = number, max = number })
  default = {
    min     = 2
    desired = 2
    max     = 4
  }
}

variable "use_local_emulator" {
  type    = bool
  default = false
}

variable "local_endpoint" {
  type    = string
  default = "http://localhost:4566"
}
