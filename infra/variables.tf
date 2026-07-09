variable "aws_region" {
  type        = string
  description = "AWS region to deploy the lab."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Project prefix used for AWS resource names."
  default     = "wiz-devsecops-lab"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR range for the lab VPC."
  default     = "10.50.0.0/16"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to reach EKS public endpoint. Keep narrow for real demos."
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key used for the MongoDB EC2 key pair."
  default     = "~/.ssh/id_rsa.pub"
}

variable "mongo_db_name" {
  type        = string
  default     = "appdb"
}

variable "mongo_app_user" {
  type        = string
  default     = "appuser"
}

variable "mongo_admin_user" {
  type        = string
  default     = "admin"
}

variable "eks_version" {
  type        = string
  description = "EKS Kubernetes control plane version."
  default     = "1.30"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "enable_guardduty" {
  type        = bool
  description = "Enable GuardDuty detector with EKS audit-log monitoring where supported."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
