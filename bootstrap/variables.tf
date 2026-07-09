variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "wiz-devsecops-lab"
}

variable "github_owner" {
  type        = string
  description = "GitHub org or username."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name."
}

variable "github_branch" {
  type    = string
  default = "main"
}
